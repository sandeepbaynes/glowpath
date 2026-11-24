import 'package:flutter_test/flutter_test.dart';

import 'package:glowpath/game/puzzle.dart';

void main() {
  group('authored introductions', () {
    test(
      'three lessons have exactly three stars and increasing reference turns',
      () {
        for (var level = 1; level <= 3; level++) {
          final puzzle = Puzzle.introduction(
            levelNumber: level,
            seed: 500 + level,
          );
          expect(puzzle.size, 5);
          expect(puzzle.tiles.length, 25);
          expect(puzzle.starIndices.length, 3);
          expect(puzzle.evaluate().solved, isFalse);
          expect(puzzle.parMoves, [1, 3, 5][level - 1]);
          expect(puzzle.solvedCopy().evaluate().solved, isTrue);
          expect(
            puzzle.solvedCopy().evaluate().collectedStars,
            puzzle.starIndices,
          );
          final turns = List<int>.generate(
            25,
            (index) =>
                (puzzle.solutionRotations[index] -
                    puzzle.tiles[index].rotation) %
                4,
          ).fold(0, (total, count) => total + count);
          expect(turns, puzzle.parMoves);
        }
      },
    );

    test(
      'the first lesson launches through every star with one clockwise tap',
      () {
        final puzzle = Puzzle.introduction(levelNumber: 1);
        final launch = puzzle.startRow * puzzle.size;
        expect(puzzle.evaluate().litCells, isEmpty);
        final tiles = puzzle.tiles.toList();
        tiles[launch] = tiles[launch].rotated();
        final status = puzzle.copyWithTiles(tiles).evaluate();
        expect(status.solved, isTrue);
        expect(status.collectedStars, puzzle.starIndices);
        expect(status.litCells.length, 5);
      },
    );

    test(
      'authored layout is stable across identifiers and rejects other levels',
      () {
        for (var level = 1; level <= 3; level++) {
          final first = Puzzle.introduction(levelNumber: level, seed: -1);
          final second = Puzzle.introduction(levelNumber: level, seed: 2832);
          expect(_signature(first), _signature(second));
          expect(first.starIndices, second.starIndices);
          expect(first.solutionRotations, second.solutionRotations);
        }
        expect(() => Puzzle.introduction(levelNumber: 0), throwsArgumentError);
        expect(() => Puzzle.introduction(levelNumber: 4), throwsArgumentError);
        expect(puzzleGeneratorVersion, 2);
      },
    );
  });

  group('tile geometry', () {
    test('a corner rotates clockwise through all four orientations', () {
      const original = Tile(baseMask: north | east);
      var tile = original;
      expect(tile.connections, north | east);
      tile = tile.rotated();
      expect(tile.connections, east | south);
      tile = tile.rotated();
      expect(tile.connections, south | west);
      tile = tile.rotated();
      expect(tile.connections, west | north);
      tile = tile.rotated();
      expect(tile.connections, original.connections);
      expect(tile.rotation, 0);
      expect(original.rotation, 0);
    });

    test('straight pipes alternate horizontal and vertical', () {
      const vertical = Tile(baseMask: north | south);
      expect(vertical.rotated().connections, east | west);
      expect(vertical.rotated().rotated().connections, north | south);
      expect(
        const Tile(baseMask: north | east, rotation: -1).connections,
        north | west,
      );
    });
  });

  group('generation', () {
    test(
      'version 2 keeps the verified native and JavaScript board snapshot',
      () {
        final puzzle = Puzzle.generate(seed: 2832, levelNumber: 2);
        expect(
          {
            'generatorVersion': puzzleGeneratorVersion,
            'size': puzzle.size,
            'startRow': puzzle.startRow,
            'endRow': puzzle.endRow,
            'starIndices': puzzle.starIndices.toList()..sort(),
            'tiles': puzzle.tiles
                .map((tile) => [tile.baseMask, tile.rotation, tile.isPath])
                .toList(),
            'solutionRotations': puzzle.solutionRotations,
            'parMoves': puzzle.parMoves,
            'label': puzzle.label,
          },
          {
            'generatorVersion': 2,
            'size': 5,
            'startRow': 1,
            'endRow': 0,
            'starIndices': [6, 12, 14],
            'tiles': [
              [3, 0, false],
              [3, 0, true],
              [3, 2, true],
              [3, 3, false],
              [3, 1, true],
              [5, 0, true],
              [3, 3, true],
              [5, 0, true],
              [5, 0, false],
              [5, 3, true],
              [5, 2, false],
              [3, 0, false],
              [3, 0, true],
              [3, 3, true],
              [5, 0, true],
              [5, 1, false],
              [5, 2, false],
              [5, 0, false],
              [5, 0, true],
              [5, 0, true],
              [3, 1, false],
              [5, 1, false],
              [5, 3, false],
              [3, 0, true],
              [3, 2, true],
            ],
            'solutionRotations': [
              0,
              1,
              2,
              3,
              1,
              1,
              3,
              0,
              0,
              0,
              2,
              0,
              0,
              2,
              0,
              1,
              2,
              0,
              0,
              0,
              1,
              1,
              3,
              0,
              3,
            ],
            'parMoves': 7,
            'label': 'Warm current',
          },
        );
      },
    );

    test('version 2 normalizes signed seeds to the same uint32 stream', () {
      expect(puzzleGeneratorVersion, 2);
      final signed = Puzzle.generate(seed: -1, levelNumber: 17);
      final unsigned = Puzzle.generate(seed: 0xffffffff, levelNumber: 17);
      expect(_signature(signed), _signature(unsigned));
      expect(signed.starIndices, unsigned.starIndices);
      expect(signed.solutionRotations, unsigned.solutionRotations);
      expect(signed.parMoves, unsigned.parMoves);
    });

    test('the same seed, level, and difficulty reproduce the whole puzzle', () {
      final first = Puzzle.generate(
        seed: -2048,
        levelNumber: 17,
        difficulty: Difficulty.bright,
      );
      final second = Puzzle.generate(
        seed: -2048,
        levelNumber: 17,
        difficulty: Difficulty.bright,
      );
      expect(_signature(first), _signature(second));
      expect(first.starIndices, second.starIndices);
      expect(first.solutionRotations, second.solutionRotations);
      expect(first.parMoves, second.parMoves);
      expect(first.label, second.label);
    });

    test(
      '100 seeds in every difficulty have valid, initially unsolved routes',
      () {
        for (final difficulty in Difficulty.values) {
          for (var seed = 0; seed < 100; seed++) {
            final puzzle = Puzzle.generate(
              seed: seed,
              levelNumber: seed % 30 + 1,
              difficulty: difficulty,
            );
            final context = '$difficulty, seed $seed';
            expect(puzzle.size, 5, reason: context);
            expect(puzzle.tiles.length, 25, reason: context);
            expect(puzzle.evaluate().solved, isFalse, reason: context);
            expect(puzzle.parMoves, greaterThan(0), reason: context);
            expect(puzzle.starIndices.length, 3, reason: context);

            final solved = puzzle.solvedCopy();
            final status = solved.evaluate();
            expect(status.solved, isTrue, reason: context);
            expect(status.blockedAt, isNull, reason: context);
            expect(status.collectedStars, puzzle.starIndices, reason: context);
            expect(status.litCells, <int>{
              for (var i = 0; i < puzzle.tiles.length; i++)
                if (puzzle.tiles[i].isPath) i,
            }, reason: context);
            expect(
              puzzle.starIndices.contains(puzzle.startRow * puzzle.size),
              isFalse,
              reason: context,
            );
            expect(
              puzzle.starIndices.contains(
                puzzle.endRow * puzzle.size + puzzle.size - 1,
              ),
              isFalse,
              reason: context,
            );
          }
        }
      },
    );

    test('30 levels vary their routes and progressively scramble more tiles', () {
      for (final difficulty in Difficulty.values) {
        final routes = <String>{};
        var previousScrambled = 0;
        for (var level = 1; level <= 30; level++) {
          final puzzle = Puzzle.generate(
            seed: 41,
            levelNumber: level,
            difficulty: difficulty,
          );
          final solved = puzzle.solvedCopy();
          final scrambled = List<int>.generate(25, (index) => index)
              .where(
                (index) =>
                    puzzle.tiles[index].isPath &&
                    puzzle.tiles[index].connections !=
                        solved.tiles[index].connections,
              )
              .length;
          expect(scrambled, greaterThanOrEqualTo(previousScrambled));
          previousScrambled = scrambled;
          routes.add(
            '${puzzle.startRow}/${puzzle.endRow}/'
            '${solved.tiles.map((tile) => tile.isPath ? tile.connections : 0).join(',')}',
          );
        }
        expect(routes.length, greaterThanOrEqualTo(25));
        expect(previousScrambled, greaterThan(10));
      }
    });

    test('high levels and negative seeds remain bounded and solvable', () {
      for (final seed in [-1000000, -1, 0, 1, 1000000]) {
        final puzzle = Puzzle.generate(
          seed: seed,
          levelNumber: 10000,
          difficulty: Difficulty.bright,
        );
        expect(puzzle.solvedCopy().evaluate().solved, isTrue);
        expect(puzzle.evaluate().solved, isFalse);
      }
    });

    test('par is clockwise turns to the supplied reference solution', () {
      final puzzle = Puzzle.generate(seed: 93, levelNumber: 23);
      var turns = 0;
      for (var index = 0; index < puzzle.tiles.length; index++) {
        turns +=
            (puzzle.solutionRotations[index] - puzzle.tiles[index].rotation) %
            4;
      }
      expect(puzzle.parMoves, turns);
      expect(puzzle.solvedCopy().parMoves, puzzle.parMoves);
    });

    test('board collections are immutable and copies do not alias inputs', () {
      final puzzle = Puzzle.generate(seed: 5);
      final replacement = puzzle.tiles.toList();
      final copied = puzzle.copyWithTiles(replacement);
      final originalTile = copied.tiles.first;
      replacement[0] = replacement[0].rotated();
      expect(identical(copied.tiles.first, originalTile), isTrue);
      expect(() => puzzle.tiles.clear(), throwsUnsupportedError);
      expect(() => puzzle.starIndices.clear(), throwsUnsupportedError);
      expect(() => puzzle.solutionRotations.clear(), throwsUnsupportedError);
      expect(() => puzzle.copyWithTiles([]), throwsArgumentError);
      expect(
        () => Puzzle.generate(seed: 1, levelNumber: 0),
        throwsArgumentError,
      );
    });
  });

  group('light tracing', () {
    test('an entrance without a west connection lights no tiles', () {
      final puzzle = Puzzle.generate(seed: 19).solvedCopy();
      final tiles = puzzle.tiles.toList();
      final entrance = puzzle.startRow * puzzle.size;
      tiles[entrance] = const Tile(baseMask: north | south);
      final status = puzzle.copyWithTiles(tiles).evaluate();
      expect(status.solved, isFalse);
      expect(status.litCells, isEmpty);
      expect(status.collectedStars, isEmpty);
      expect(status.blockedAt, entrance);
    });

    test('a nonreciprocal neighbor stops light before that tile', () {
      final puzzle = Puzzle.generate(seed: 12).solvedCopy();
      final tiles = puzzle.tiles.toList();
      final entrance = puzzle.startRow * puzzle.size;
      final outgoing = tiles[entrance].connections & ~west;
      final next =
          entrance +
          switch (outgoing) {
            north => -puzzle.size,
            east => 1,
            south => puzzle.size,
            _ => throw StateError('Unexpected entrance direction.'),
          };
      tiles[next] = Tile(
        baseMask: outgoing == east ? north | south : east | west,
      );
      final status = puzzle.copyWithTiles(tiles).evaluate();
      expect(status.solved, isFalse);
      expect(status.litCells, {entrance});
      expect(status.blockedAt, next);
    });

    test('reaching the correct exit without every star does not solve', () {
      final puzzle =
          List<Puzzle>.generate(
            100,
            (seed) => Puzzle.generate(seed: seed),
          ).firstWhere(
            (puzzle) =>
                puzzle.startRow == puzzle.endRow &&
                puzzle.starIndices.any(
                  (cell) => cell ~/ puzzle.size != puzzle.startRow,
                ),
          );
      final tiles = puzzle.tiles.toList();
      for (var column = 0; column < puzzle.size; column++) {
        tiles[puzzle.startRow * puzzle.size + column] = const Tile(
          baseMask: east | west,
        );
      }
      final status = puzzle.copyWithTiles(tiles).evaluate();
      expect(status.collectedStars.length, lessThan(3));
      expect(status.solved, isFalse);
      expect(status.litCells.length, puzzle.size);
      expect(status.blockedAt, puzzle.endRow * puzzle.size + puzzle.size - 1);
    });

    test('light exiting at the wrong row is not a solution', () {
      final puzzle = List<Puzzle>.generate(
        100,
        (seed) => Puzzle.generate(seed: seed),
      ).firstWhere((puzzle) => puzzle.startRow != puzzle.endRow);
      final tiles = puzzle.tiles.toList();
      for (var column = 0; column < puzzle.size; column++) {
        tiles[puzzle.startRow * puzzle.size + column] = const Tile(
          baseMask: east | west,
        );
      }
      final status = puzzle.copyWithTiles(tiles).evaluate();
      expect(status.solved, isFalse);
      expect(status.blockedAt, puzzle.startRow * puzzle.size + puzzle.size - 1);
    });
  });

  test(
    'score has a 200-point ceiling, five-point penalties, and 100 floor',
    () {
      expect(puzzleScore(moves: 0, parMoves: 10), 200);
      expect(puzzleScore(moves: 10, parMoves: 10), 200);
      expect(puzzleScore(moves: 11, parMoves: 10), 195);
      expect(puzzleScore(moves: 29, parMoves: 10), 105);
      expect(puzzleScore(moves: 30, parMoves: 10), 100);
      expect(puzzleScore(moves: 1000, parMoves: 10), 100);
      final puzzle = Puzzle.generate(seed: 42);
      expect(puzzle.scoreForMoves(puzzle.parMoves), 200);
    },
  );
}

String _signature(Puzzle puzzle) =>
    '${puzzle.size}/${puzzle.startRow}/${puzzle.endRow}/'
    '${puzzle.tiles.map((tile) => '${tile.baseMask}:${tile.rotation}:${tile.isPath}').join(',')}';
