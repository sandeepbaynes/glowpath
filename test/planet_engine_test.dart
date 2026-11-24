import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/launch_clock.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/game/voyage_progression.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'fifteen-route planets keep geometry fixed and tighten in five-route legs',
    () {
      for (final planet in [1, 2, 3, 8, 14, 500, 501, 10000]) {
        final first = (planet - 1) * 15 + 1;
        final baseline = VoyageProgression.forLevel(first);
        for (var route = 0; route < 15; route++) {
          final plan = VoyageProgression.forLevel(first + route);
          expect(plan.planetIndex, planet);
          expect(plan.levelInPlanet, route + 1);
          expect(plan.size, baseline.size);
          expect(plan.lockedRelays, baseline.lockedRelays);
          expect(plan.baseScrambles, baseline.baseScrambles);
          expect(plan.launchSeconds, 30 - (route ~/ 5) * 3);
          for (final pace in Difficulty.values) {
            expect(
              launchBudget(
                difficulty: pace,
                level: first + route,
                progressive: true,
              ).inSeconds,
              inInclusiveRange(18, 30),
            );
          }
        }
      }
    },
  );

  test('over 500 planets replay certified legal moves deterministically', () {
    for (var planet = 1; planet <= 525; planet++) {
      for (final offset in [0, 7, 14]) {
        final level = (planet - 1) * 15 + offset + 1;
        final board = Puzzle.planet(
          seed: planet * 7919 + offset,
          levelNumber: level,
        );
        final repeated = Puzzle.planet(
          seed: planet * 7919 + offset,
          levelNumber: level,
        );
        expect(
          _signature(board),
          _signature(repeated),
          reason: '$planet/$offset',
        );
        expect(board.evaluate().solved, isFalse, reason: '$planet/$offset');
        expect(board.starIndices, hasLength(3));
        var replay = board;
        for (final action in board.solutionActions) {
          replay = replay.rotateAt(action);
        }
        expect(replay.evaluate().solved, isTrue, reason: '$planet/$offset');
        expect(board.parMoves, board.solutionActions.length);
        expect(board.solvedCopy().evaluate().route.toSet(), {
          for (var cell = 0; cell < board.tiles.length; cell++)
            if (board.tiles[cell].isPath) cell,
        });
      }
    }
  });

  test('every opening leg needs the whole board and at least twelve taps', () {
    final geometries = <String>{};
    for (final pace in Difficulty.values) {
      for (var seed = 0; seed < 100; seed++) {
        for (final level in [1, 5, 6, 10, 11, 15]) {
          final board = Puzzle.planet(
            seed: seed,
            levelNumber: level,
            difficulty: pace,
          );
          final analysis = board.relayRouteAnalysis!;
          expect(analysis.minimumMoves, inInclusiveRange(12, 16));
          expect(analysis.minimumCells, 9);
          expect(analysis.routeCount, 1);
          expect(board.parMoves, analysis.minimumMoves);
          expect(board.solvedCopy().evaluate().route, hasLength(9));
          final reference = board.solvedCopy();
          expect([
            for (var cell = 0; cell < board.tiles.length; cell++)
              if (!board.tiles[cell].orientationMatches(reference.tiles[cell]))
                cell,
          ], hasLength(8));
          geometries.add(reference.evaluate().route.join(','));
        }
      }
    }
    expect(geometries, hasLength(6));
  });

  test('exact opening analysis agrees with exhaustive orientation search', () {
    // This oracle enumerates all 32,768 distinct board orientations and calls
    // the actual traversal evaluator. It does not use reference rotations,
    // target moves, or the path-enumeration algorithm being checked.
    for (final seed in [0, 71, 819]) {
      final board = Puzzle.planet(seed: seed, levelNumber: 1);
      final bruteForce = _exhaustiveRelayOrientations(board);
      expect(board.relayRouteAnalysis!.minimumMoves, bruteForce.minimumMoves);
      expect(board.relayRouteAnalysis!.minimumCells, bruteForce.minimumCells);
      expect(board.relayRouteAnalysis!.routeCount, bruteForce.routeCount);
    }
  });

  test('exact relay analysis finds shortcuts and rejects unsupported mechanics', () {
    final board = Puzzle.authored(
      size: 3,
      startRow: 1,
      endRow: 1,
      tiles: List.generate(9, (_) => const Tile(baseMask: north | south)),
      starIndices: {3, 4, 5},
      // Deliberately irrelevant reference: the analyzer must find its own path.
      solutionRotations: List.filled(9, 0),
    );
    expect(board.relayRouteAnalysis!.minimumMoves, 3);
    expect(board.relayRouteAnalysis!.minimumCells, 3);
    expect(board.relayRouteAnalysis!.routeCount, 1);
    final unsolvable = board.copyWithTiles([
      ...board.tiles.take(4),
      const Tile(baseMask: north | south, isLocked: true),
      ...board.tiles.skip(5),
    ]);
    expect(unsolvable.relayRouteAnalysis!.minimumMoves, isNull);
    expect(unsolvable.relayRouteAnalysis!.routeCount, 0);
    expect(Puzzle.planet(seed: 31, levelNumber: 31).relayRouteAnalysis, isNull);
  });

  test('all mechanic families appear on their introduction planets', () {
    final introduced = {
      TileKind.bridge: 5,
      TileKind.crossway: 6,
      TileKind.wormhole: 7,
      TileKind.blackHole: 8,
      TileKind.whiteHole: 9,
      TileKind.fork: 11,
      TileKind.weapon: 12,
      TileKind.disarm: 12,
      TileKind.shield: 13,
    };
    for (final entry in introduced.entries) {
      for (var seed = 0; seed < 30; seed++) {
        final board = Puzzle.planet(
          seed: seed,
          levelNumber: (entry.value - 1) * 15 + 1,
        );
        expect(
          board.tiles.any((t) => t.kind == entry.key && t.isPath),
          isTrue,
          reason: '${entry.key}/$seed',
        );
      }
    }
  });

  test('bridge revisits use independent lanes, not a false loop or fork', () {
    final board = _crossing(bridge: true);
    final status = board.evaluate();
    expect(status.solved, isTrue);
    expect(status.route, [3, 4, 5, 2, 1, 4, 7, 8]);
    expect(status.litPorts[4], 15);
    final tiles = board.tiles.toList()
      ..[4] = const Tile(
        baseMask: 15,
        kind: TileKind.bridge,
        oneWayEntry: west,
      );
    expect(
      board.copyWithTiles(tiles).evaluate().failure,
      PuzzleFailure.wrongWay,
    );
  });

  test(
    'crossways preserve two adjacent bend pairs and respect gravity offset',
    () {
      final board = _crossing(bridge: false);
      expect(board.evaluate().route, [3, 4, 1, 2, 5, 4, 7, 8]);
      expect(board.evaluate().solved, isTrue);
      final tiles = board.tiles.toList()
        ..[4] = const Tile(
          baseMask: 15,
          kind: TileKind.crossway,
          gravityPeer: 0,
          gravityTurn: 1,
        );
      expect(board.copyWithTiles(tiles).evaluate().solved, isTrue);
      expect(board.rotateAt(4).evaluate().solved, isFalse);
    },
  );

  test('black and white holes select opposite visible fork priorities', () {
    final tiles = List.generate(9, (_) => const Tile(baseMask: north | south));
    tiles[3] = const Tile(baseMask: west | east);
    tiles[4] = const Tile(
      baseMask: west | east | south,
      kind: TileKind.blackHole,
    );
    tiles[7] = const Tile(baseMask: north | east);
    tiles[8] = const Tile(baseMask: west | east);
    final board = Puzzle.authored(
      size: 3,
      startRow: 1,
      endRow: 2,
      tiles: tiles,
      starIndices: {3, 4, 7},
    );
    expect(board.evaluate().solved, isTrue);
    expect(board.outgoingAt(4, west), south);
    tiles[4] = tiles[4].copyWith(kind: TileKind.whiteHole);
    final pushed = board.copyWithTiles(tiles);
    expect(pushed.outgoingAt(4, west), east);
    expect(pushed.evaluate().solved, isFalse);
  });

  test('rotating a gravity well also changes its remote crossing', () {
    final board = _crossing(bridge: false);
    final tiles = board.tiles.toList();
    tiles[0] = const Tile(
      baseMask: north | east | south,
      kind: TileKind.blackHole,
    );
    tiles[4] = const Tile(
      baseMask: 15,
      kind: TileKind.crossway,
      gravityPeer: 0,
      gravityTurn: 1,
    );
    final dependent = board.copyWithTiles(tiles);
    expect(dependent.evaluate().solved, isTrue);
    final changed = dependent.rotateAt(0);
    expect(changed.tiles[4].rotation, dependent.tiles[4].rotation);
    expect(
      changed.visualTileAt(4).routeRotation,
      (dependent.visualTileAt(4).routeRotation + 1) % 4,
    );
    expect(changed.evaluate().solved, isFalse);
  });

  test('neighboring gravity chooses fork toward black and away from white', () {
    final tiles = List.generate(9, (_) => const Tile(baseMask: north | south));
    tiles[7] = const Tile(
      baseMask: north | east | west,
      kind: TileKind.blackHole,
    );
    tiles[4] = const Tile(
      baseMask: west | east | south,
      kind: TileKind.fork,
      gravityPeer: 7,
    );
    final board = Puzzle.authored(
      size: 3,
      startRow: 1,
      endRow: 1,
      tiles: tiles,
      starIndices: {},
    );
    expect(board.outgoingAt(4, west), south);
    tiles[7] = tiles[7].copyWith(kind: TileKind.whiteHole);
    expect(board.copyWithTiles(tiles).outgoingAt(4, west), east);
  });

  test(
    'wormholes make a genuine non-adjacent jump and reject missing pairs',
    () {
      final board = Puzzle.planet(seed: 31, levelNumber: 91).solvedCopy();
      final route = board.evaluate().route;
      final portal = route.firstWhere(
        (i) => board.tiles[i].kind == TileKind.wormhole,
      );
      final position = route.indexOf(portal);
      final peer = board.tiles[portal].portalPeer!;
      expect(route[position + 1], peer);
      expect(
        (portal ~/ board.size - peer ~/ board.size).abs() +
            (portal % board.size - peer % board.size).abs(),
        greaterThan(1),
      );
      final tiles = board.tiles.toList()
        ..[peer] = const Tile(baseMask: north | south);
      expect(
        board.copyWithTiles(tiles).evaluate().failure,
        PuzzleFailure.unpairedWormhole,
      );
    },
  );

  test('weapon must be disabled or protected before flight passes it', () {
    final tiles = List.generate(9, (_) => const Tile(baseMask: west | east));
    tiles[3] = const Tile(
      baseMask: west | east,
      kind: TileKind.disarm,
      circuit: 1,
    );
    tiles[5] = const Tile(
      baseMask: west | east,
      kind: TileKind.weapon,
      circuit: 1,
    );
    final board = Puzzle.authored(
      size: 3,
      startRow: 1,
      endRow: 1,
      tiles: tiles,
      starIndices: {3, 4, 5},
    );
    expect(board.evaluate().solved, isTrue);
    tiles[3] = const Tile(baseMask: west | east);
    expect(
      board.copyWithTiles(tiles).evaluate().failure,
      PuzzleFailure.weaponHit,
    );
    tiles[3] = const Tile(baseMask: west | east, kind: TileKind.shield);
    expect(board.copyWithTiles(tiles).evaluate().solved, isTrue);
    tiles[4] = const Tile(
      baseMask: west | east,
      kind: TileKind.weapon,
      circuit: 2,
    );
    expect(
      board.copyWithTiles(tiles).evaluate().failure,
      PuzzleFailure.weaponHit,
    );
  });

  test(
    'twins and triplets rotate together and four taps restore the board',
    () {
      final board = Puzzle.planet(seed: 819, levelNumber: 136);
      for (final group in [1, 2]) {
        final members = [
          for (var i = 0; i < board.tiles.length; i++)
            if (board.tiles[i].couplingGroup == group) i,
        ];
        expect(members, hasLength(group == 1 ? 2 : 3));
        final turned = board.rotateAt(members.last);
        for (var i = 0; i < board.tiles.length; i++) {
          expect(
            turned.tiles[i].rotation,
            (board.tiles[i].rotation + (members.contains(i) ? 1 : 0)) % 4,
          );
        }
        var restored = turned;
        for (var i = 0; i < 3; i++) {
          restored = restored.rotateAt(members.first);
        }
        expect(_signature(restored), _signature(board));
      }
    },
  );

  for (final level in [196, 197]) {
    test('linked hints and undo survive saved route $level', () async {
      SharedPreferences.setMockInitialValues({'journeyLevel': level});
      final prefs = await SharedPreferences.getInstance();
      final game = GameController(preferences: prefs);
      await game.load();
      expect(game.isPlanetRound, isTrue);
      // Salvage uses one linked set, while ordinary advanced routes retain
      // separate twin and triplet sets. Verify the mechanic on both layouts.
      expect(game.puzzle.isBountyRoute, level == 196);
      final groupId = game.puzzle.isBountyRoute ? 1 : 2;
      final members = [
        for (var i = 0; i < game.puzzle.tiles.length; i++)
          if (game.puzzle.tiles[i].couplingGroup == groupId) i,
      ];
      expect(members.length, greaterThanOrEqualTo(2));
      if (!game.puzzle.isBountyRoute) expect(members, hasLength(3));
      final group = members.last;
      final rotations = game.puzzle.tiles.map((t) => t.rotation).toList();
      final before = _signature(game.puzzle);
      game.rotate(group);
      expect(game.replayActions, [group]);
      for (var i = 0; i < game.puzzle.tiles.length; i++) {
        expect(
          game.puzzle.tiles[i].rotation,
          (rotations[i] + (members.contains(i) ? 1 : 0)) % 4,
        );
      }
      expect(game.undo(), isTrue);
      expect(_signature(game.puzzle), before);
      game.rotate(group);
      final after = _signature(game.puzzle);
      await game.flush();
      final loaded = GameController(preferences: prefs);
      await loaded.load();
      expect(loaded.hasVerifiedReplay, isTrue);
      expect(loaded.replayActions, [group]);
      expect(_signature(loaded.puzzle), after);
      expect(loaded.undo(), isTrue);
      expect(_signature(loaded.puzzle), before);
      loaded.rotate(group);
      var count = 0;
      while (!loaded.status.solved && count++ < 50) {
        expect(loaded.hint(), isTrue);
      }
      expect(loaded.status.solved, isTrue);
      expect(loaded.assisted, isTrue);
      game.dispose();
      loaded.dispose();
    });
  }

  test('skips advance without rewards and onboarding persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final game = GameController(preferences: prefs);
    await game.load();
    expect(game.onboardingSeen, isFalse);
    game.markOnboardingSeen();
    for (var i = 0; i < 5; i++) {
      expect(game.skipCurrentLevel(), isTrue);
    }
    expect(game.journeyLevel, 6);
    expect(game.stars, 0);
    expect(game.best, 0);
    expect(game.earnedAchievementIds, isEmpty);
    expect(game.voyageClears, 0);
    while (!game.status.solved) {
      game.hint();
    }
    expect(game.voyageClears, 1);
    expect(game.earnedAchievementIds, contains('first_signal'));
    expect(game.earnedAchievementIds, isNot(contains('navigator_5')));
    await game.flush();
    final loaded = GameController(preferences: prefs);
    await loaded.load();
    expect(loaded.onboardingSeen, isTrue);
    expect(loaded.skippedVoyage, 5);
    loaded.setDaily(true);
    expect(loaded.skipCurrentLevel(), isFalse);
    game.dispose();
    loaded.dispose();
  });

  test(
    'old voyage-v3 saved board restores exactly until its next route',
    () async {
      final board = Puzzle.voyage(seed: 731 + 20 * 97 + 1907, levelNumber: 20);
      SharedPreferences.setMockInitialValues({
        GameController.storageKey: jsonEncode({
          'schemaVersion': 1,
          'generatorVersion': puzzleGeneratorVersion,
          'journeyLevel': 20,
          'difficulty': 'balanced',
          'mode': 'voyage',
          'stars': 57,
          'round': {
            'layout': 'voyage-v3',
            'difficulty': 'balanced',
            'seed': board.seed,
            'level': 20,
            'rotations': board.tiles.map((t) => t.rotation).toList(),
            'moves': 0,
            'assisted': false,
            'recorded': false,
            'history': [],
          },
        }),
      });
      final game = GameController(
        preferences: await SharedPreferences.getInstance(),
      );
      await game.load();
      expect(_signature(game.puzzle), _signature(board));
      expect(game.isPlanetRound, isFalse);
      while (!game.status.solved) {
        game.hint();
      }
      game.nextPuzzle();
      expect(game.isPlanetRound, isTrue);
      expect(game.puzzle.levelNumber, 21);
      game.dispose();
    },
  );
}

RelayRouteAnalysis _exhaustiveRelayOrientations(Puzzle board) {
  final tiles = board.tiles.toList();
  int? minimumMoves, minimumCells;
  var solutions = 0;
  void enumerate(int cell, int moves) {
    if (cell == tiles.length) {
      final status = board.copyWithTiles(tiles).evaluate();
      if (!status.solved) return;
      solutions++;
      if (minimumMoves == null || moves < minimumMoves!) minimumMoves = moves;
      if (minimumCells == null || status.route.length < minimumCells!) {
        minimumCells = status.route.length;
      }
      return;
    }
    final original = board.tiles[cell];
    final orientations =
        original.connections == (north | south) ||
            original.connections == (east | west)
        ? 2
        : 4;
    for (var turns = 0; turns < orientations; turns++) {
      tiles[cell] = original.withRotation(original.rotation + turns);
      enumerate(cell + 1, moves + turns);
    }
  }

  enumerate(0, 0);
  return RelayRouteAnalysis(
    minimumMoves: minimumMoves,
    minimumCells: minimumCells,
    routeCount: solutions,
  );
}

Puzzle _crossing({required bool bridge}) {
  final tiles = List.generate(9, (_) => const Tile(baseMask: north | south));
  tiles[3] = const Tile(baseMask: west | east);
  tiles[4] = Tile(
    baseMask: 15,
    kind: bridge ? TileKind.bridge : TileKind.crossway,
    rotation: bridge ? 0 : 1,
  );
  tiles[5] = const Tile(baseMask: west | north);
  tiles[2] = const Tile(baseMask: south | west);
  tiles[1] = const Tile(baseMask: east | south);
  tiles[7] = const Tile(baseMask: north | east);
  tiles[8] = const Tile(baseMask: west | east);
  return Puzzle.authored(
    size: 3,
    startRow: 1,
    endRow: 2,
    tiles: tiles,
    starIndices: {1, 5, 7},
  );
}

String _signature(Puzzle b) =>
    '${b.startRow}/${b.endRow}/${b.starIndices}/${b.tiles.map((t) => '${t.kind.name},${t.baseMask},${t.rotation},${t.oneWayEntry},${t.isLocked},${t.couplingGroup},${t.portalPeer},${t.gravityPeer},${t.gravityTurn},${t.circuit}').join(';')}';
