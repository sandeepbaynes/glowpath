import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mission.dart';

/// Owns plans and flight outcomes, but never starts a timer or an animation.
class MissionController extends ChangeNotifier {
  MissionController({
    SharedPreferences? preferences,
    DateTime Function()? now,
    Future<bool> Function(String snapshot)? snapshotWriter,
  }) : this._(preferences, now ?? DateTime.now, snapshotWriter);

  MissionController._(this._preferences, this._now, this._snapshotWriter) {
    _dailyDate = _date(_now());
  }

  static const storageKey = 'glowpath.missions.v1';
  SharedPreferences? _preferences;
  final DateTime Function() _now;
  final Future<bool> Function(String snapshot)? _snapshotWriter;
  Future<void>? _loading;
  Future<void> _saveQueue = Future.value();
  bool _ready = false;
  bool _disposed = false;
  bool _saveError = false;
  bool _isDaily = false;
  int _highestUnlocked = 1;
  _Round _campaignRound = _Round(Mission.campaign(1));
  _Round? _dailyRound;
  late String _dailyDate;
  final Set<int> _completedLevels = {};
  final Set<String> _dailyWins = {};

  _Round get _round => _isDaily ? _dailyRound! : _campaignRound;
  bool get ready => _ready;
  bool get saveError => _saveError;
  Mission get mission => _round.mission;
  int get currentLevel => mission.number;
  int get campaignLevel => _campaignRound.mission.number;
  int get highestUnlocked => _highestUnlocked;
  List<int> get rotations =>
      List.unmodifiable(mission.cells.map((cell) => cell.rotation));
  int get moves => _round.moves;
  bool get assisted => _round.assisted;
  int get attempt => _round.attempt;
  FlightResult? get flightResult => _round.result;
  bool get canEdit => _ready && !_disposed && _round.result == null;
  bool get canUndo => canEdit && _round.history.isNotEmpty;
  int get stars => 3 * (_completedLevels.length + _dailyWins.length);
  Set<int> get completedLevels => Set.unmodifiable(_completedLevels);
  bool get isDaily => _isDaily;
  String get dailyDate => _dailyDate;
  bool get dailyCompleted => _dailyWins.contains(_dailyDate);
  DateTime get dailyResetAt =>
      DateTime.parse('${_dailyDate}T00:00:00Z').add(const Duration(days: 1));

  Future<void> load() => _loading ??= Future<void>.microtask(_load);

  Future<void> _load() async {
    if (_disposed) return;
    try {
      _preferences ??= await SharedPreferences.getInstance();
      if (_disposed) return;
      final raw = _preferences!.get(storageKey);
      if (raw is String) {
        try {
          final data = jsonDecode(raw);
          if (data is Map<String, dynamic> && data['schemaVersion'] == 1) {
            final completed = data['completed'];
            if (completed is List) {
              _completedLevels.addAll(
                completed.whereType<int>().where(
                  (level) => level >= 1 && level <= Mission.campaignCount,
                ),
              );
            }
            _highestUnlocked = _completedLevels.isEmpty
                ? 1
                : math.min(
                    Mission.campaignCount,
                    _completedLevels.reduce(math.max) + 1,
                  );
            final wins = data['dailyWins'];
            if (wins is List) {
              _dailyWins.addAll(
                wins.whereType<String>().where(
                  (date) => _validDate(date) != null,
                ),
              );
            }
            _campaignRound = _Round(Mission.campaign(_highestUnlocked));
            if (data['campaignVersion'] == Mission.campaignVersion) {
              _campaignRound =
                  _decodeRound(data['campaign'], maxLevel: _highestUnlocked) ??
                  _campaignRound;
              final daily = data['daily'];
              if (daily is Map<String, dynamic>) {
                final date = _validDate(daily['date']);
                if (date != null) {
                  final round = _decodeRound(
                    daily['round'],
                    maxLevel: Mission.campaignCount,
                  );
                  if (round != null &&
                      round.mission.number == _dailyNumber(date)) {
                    _dailyDate = date;
                    _dailyRound = round;
                  }
                }
              }
              _isDaily = data['isDaily'] == true && _dailyRound != null;
            }
            // A successful result and its reward are saved atomically. Invalid
            // saves cannot fabricate a completed flight without its progress.
            if (_campaignRound.result?.success == true &&
                !_completedLevels.contains(_campaignRound.mission.number)) {
              _campaignRound.result = null;
            }
            if (_dailyRound?.result?.success == true &&
                !_dailyWins.contains(_dailyDate)) {
              _dailyRound!.result = null;
            }
          }
        } on FormatException {
          // Keep the default campaign usable if saved JSON is damaged.
        }
      }
    } catch (_) {
      _saveError = true;
    }
    if (_disposed) return;
    _ready = true;
    _changed();
  }

  bool turn(int index) {
    if (!canEdit ||
        index < 0 ||
        index >= mission.cells.length ||
        !mission.cells[index].rotatable) {
      return false;
    }
    _remember();
    final cells = mission.cells.toList();
    cells[index] = cells[index].rotated();
    _round.mission = mission.copyWithCells(cells);
    _round.moves++;
    _changed();
    return true;
  }

  bool undo() {
    if (!canUndo) return false;
    final move = _round.history.removeLast();
    _round.mission = move.mission;
    _round.moves = move.moves;
    _changed();
    return true;
  }

  int? get suggestedHintIndex {
    if (!canEdit) return null;
    final reference = mission.solvedCopy();
    final candidates = mission.referencePath.where(
      (index) =>
          mission.cells[index].rotatable &&
          !_sameOrientation(mission.cells[index], reference.cells[index]),
    );
    return candidates.isEmpty ? null : candidates.first;
  }

  bool requestHint() {
    if (suggestedHintIndex == null) return false;
    _round.assisted = true;
    _changed();
    return true;
  }

  bool hint() {
    final index = suggestedHintIndex;
    if (index == null) return false;
    final reference = mission.solvedCopy();
    _remember();
    final cells = mission.cells.toList();
    var turns = 0;
    while (!_sameOrientation(cells[index], reference.cells[index]) &&
        turns < 4) {
      cells[index] = cells[index].rotated();
      turns++;
    }
    _round.mission = mission.copyWithCells(cells);
    _round.moves += turns;
    _round.assisted = true;
    _changed();
    return true;
  }

  /// Resolves once per attempt. The UI animates this immutable result and can
  /// lock its own controls while doing so; no progress is earned by planning.
  FlightResult launch() {
    if (!_ready || _disposed) {
      throw StateError('Load the mission controller before launching.');
    }
    if (_round.result != null) return _round.result!;
    final result = mission.launch(attempt: attempt);
    _round.result = result;
    if (result.success) {
      if (_isDaily) {
        _dailyWins.add(_dailyDate);
      } else {
        _completedLevels.add(currentLevel);
        _highestUnlocked = math.max(
          _highestUnlocked,
          math.min(Mission.campaignCount, currentLevel + 1),
        );
      }
    }
    _changed();
    return result;
  }

  /// Keeps the corrected plan, assistance and undo history for the next attempt.
  bool retry() {
    if (!_ready || _disposed || _round.result == null) return false;
    _round.result = null;
    _round.attempt++;
    _changed();
    return true;
  }

  bool next() {
    if (!_ready || _disposed || _round.result?.success != true) return false;
    if (_isDaily) return setDaily(false);
    if (currentLevel >= Mission.campaignCount) return false;
    _campaignRound = _Round(Mission.campaign(currentLevel + 1));
    _changed();
    return true;
  }

  bool selectUnlocked(int level) {
    if (!_ready || _disposed || level < 1 || level > _highestUnlocked) {
      return false;
    }
    if (!_isDaily && level == currentLevel) return false;
    if (level != _campaignRound.mission.number) {
      _campaignRound = _Round(Mission.campaign(level));
    }
    _isDaily = false;
    _changed();
    return true;
  }

  bool setDaily(bool daily) {
    if (!_ready || _disposed || _isDaily == daily) return false;
    if (daily) {
      final today = _date(_now());
      if (_dailyRound == null ||
          (_dailyDate != today && _dailyRound!.result?.success == true)) {
        _dailyDate = today;
        _dailyRound = _Round(Mission.campaign(_dailyNumber(today)));
      }
    }
    _isDaily = daily;
    _changed();
    return true;
  }

  void _remember() => _round.history.add(_Move(mission, moves));

  static bool _sameOrientation(MissionCell first, MissionCell second) =>
      first.connections == second.connections && first.input == second.input;

  static String _date(DateTime now) =>
      now.toUtc().toIso8601String().split('T').first;
  static String? _validDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final date = DateTime.tryParse('${value}T00:00:00Z');
    return date != null && _date(date) == value ? value : null;
  }

  static int _dailyNumber(String date) =>
      (DateTime.parse('${date}T00:00:00Z').millisecondsSinceEpoch ~/
              Duration.millisecondsPerDay) %
          Mission.campaignCount +
      1;

  static _Round? _decodeRound(Object? value, {required int maxLevel}) {
    if (value is! Map<String, dynamic>) return null;
    final level = value['level'];
    final moves = value['moves'];
    final attempt = value['attempt'];
    if (level is! int ||
        level < 1 ||
        level > maxLevel ||
        moves is! int ||
        moves < 0 ||
        moves > 1000000 ||
        attempt is! int ||
        attempt < 1 ||
        attempt > 1000000) {
      return null;
    }
    final initial = Mission.campaign(level);
    final mission = _restoreRotations(initial, value['rotations']);
    if (mission == null) return null;
    final round = _Round(mission)
      ..moves = moves
      ..attempt = attempt
      ..assisted = value['assisted'] == true;
    final history = value['history'];
    if (history is List) {
      var previousCount = -1;
      for (final item in history) {
        if (item is! Map<String, dynamic>) {
          round.history.clear();
          break;
        }
        final count = item['moves'];
        final past = _restoreRotations(initial, item['rotations']);
        if (count is! int ||
            count <= previousCount ||
            count >= moves ||
            past == null) {
          round.history.clear();
          break;
        }
        round.history.add(_Move(past, count));
        previousCount = count;
      }
    }
    if (value['launched'] == true) {
      round.result = mission.launch(attempt: attempt);
    }
    return round;
  }

  static Mission? _restoreRotations(Mission initial, Object? value) {
    if (value is! List || value.length != initial.cells.length) return null;
    final rotations = <int>[];
    for (var index = 0; index < value.length; index++) {
      final rotation = value[index];
      if (rotation is! int ||
          rotation < 0 ||
          rotation > 3 ||
          (!initial.cells[index].rotatable &&
              rotation != initial.cells[index].rotation)) {
        return null;
      }
      rotations.add(rotation);
    }
    return initial.withRotations(rotations);
  }

  Map<String, dynamic> _encodeRound(_Round round) => {
    'level': round.mission.number,
    'rotations': round.mission.cells.map((cell) => cell.rotation).toList(),
    'moves': round.moves,
    'assisted': round.assisted,
    'attempt': round.attempt,
    'launched': round.result != null,
    'history': [
      for (final move in round.history)
        {
          'moves': move.moves,
          'rotations': move.mission.cells.map((cell) => cell.rotation).toList(),
        },
    ],
  };

  String _snapshot() => jsonEncode({
    'schemaVersion': 1,
    'campaignVersion': Mission.campaignVersion,
    'completed': _completedLevels.toList()..sort(),
    'dailyWins': _dailyWins.toList()..sort(),
    'isDaily': _isDaily,
    'campaign': _encodeRound(_campaignRound),
    'daily': _dailyRound == null
        ? null
        : {'date': _dailyDate, 'round': _encodeRound(_dailyRound!)},
  });

  void _changed() {
    _enqueueSave();
    if (!_disposed) notifyListeners();
  }

  void _setSaveError(bool value) {
    if (_saveError == value) return;
    _saveError = value;
    if (!_disposed) notifyListeners();
  }

  void _enqueueSave() {
    final preferences = _preferences;
    if (preferences == null) {
      _setSaveError(true);
      return;
    }
    final snapshot = _snapshot();
    _saveQueue = _saveQueue.then((_) async {
      try {
        final saved =
            await (_snapshotWriter?.call(snapshot) ??
                preferences.setString(storageKey, snapshot));
        _setSaveError(!saved);
      } catch (_) {
        _setSaveError(true);
      }
    });
  }

  Future<void> flush() async {
    await load();
    await _drain();
    if (_saveError && !_disposed && _preferences != null) {
      _enqueueSave();
      await _drain();
    }
  }

  Future<void> _drain() async {
    while (true) {
      final pending = _saveQueue;
      await pending;
      if (identical(pending, _saveQueue)) return;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _Round {
  _Round(this.mission);
  Mission mission;
  int moves = 0;
  int attempt = 1;
  bool assisted = false;
  FlightResult? result;
  final List<_Move> history = [];
}

class _Move {
  const _Move(this.mission, this.moves);
  final Mission mission;
  final int moves;
}
