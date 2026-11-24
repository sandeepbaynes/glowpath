// Standalone validator shares the exact mobile rule sources.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';

import '../lib/game/puzzle.dart';
import '../lib/game/voyage_progression.dart';

/// Shared rule engine: never trust a client-supplied score or solved flag.
void main() async {
  try {
    final input = jsonDecode(
      await stdin.transform(utf8.decoder).join(),
    ) as Map<String, dynamic>;
    final mode = input['mode'];
    final layout = input['layout'];
    final index = input['index'];
    final period = input['period'];
    final actions = input['actions'];
    if (!['planet-v4', 'planet-v5'].contains(layout) ||
        (mode != 'daily' && mode != 'weekly') ||
        index is! int ||
        index < 0 ||
        index >= (mode == 'daily' ? 3 : 5) ||
        period is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(period) ||
        actions is! List ||
        actions.isEmpty ||
        actions.length > 500) {
      throw const FormatException('Invalid replay');
    }
    final date = DateTime.parse('${period}T00:00:00Z');
    if (date.toIso8601String().split('T').first != period ||
        (mode == 'weekly' && date.weekday != DateTime.monday)) {
      throw const FormatException('Invalid period');
    }
    final day = date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final seed = day * 100 + (mode == 'weekly' ? 50 : 0) + index;
    final strategic = layout == 'planet-v5';
    final level = mode == 'weekly'
        ? (strategic
              ? VoyageProgression.weeklyLevel(index)
              : PlanetV4Progression.weeklyLevel(index))
        : (strategic
              ? VoyageProgression.dailyLevel(index)
              : PlanetV4Progression.dailyLevel(index));
    var puzzle = strategic
        ? Puzzle.strategicPlanet(seed: seed, levelNumber: level)
        : Puzzle.planet(seed: seed, levelNumber: level);
    for (final action in actions) {
      if (action is! int ||
          action < 0 ||
          action >= puzzle.tiles.length ||
          puzzle.tiles[action].isLocked ||
          puzzle.evaluate().solved) {
        throw const FormatException('Invalid action');
      }
      puzzle = puzzle.rotateAt(action);
    }
    if (!puzzle.evaluate().solved) {
      throw const FormatException('Route incomplete');
    }
    stdout.writeln(
      jsonEncode({
        'valid': true,
        'score': puzzle.scoreForMoves(actions.length),
        'moves': actions.length,
      }),
    );
  } catch (_) {
    stdout.writeln(jsonEncode({'valid': false}));
    exitCode = 1;
  }
}
