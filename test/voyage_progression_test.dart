import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/launch_clock.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/game/voyage_progression.dart';

void main() {
  test('board and relay unlocks have explicit teaching thresholds', () {
    for (final level in [
      1,
      5,
      6,
      9,
      10,
      14,
      15,
      16,
      19,
      20,
      25,
      35,
      50,
      10000,
    ]) {
      final plan = LegacyVoyageProgression.forLevel(level);
      final board = Puzzle.voyage(seed: 731, levelNumber: level);
      expect(
        board.size,
        level <= 5
            ? 3
            : level <= 15
            ? 4
            : 5,
      );
      expect(board.tiles.length, board.size * board.size);
      expect(
        board.tiles.where((tile) => tile.isLocked).length,
        plan.lockedRelays,
      );
      expect(
        board.tiles.where((tile) => tile.isOneWay).length,
        plan.oneWayRelays,
      );
      final solution = board.solvedCopy();
      for (var cell = 0; cell < board.tiles.length; cell++) {
        final tile = board.tiles[cell];
        if (tile.isLocked) {
          expect(tile.orientationMatches(solution.tiles[cell]), isTrue);
          expect(tile.rotated(), same(tile));
        }
        if (tile.isOneWay) {
          expect(
            tile.orientationMatches(solution.tiles[cell]),
            isFalse,
            reason: 'New relay types must participate in the puzzle',
          );
        }
      }
    }
  });

  test('first lesson takes exactly one turn for every seed and pace', () {
    for (final pace in Difficulty.values) {
      for (var seed = -50; seed < 250; seed++) {
        final board = Puzzle.voyage(
          seed: seed,
          levelNumber: 1,
          difficulty: pace,
        );
        expect(board.size, 3);
        expect(board.parMoves, 1, reason: '$pace/$seed');
        final tiles = board.tiles.toList();
        final entrance = board.startRow * board.size;
        tiles[entrance] = tiles[entrance].rotated();
        expect(
          board.copyWithTiles(tiles).evaluate().solved,
          isTrue,
          reason: '$pace/$seed',
        );
      }
    }
  });

  test(
    'progressive routes remain deterministic, unsolved and fairly solvable',
    () {
      for (final pace in Difficulty.values) {
        for (final level in [
          ...List.generate(60, (i) => i + 1),
          999,
          10000,
          1000000,
        ]) {
          for (var seed = -4; seed < 16; seed++) {
            final board = Puzzle.voyage(
              seed: seed,
              levelNumber: level,
              difficulty: pace,
            );
            final again = Puzzle.voyage(
              seed: seed,
              levelNumber: level,
              difficulty: pace,
            );
            final context = '$pace / $level / $seed';
            expect(_signature(board), _signature(again), reason: context);
            expect(board.evaluate().solved, isFalse, reason: context);
            expect(board.parMoves, greaterThan(0), reason: context);
            expect(board.starIndices, hasLength(3), reason: context);
            final solved = board.solvedCopy();
            expect(solved.evaluate().solved, isTrue, reason: context);
            expect(
              solved.evaluate().collectedStars,
              board.starIndices,
              reason: context,
            );
            expect(solved.evaluate().litCells, {
              for (var i = 0; i < board.tiles.length; i++)
                if (board.tiles[i].isPath) i,
            }, reason: context);
            var taps = 0;
            for (var i = 0; i < board.tiles.length; i++) {
              var tile = board.tiles[i];
              var turns = 0;
              while (!tile.orientationMatches(solved.tiles[i]) && turns < 4) {
                tile = tile.rotated();
                turns++;
                taps++;
              }
              expect(
                tile.orientationMatches(solved.tiles[i]),
                isTrue,
                reason: context,
              );
            }
            expect(taps, board.parMoves, reason: context);
          }
        }
      }
    },
  );

  test(
    'one-way relays reject reverse flow even when their channels connect',
    () {
      final solved = Puzzle.voyage(seed: 93, levelNumber: 20).solvedCopy();
      final index = solved.tiles.indexWhere((tile) => tile.isOneWay);
      final old = solved.tiles[index];
      final reversed = Tile(
        baseMask: old.baseMask,
        rotation: old.rotation,
        isPath: old.isPath,
        oneWayEntry: old.baseMask & ~old.oneWayEntry,
      );
      expect(reversed.connections, old.connections);
      expect(reversed.orientationMatches(old), isFalse);
      final tiles = solved.tiles.toList()..[index] = reversed;
      final result = solved.copyWithTiles(tiles).evaluate();
      expect(result.solved, isFalse);
      expect(result.blockedAt, index);
      expect(result.litCells.contains(index), isFalse);
      expect(solved.evaluate().solved, isTrue);
    },
  );

  test('rotation copies preserve locks and directional inlets', () {
    const directional = Tile(baseMask: north | south, oneWayEntry: north);
    final rotated = directional.withRotation(3);
    expect(rotated.oneWayEntry, north);
    expect(rotated.entryDirection, west);
    expect(rotated.connections, east | west);
    const locked = Tile(baseMask: north | east, rotation: 2, isLocked: true);
    expect(locked.withRotation(2).isLocked, isTrue);
    expect(locked.rotated(), same(locked));
  });

  test('new planets reset to thirty seconds before three timed legs', () {
    int budget(int level) => launchBudget(
      difficulty: Difficulty.balanced,
      level: level,
      progressive: true,
    ).inSeconds;
    expect(budget(1), 30);
    expect(budget(5), 30);
    expect(budget(6), 27);
    expect(budget(15), 24);
    expect(budget(16), 30);
    expect(budget(1000000), 27);
    for (final pace in Difficulty.values) {
      for (var level = 1; level <= 200; level++) {
        expect(
          launchBudget(
            difficulty: pace,
            level: level,
            progressive: true,
          ).inSeconds,
          inInclusiveRange(18, 30),
        );
      }
    }
  });

  test('invalid voyage levels are rejected', () {
    expect(() => Puzzle.voyage(seed: 1, levelNumber: 0), throwsArgumentError);
    expect(() => Puzzle.voyage(seed: 1, levelNumber: -1), throwsArgumentError);
  });
}

String _signature(Puzzle board) =>
    '${board.size}/${board.startRow}/${board.endRow}/'
    '${board.tiles.map((t) => '${t.baseMask}:${t.rotation}:${t.isPath}:${t.isLocked}:${t.oneWayEntry}').join(',')}/'
    '${board.starIndices.join(',')}/${board.solutionRotations.join(',')}/${board.parMoves}';
