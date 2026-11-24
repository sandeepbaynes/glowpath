import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a partial trace aligns only touched lanes and records actual quarter turns', () {
    final board = line();
    final plan = board.planTrace([3, 4]);
    expect(plan.accepted, isTrue);
    expect(plan.puzzle.tiles[3].connections, east | west);
    expect(plan.puzzle.tiles[4].connections, east | west);
    expect(plan.puzzle.tiles[5].rotation, board.tiles[5].rotation);
    expect(plan.puzzle.evaluate().solved, isFalse);
    expect(plan.actions, [3, 4]);
    expect(plan.changedCells, {3, 4});
    expect(board.tiles[3].connections, north | south);
    expect(board.planTrace([3]).actions, isEmpty);
    verifyReplay(board, plan);
  });

  test(
    'impossible bends, diagonal gaps, edge wraps and invalid cells are atomic',
    () {
      final board = line();
      for (final cells in [
        [3, 4, 1],
        [3, 1],
        [2, 3],
        [3, 4, 3],
        [-1, 0],
        [8, 9],
        <int>[],
      ]) {
        final plan = board.planTrace(cells);
        expect(plan.accepted, isFalse, reason: '$cells');
        expect(identical(plan.puzzle, board), isTrue);
        expect(plan.actions, isEmpty);
        expect(plan.changedCells, isEmpty);
      }
    },
  );

  test('fixed and directed channels retain their real constraints', () {
    final fixed = line(
      overrides: {4: const Tile(baseMask: east | west, isLocked: true)},
    );
    final valid = fixed.planTrace([3, 4, 5]);
    expect(valid.accepted, isTrue);
    expect(valid.actions, [3, 5]);
    expect(valid.puzzle.evaluate().solved, isTrue);
    expect(
      line(overrides: {4: const Tile(baseMask: north | south, isLocked: true)})
          .planTrace([3, 4, 5])
          .accepted,
      isFalse,
    );
    final directed = pathBoard(
      [3, 4, 1],
      overrides: {4: const Tile(baseMask: north | east, oneWayEntry: north)},
      endRow: 2,
    );
    final good = directed.planTrace([3, 4, 1]);
    expect(good.accepted, isTrue);
    expect(good.puzzle.tiles[4].entryDirection, west);
    expect(good.puzzle.outgoingAt(4, west), north);
    final reversed = directed
        .copyWithTiles([
          for (var i = 0; i < 9; i++)
            i == 4
                ? const Tile(
                    baseMask: north | west,
                    oneWayEntry: north,
                    isLocked: true,
                  )
                : directed.tiles[i],
        ])
        .planTrace([3, 4, 1]);
    expect(reversed.accepted, isFalse);
  });

  test('twins and triplets rotate together, while conflicting earlier lanes reject', () {
    for (final members in [
      <int>{3, 5},
      <int>{3, 4, 5},
    ]) {
      final board = line(
        overrides: {
          for (final i in members)
            i: const Tile(baseMask: north | south, couplingGroup: 7),
        },
      );
      final plan = board.planTrace([3, 4, 5]);
      expect(plan.accepted, isTrue);
      expect(plan.actions.where(members.contains).length, 1);
      expect(plan.puzzle.evaluate().solved, isTrue);
      verifyReplay(board, plan);
    }
    final conflict = line(
      overrides: {
        3: const Tile(baseMask: north | south, couplingGroup: 7),
        4: const Tile(baseMask: east | west, couplingGroup: 7),
      },
    ).planTrace([3, 4, 5]);
    expect(conflict.accepted, isFalse);
    final outside = line(
      overrides: {
        3: const Tile(baseMask: north | south, couplingGroup: 7),
        0: const Tile(baseMask: north | east, couplingGroup: 7),
      },
    ).planTrace([3, 4]);
    expect(outside.accepted, isTrue);
    expect(outside.changedCells, {0, 3, 4});
  });

  test(
    'backtracking recomputes from the gesture origin without leftover turns',
    () {
      final board = line(
        overrides: {
          3: const Tile(baseMask: east | west),
          4: const Tile(baseMask: north | east),
        },
      );
      final short = board.planTrace([3, 4]);
      final extended = board.planTrace([3, 4, 1]);
      expect(short.accepted, isTrue);
      expect(extended.accepted, isTrue);
      expect(
        short.puzzle.tiles[4].rotation,
        isNot(extended.puzzle.tiles[4].rotation),
      );
      expect(board.planTrace([3, 4]).actions, short.actions);
    },
  );

  test('independent bridges and crossways support a second distinct lane', () {
    for (final sample in [
      (path: [3, 4, 5, 2, 1, 4, 7, 8], kind: TileKind.bridge),
      (path: [3, 4, 1, 2, 5, 4, 7, 8], kind: TileKind.crossway),
    ]) {
      final board = pathBoard(
        sample.path,
        overrides: {4: Tile(baseMask: 15, kind: sample.kind)},
      );
      final plan = board.planTrace(sample.path);
      expect(plan.accepted, isTrue, reason: sample.kind.name);
      expect(plan.puzzle.evaluate().solved, isTrue);
      expect(plan.puzzle.evaluate().route, sample.path);
      expect(plan.puzzle.evaluate().litPorts[4], 15);
      verifyReplay(board, plan);
    }
    final bridge = pathBoard(
      [3, 4, 1],
      overrides: {4: const Tile(baseMask: 15, kind: TileKind.bridge)},
      endRow: 2,
    );
    expect(bridge.planTrace([3, 4, 1]).accepted, isFalse);
  });

  test(
    'gravity-selected forks and source-rotated crossings use actual routing',
    () {
      for (final well in [TileKind.blackHole, TileKind.whiteHole]) {
        final board = line(
          overrides: {
            0: Tile(baseMask: north | south, kind: well, rotation: 1),
            4: const Tile(
              baseMask: north | south | west,
              kind: TileKind.fork,
              gravityPeer: 0,
              isLocked: true,
            ),
            3: const Tile(baseMask: east | west),
          },
        );
        final next = well == TileKind.blackHole ? 1 : 7;
        expect(board.planTrace([3, 4, next]).accepted, isTrue);
        expect(board.planTrace([3, 4, next == 1 ? 7 : 1]).accepted, isFalse);
      }
      final board = line(
        overrides: {
          0: const Tile(
            baseMask: north | south,
            kind: TileKind.blackHole,
            rotation: 1,
          ),
          3: const Tile(baseMask: east | west),
          4: const Tile(
            baseMask: 15,
            kind: TileKind.crossway,
            gravityPeer: 0,
            isLocked: true,
          ),
        },
      );
      expect(board.planTrace([3, 4, 1]).accepted, isTrue);
      expect(board.planTrace([3, 4, 7]).accepted, isFalse);
    },
  );

  test('wormholes require the paired jump and preserve directed arrival', () {
    final board = pathBoard(
      [3, 4, 0, 1, 2],
      endRow: 0,
      overrides: {
        4: const Tile(
          baseMask: east | west,
          kind: TileKind.wormhole,
          portalPeer: 0,
          oneWayEntry: west,
        ),
        0: const Tile(
          baseMask: north | east,
          kind: TileKind.wormhole,
          portalPeer: 4,
          oneWayEntry: north,
        ),
      },
    );
    final plan = board.planTrace([3, 4, 0, 1, 2]);
    expect(plan.accepted, isTrue);
    expect(plan.puzzle.evaluate().solved, isTrue);
    expect(plan.puzzle.evaluate().route, [3, 4, 0, 1, 2]);
    expect(board.planTrace([3, 4, 5]).accepted, isFalse);
    final exitRepair = board.rotateAt(0).planTrace([0, 1, 2]);
    expect(
      exitRepair.accepted,
      isTrue,
      reason: 'Lift at the entrance and resume the trace at its paired exit.',
    );
    expect(
      exitRepair.puzzle.outgoingAt(
        0,
        exitRepair.puzzle.tiles[0].entryDirection,
      ),
      east,
    );
    expect(
      board.planTrace([0, 1, 2], entryPort: south).accepted,
      isFalse,
      reason: 'An explicit physical inlet still enters the portal, rather than pretending arrival.',
    );
    verifyReplay(board, plan);
  });

  test(
    'weapon order is checked on a traced launch route, including spent shields',
    () {
      final safe = line(
        overrides: {
          4: const Tile(
            baseMask: north | south,
            kind: TileKind.disarm,
            circuit: 1,
          ),
          5: const Tile(
            baseMask: north | south,
            kind: TileKind.weapon,
            circuit: 1,
          ),
        },
      );
      expect(safe.planTrace([3, 4, 5]).accepted, isTrue);
      final unsafe = line(
        overrides: {
          4: const Tile(
            baseMask: north | south,
            kind: TileKind.weapon,
            circuit: 1,
          ),
          5: const Tile(
            baseMask: north | south,
            kind: TileKind.disarm,
            circuit: 1,
          ),
        },
      );
      expect(unsafe.planTrace([3, 4, 5]).rejection, TraceRejection.armedWeapon);
      final shield = line(
        overrides: {
          3: const Tile(baseMask: north | south, kind: TileKind.shield),
          4: const Tile(
            baseMask: north | south,
            kind: TileKind.weapon,
            circuit: 1,
          ),
          5: const Tile(
            baseMask: north | south,
            kind: TileKind.weapon,
            circuit: 2,
          ),
        },
      );
      expect(shield.planTrace([3, 4]).accepted, isTrue);
      expect(shield.planTrace([3, 4, 5]).rejection, TraceRejection.armedWeapon);
    },
  );

  test('certified campaign routes remain traceable and replayable across all mechanics', () {
    for (var planet = 0; planet < 70; planet++) {
      for (final step in [1, 8, 15]) {
        final board = Puzzle.planet(
          seed: 327 + planet * 139,
          levelNumber: planet * 15 + step,
        );
        final route = board.solvedCopy().evaluate().route;
        final plan = board.planTrace(route);
        expect(
          plan.accepted,
          isTrue,
          reason: 'planet ${planet + 1} route $step: ${plan.message}',
        );
        expect(plan.puzzle.evaluate().solved, isTrue);
        expect(plan.puzzle.evaluate().route, route);
        verifyReplay(board, plan);
      }
    }
  });

  test(
    'preview rejects atomically, cancels cleanly and never persists or awards',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final game = GameController(preferences: preferences);
      await game.load();
      addTearDown(game.dispose);
      final original = game.puzzle;
      final route = original.solvedCopy().evaluate().route;
      expect(game.beginTrace(), isTrue);
      expect(game.updateTrace(route.take(3).toList()), isTrue);
      final preview = game.tracePreview;
      expect(preview, isNotNull);
      expect(identical(game.puzzle, original), isTrue);
      expect(game.moves, 0);
      expect(game.historyLength, 0);
      expect(game.replayActions, isEmpty);
      expect(game.updateTrace([-1, 99]), isFalse);
      expect(identical(game.tracePreview, preview), isTrue);
      expect(game.updateTrace([route.first]), isTrue);
      expect(
        game.tracePreview!.tiles.map((tile) => tile.rotation),
        original.tiles.map((tile) => tile.rotation),
        reason: 'Backtracking to pointer-down removes every pending turn.',
      );
      expect(game.updateTrace(route.take(3).toList()), isTrue);
      await game.flush();
      final saved =
          jsonDecode(preferences.getString(GameController.storageKey)!) as Map;
      expect(
        (saved['round'] as Map)['rotations'],
        original.tiles.map((t) => t.rotation).toList(),
      );
      expect(game.updateTrace(route), isTrue);
      expect(game.tracePreview!.evaluate().solved, isTrue);
      expect(game.status.solved, isFalse);
      expect(game.stars, 0);
      game.cancelTrace();
      expect(game.isTracing, isFalse);
      expect(game.tracePreview, isNull);
      expect(game.endTrace(), isFalse);
      expect(identical(game.puzzle, original), isTrue);
    },
  );

  test('strategic v5 obstacle routes remain legal exact gesture replays', () {
    for (final level in [
      1,
      5,
      15,
      16,
      29,
      31,
      46,
      61,
      91,
      121,
      151,
      181,
      226,
      301,
      751,
    ]) {
      final board = Puzzle.strategicPlanet(
        seed: 2735 + level * 139,
        levelNumber: level,
      );
      final route = board.solvedCopy().evaluate().route;
      final plan = board.planTrace(route);
      expect(plan.accepted, isTrue, reason: 'v5 level $level: ${plan.message}');
      expect(plan.puzzle.evaluate().solved, isTrue);
      expect(plan.puzzle.evaluate().route, route);
      verifyReplay(board, plan);
    }
  });

  test(
    'one drag is one undo and its exact tap replay survives save and reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final game = GameController(preferences: preferences);
      await game.load();
      addTearDown(game.dispose);
      final original = game.puzzle;
      final path = original.solvedCopy().evaluate().route.take(3).toList();
      final plan = original.planTrace(path);
      expect(game.beginTrace(), isTrue);
      expect(game.updateTrace(path), isTrue);
      expect(game.endTrace(), isTrue);
      expect(game.moves, plan.actions.length);
      expect(game.historyLength, 1);
      expect(game.replayActions, plan.actions);
      expect(game.assisted, isFalse);
      await game.flush();
      final restored = GameController(preferences: preferences);
      await restored.load();
      addTearDown(restored.dispose);
      expect(restored.hasVerifiedReplay, isTrue);
      expect(restored.replayActions, plan.actions);
      expect(restored.historyLength, 1);
      expect(restored.undo(), isTrue);
      expect(restored.moves, 0);
      expect(restored.replayActions, isEmpty);
      expect(
        restored.puzzle.tiles.map((t) => t.rotation),
        original.tiles.map((t) => t.rotation),
      );
    },
  );

  test('completion commits only on release; mode changes and ordinary taps cancel previews', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameController(
      preferences: await SharedPreferences.getInstance(),
    );
    await game.load();
    addTearDown(game.dispose);
    final route = game.puzzle.solvedCopy().evaluate().route;
    game.beginTrace();
    game.updateTrace(route.take(3).toList());
    expect(game.rotate(route.first), isTrue);
    expect(game.isTracing, isFalse);
    game.beginTrace();
    game.updateTrace(route.take(3).toList());
    expect(game.setMode(GameMode.daily), isTrue);
    expect(game.isTracing, isFalse);
    game.setMode(GameMode.voyage);
    game.beginTrace();
    expect(game.updateTrace(route), isTrue);
    expect(game.stars, 0);
    expect(game.status.solved, isFalse);
    expect(game.endTrace(), isTrue);
    expect(game.status.solved, isTrue);
    expect(game.stars, 3);
    expect(game.beginTrace(), isFalse);
    expect(game.endTrace(), isFalse);
    expect(game.stars, 3);
  });
}

Puzzle line({Map<int, Tile> overrides = const {}}) => Puzzle.authored(
  size: 3,
  startRow: 1,
  endRow: 1,
  tiles: List.generate(
    9,
    (i) => overrides[i] ?? const Tile(baseMask: north | south),
  ),
  starIndices: {3, 4, 5},
);

Puzzle pathBoard(
  List<int> path, {
  Map<int, Tile> overrides = const {},
  int endRow = 2,
}) {
  int direction(int a, int b) => b ~/ 3 < a ~/ 3
      ? north
      : b ~/ 3 > a ~/ 3
      ? south
      : b < a
      ? west
      : east;
  final tiles = List<Tile>.filled(9, const Tile(baseMask: north | south));
  for (var i = 0; i < path.length; i++) {
    final cell = path[i];
    if (overrides.containsKey(cell)) continue;
    final incoming = i == 0 ? west : direction(cell, path[i - 1]);
    final outgoing = i + 1 == path.length ? east : direction(cell, path[i + 1]);
    tiles[cell] = Tile(baseMask: incoming | outgoing);
  }
  for (final entry in overrides.entries) {
    tiles[entry.key] = entry.value;
  }
  tiles[path.first] = tiles[path.first].withRotation(1);
  return Puzzle.authored(
    size: 3,
    startRow: 1,
    endRow: endRow,
    tiles: tiles,
    starIndices: {path.first, path[path.length ~/ 2], path.last},
  );
}

void verifyReplay(Puzzle original, TracePlan plan) {
  var replay = original;
  for (final action in plan.actions) {
    expect(
      replay.evaluate().solved,
      isFalse,
      reason: 'No tap after completion may enter the verified replay.',
    );
    expect(replay.tiles[action].isLocked, isFalse);
    replay = replay.rotateAt(action);
  }
  expect(
    replay.tiles.map((t) => t.rotation),
    plan.puzzle.tiles.map((t) => t.rotation),
  );
}
