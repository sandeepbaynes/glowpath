import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/puzzle.dart';
import '../game/voyage_progression.dart';

/// Explicit on-device preview. The four competitors are fictional; this
/// player's scores are calculated by replaying real challenge actions locally.
class MockFlightLeague {
  MockFlightLeague({DateTime Function()? now}) : _now = now ?? DateTime.now;
  static const storageKey = 'glowpath.mock.league.v1';
  static const pilotId = 'local-preview-pilot';
  final DateTime Function() _now;
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();
  bool joined = false;
  String? get callsign => joined ? 'You · local preview' : null;
  final Map<String, Map<String, dynamic>> _results = {};

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1 || data['joined'] != true) return;
      joined = true;
      final records = data['results'];
      if (records is! List) return;
      for (final record in records.take(720)) {
        if (record is! Map ||
            !['daily', 'weekly'].contains(record['mode']) ||
            record['period'] is! String ||
            record['index'] is! int ||
            record['score'] is! int ||
            record['moves'] is! int) {
          continue;
        }
        if ((record['index'] as int) < 0 ||
            (record['index'] as int) >= (record['mode'] == 'daily' ? 3 : 5) ||
            (record['score'] as int) < 100 ||
            (record['score'] as int) > 200 ||
            (record['moves'] as int) < 1 ||
            (record['moves'] as int) > 500 ||
            DateTime.tryParse('${record['period']}T00:00:00Z') == null) {
          continue;
        }
        final value = Map<String, dynamic>.from(record);
        _results[_key(value)] = value;
      }
    } catch (_) {
      joined = false;
      _results.clear();
    }
  }

  String _key(Map<String, dynamic> value) =>
      '${value['mode']}/${value['period']}/${value['index']}';

  String _period(String mode) {
    final utc = _now().toUtc();
    var day = DateTime.utc(utc.year, utc.month, utc.day);
    if (mode == 'weekly') day = day.subtract(Duration(days: day.weekday - 1));
    return day.toIso8601String().split('T').first;
  }

  Future<void> _save() {
    final snapshot = jsonEncode({
      'version': 1,
      'joined': joined,
      'results': _results.values.toList(),
    });
    _writes = _writes.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, snapshot)) {
        throw const MockLeagueException(
          'The preview league could not save on this device.',
        );
      }
    });
    return _writes;
  }

  Future<void> join() async {
    await load();
    joined = true;
    await _save();
  }

  Future<Map<String, dynamic>> standings(String mode) async {
    await load();
    if (!joined) {
      throw const MockLeagueException('Join the preview league first.');
    }
    if (!['daily', 'weekly'].contains(mode)) {
      throw const MockLeagueException('Choose Daily or Weekly.');
    }
    final period = _period(mode);
    final weekly = mode == 'weekly';
    final entries = <Map<String, dynamic>>[
      for (final (index, name) in ['Nova', 'Orion', 'Lyra', 'Vega'].indexed)
        {
          'id': 'demo-$index',
          'name': '$name · demo',
          'score': (weekly ? 970 : 590) - index * (weekly ? 50 : 35),
          'routes': weekly ? 5 : 3,
          'moves': (weekly ? 70 : 42) + index * 9,
          'demo': true,
        },
    ];
    final mine = _results.values.where(
      (r) => r['mode'] == mode && r['period'] == period,
    );
    entries.add({
      'id': pilotId,
      'name': callsign!,
      'score': mine.fold<int>(0, (n, r) => n + (r['score'] as int)),
      'routes': mine.length,
      'moves': mine.fold<int>(0, (n, r) => n + (r['moves'] as int)),
      'demo': true,
    });
    entries.sort((a, b) {
      final score = (b['score'] as int).compareTo(a['score'] as int);
      if (score != 0) return score;
      final routes = (b['routes'] as int).compareTo(a['routes'] as int);
      if (routes != 0) return routes;
      return (a['moves'] as int).compareTo(b['moves'] as int);
    });
    return {
      'mode': mode,
      'period': period,
      'entries': entries,
      'pilotId': pilotId,
      'demo': true,
    };
  }

  Future<void> submit({
    required String mode,
    required String period,
    required int index,
    required List<int> actions,
    String layout = 'planet-v4',
  }) async {
    await load();
    if (!joined) return;
    if (!['daily', 'weekly'].contains(mode) ||
        !['planet-v4', 'planet-v5'].contains(layout) ||
        period != _period(mode) ||
        index < 0 ||
        index >= (mode == 'daily' ? 3 : 5) ||
        actions.isEmpty ||
        actions.length > 500) {
      throw const MockLeagueException(
        'Only current challenge routes enter the preview league.',
      );
    }
    final date = DateTime.parse('${period}T00:00:00Z');
    final day = date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final seed = day * 100 + (mode == 'weekly' ? 50 : 0) + index;
    var puzzle = layout == 'planet-v5'
        ? Puzzle.strategicPlanet(
            seed: seed,
            levelNumber: mode == 'weekly'
                ? VoyageProgression.weeklyLevel(index)
                : VoyageProgression.dailyLevel(index),
          )
        : Puzzle.planet(
            seed: seed,
            levelNumber: mode == 'weekly'
                ? PlanetV4Progression.weeklyLevel(index)
                : PlanetV4Progression.dailyLevel(index),
          );
    for (final action in actions) {
      if (action < 0 ||
          action >= puzzle.tiles.length ||
          puzzle.tiles[action].isLocked ||
          puzzle.evaluate().solved) {
        throw const MockLeagueException('This route could not be replayed.');
      }
      puzzle = puzzle.rotateAt(action);
    }
    if (!puzzle.evaluate().solved) {
      throw const MockLeagueException(
        'Finish the route before posting its preview score.',
      );
    }
    final result = <String, dynamic>{
      'mode': mode,
      'period': period,
      'index': index,
      'layout': layout,
      'score': puzzle.scoreForMoves(actions.length),
      'moves': actions.length,
    };
    final key = _key(result), previous = _results[_key(result)];
    if (previous == null ||
        (result['score'] as int) > (previous['score'] as int) ||
        result['score'] == previous['score'] &&
            actions.length < (previous['moves'] as int)) {
      _results[key] = result;
      final oldest = _now().toUtc().subtract(const Duration(days: 90));
      _results.removeWhere(
        (_, r) => DateTime.parse('${r['period']}T00:00:00Z').isBefore(oldest),
      );
      await _save();
    }
  }

  Future<void> leave() async {
    await load();
    joined = false;
    _results.clear();
    await _writes.catchError((Object _) {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}

class MockLeagueException implements Exception {
  const MockLeagueException(this.message);
  final String message;
  @override
  String toString() => message;
}
