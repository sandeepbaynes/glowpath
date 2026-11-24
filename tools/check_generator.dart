import 'dart:convert';

import 'package:glowpath/game/puzzle.dart';

/// Prints a stable corpus for byte-for-byte native/JavaScript comparison.
/// Run from the project root:
///
/// mkdir -p build/checks
/// dart run tools/check_generator.dart > build/checks/generator-native.json
/// dart compile js tools/check_generator.dart -o build/checks/check_generator.js
/// node build/checks/check_generator.js > build/checks/generator-js.json
/// cmp build/checks/generator-native.json build/checks/generator-js.json
void main() {
  const cases = <({int seed, int level, Difficulty difficulty})>[
    (seed: 0, level: 1, difficulty: Difficulty.gentle),
    (seed: -1, level: 30, difficulty: Difficulty.bright),
    (seed: 2832, level: 2, difficulty: Difficulty.gentle),
    (seed: 2832, level: 2, difficulty: Difficulty.balanced),
    (seed: 2832, level: 2, difficulty: Difficulty.bright),
    (seed: 2077900, level: 8, difficulty: Difficulty.balanced),
    (seed: 2077901, level: 11, difficulty: Difficulty.balanced),
    (seed: 2077902, level: 14, difficulty: Difficulty.balanced),
    (seed: 2147483647, level: 17, difficulty: Difficulty.bright),
    (seed: 2147483648, level: 1, difficulty: Difficulty.gentle),
    (seed: 4294967295, level: 30, difficulty: Difficulty.balanced),
    (seed: -2147483648, level: 10000, difficulty: Difficulty.bright),
  ];

  final snapshots = cases.map((entry) {
    final puzzle = Puzzle.generate(
      seed: entry.seed,
      levelNumber: entry.level,
      difficulty: entry.difficulty,
    );
    if (puzzle.evaluate().solved || !puzzle.solvedCopy().evaluate().solved) {
      throw StateError('Invalid generated board for $entry.');
    }
    return {
      'seed': puzzle.seed,
      'level': puzzle.levelNumber,
      'difficulty': entry.difficulty.name,
      'size': puzzle.size,
      'startRow': puzzle.startRow,
      'endRow': puzzle.endRow,
      'starIndices': puzzle.starIndices.toList()..sort(),
      'tiles': puzzle.tiles
          .map((tile) => [tile.baseMask, tile.rotation, tile.isPath])
          .toList(),
      'connections': puzzle.tiles.map((tile) => tile.connections).toList(),
      'solutionRotations': puzzle.solutionRotations,
      'parMoves': puzzle.parMoves,
      'label': puzzle.label,
    };
  }).toList();

  // ignore: avoid_print
  print(
    jsonEncode({
      'generatorVersion': puzzleGeneratorVersion,
      'cases': snapshots,
    }),
  );
}
