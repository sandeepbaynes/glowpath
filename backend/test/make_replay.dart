// Standalone validator shares the exact mobile rule sources.
// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';

import '../../lib/game/puzzle.dart';
import '../../lib/game/voyage_progression.dart';

void main(List<String> args) {
  final strategic = args.contains("--strategic");
  const period = '2026-11-22';
  final day =
      DateTime.parse('${period}T00:00:00Z').millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  var puzzle = strategic
      ? Puzzle.strategicPlanet(
          seed: day * 100,
          levelNumber: VoyageProgression.dailyLevel(0),
        )
      : Puzzle.planet(
          seed: day * 100,
          levelNumber: PlanetV4Progression.dailyLevel(0),
        );
  final actions = <int>[];
  for (final action in puzzle.solutionActions) {
    if (puzzle.evaluate().solved) break;
    actions.add(action);
    puzzle = puzzle.rotateAt(action);
  }
  stdout.writeln(
    jsonEncode({
      'mode': 'daily',
      'period': period,
      'index': 0,
      'layout': strategic ? 'planet-v5' : 'planet-v4',
      'assisted': false,
      'actions': actions,
    }),
  );
}
