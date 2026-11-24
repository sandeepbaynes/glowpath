import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/game/voyage_progression.dart';

void main() {
  test(
    'opening worlds require route choices and meaningful separated stars',
    () {
      final geometries = <String>{};
      for (var seed = 0; seed < 100; seed++) {
        for (final level in [1, 6, 11, 16, 21, 26]) {
          final board = Puzzle.strategicPlanet(
            seed: seed,
            levelNumber: level,
            difficulty: Difficulty.values[seed % 3],
          );
          _expectStrategicOpening(board);
          final path = board.solvedCopy().evaluate().route;
          expect(
            path.length,
            lessThan(board.tiles.length),
            reason:
                'Off-route relays create alternatives to visiting every cell.',
          );
          expect(
            List.generate(path.length - 1, (i) => path[i + 1] - path[i]),
            contains(-1),
          );
          final stars = board.starIndices.map(path.indexOf).toList()..sort();
          expect(stars[1] - stars[0], greaterThanOrEqualTo(2));
          expect(stars[2] - stars[1], greaterThanOrEqualTo(2));
          geometries.add(path.join(','));
          expect(
            _signature(
              Puzzle.strategicPlanet(
                seed: seed,
                levelNumber: level,
                difficulty: Difficulty.values[seed % 3],
              ),
            ),
            _signature(board),
          );
        }
      }
      expect(geometries.length, greaterThan(100));
    },
  );

  test(
    'certified reserve variants retain the same strategic opening contract',
    () {
      for (final level in [1, 6, 11, 16, 21, 26]) {
        for (final seed in [0, 1, 2, 3, 819, -1]) {
          final board = Puzzle.strategicReserve(seed: seed, levelNumber: level);
          _expectStrategicOpening(board);
          _expectReplay(board);
          expect(board.seed, seed);
          expect(board.levelNumber, level);
        }
      }
    },
  );

  test(
    'actual lane planner confirms stars exclude alternative finish routes',
    () {
      for (final level in [1, 16]) {
        final board = Puzzle.strategicReserve(seed: 0, levelNumber: level);
        final withoutStars = Puzzle.authored(
          size: board.size,
          startRow: board.startRow,
          endRow: board.endRow,
          tiles: board.tiles,
          starIndices: {},
          solutionRotations: board.solutionRotations,
        );
        final withGoals = _actualWinningPaths(board);
        final noGoals = _actualWinningPaths(withoutStars);
        expect(withGoals.length, 1);
        expect(
          noGoals.length,
          greaterThan(1),
          reason: 'The stars must exclude otherwise legal exits, not merely decorate the route.',
        );
      }
    },
  );

  test('all advanced profiles and bounded reserves retain their scheduled mechanics', () {
    for (var planet = 3; planet <= 525; planet++) {
      final level = (planet - 1) * 15 + 1;
      for (final board in [
        Puzzle.strategicPlanet(seed: planet * 7919, levelNumber: level),
        Puzzle.strategicPlanet(
          seed: planet * 7919 + 14,
          levelNumber: level + 14,
        ),
        if (planet <= 16 || planet == 525)
          Puzzle.strategicReserve(seed: planet * 31, levelNumber: level),
      ]) {
        _expectMechanics(board);
        _expectReplay(board);
      }
    }
    for (final level in [7501, 150001]) {
      _expectReplay(Puzzle.strategicPlanet(seed: -1, levelNumber: level));
      _expectMechanics(Puzzle.strategicReserve(seed: 819, levelNumber: level));
    }
  });

  test(
    'v4 generation keeps its original opening size and mechanic introduction',
    () {
      final old = Puzzle.planet(seed: 0, levelNumber: 1);
      expect(old.size, 3);
      expect(old.relayRouteAnalysis!.minimumMoves, inInclusiveRange(12, 16));
      expect(old.relayRouteAnalysis!.routeCount, 1);
      expect(
        Puzzle.planet(
          seed: 0,
          levelNumber: 16,
        ).tiles.where((tile) => tile.couplingGroup > 0),
        isEmpty,
      );
      expect(
        Puzzle.strategicPlanet(
          seed: 0,
          levelNumber: 16,
        ).tiles.where((tile) => tile.couplingGroup == 1),
        hasLength(2),
      );
      expect(PlanetV4Progression.forLevel(1).size, 3);
      expect(VoyageProgression.forLevel(1).size, 4);
      for (var route = 0; route < 15; route++) {
        expect(
          VoyageProgression.forLevel(route + 1).launchSeconds,
          30 - route ~/ 5 * 3,
        );
        expect(VoyageProgression.forLevel(route + 1).size, 4);
      }
    },
  );
}

void _expectStrategicOpening(Puzzle board) {
  expect(board.size, 4);
  final analysis = board.strategicRouteAnalysis!;
  expect(analysis.solutionCount, 1);
  expect(analysis.starlessFinishRoutes, greaterThanOrEqualTo(1));
  expect(analysis.decisionPoints, greaterThanOrEqualTo(2));
  expect(analysis.minimumMoves, greaterThanOrEqualTo(5));
  expect(board.evaluate().solved, isFalse);
  expect(board.starIndices, hasLength(3));
}

void _expectReplay(Puzzle board) {
  expect(board.evaluate().solved, isFalse);
  var replay = board;
  for (final move in board.solutionActions) {
    replay = replay.rotateAt(move);
  }
  expect(
    replay.evaluate().solved,
    isTrue,
    reason:
        'Seed${board.seed}/level${board.levelNumber} must remain legally solvable.',
  );
  expect(board.parMoves, board.solutionActions.length);
}

void _expectMechanics(Puzzle board) {
  final plan = VoyageProgression.forLevel(board.levelNumber);
  int count(TileKind kind) =>
      board.tiles.where((tile) => tile.kind == kind).length;
  expect(
    board.tiles.where((tile) => tile.isLocked),
    hasLength(plan.lockedRelays),
  );
  expect(board.tiles.where((tile) => tile.couplingGroup == 1), hasLength(2));
  expect(
    board.tiles.where((tile) => tile.couplingGroup == 2),
    hasLength(plan.hasTriplets ? 3 : 0),
  );
  for (final (kind, expected) in [
    (TileKind.bridge, plan.hasBridges ? 1 : 0),
    (TileKind.crossway, plan.hasCrossways ? 1 : 0),
    (TileKind.wormhole, plan.hasWormholes ? 2 : 0),
    (TileKind.blackHole, plan.hasBlackHoles ? 1 : 0),
    (TileKind.whiteHole, plan.hasWhiteHoles ? 1 : 0),
    (TileKind.fork, plan.hasGravityForks ? 1 : 0),
    (TileKind.weapon, plan.hasWeapons ? (plan.hasShields ? 2 : 1) : 0),
    (TileKind.shield, plan.hasShields ? 1 : 0),
    (TileKind.disarm, plan.hasWeapons ? 1 : 0),
  ]) {
    expect(count(kind), expected, reason: 'Planet${plan.planetIndex}: $kind');
  }
}

Set<String> _actualWinningPaths(Puzzle board) {
  final wins = <String>{};
  void search(List<int> path) {
    final cell = path.last;
    if (cell == board.endRow * board.size + board.size - 1) {
      final plan = board.planTrace(path);
      if (plan.accepted && plan.puzzle.evaluate().solved) {
        wins.add(path.join(','));
      }
      return;
    }
    for (final next in [
      if (cell % board.size > 0) cell - 1,
      if (cell % board.size < board.size - 1) cell + 1,
      if (cell >= board.size) cell - board.size,
      if (cell < board.size * (board.size - 1)) cell + board.size,
    ]) {
      if (!path.contains(next)) search([...path, next]);
    }
  }

  search([board.startRow * board.size]);
  return wins;
}

String _signature(Puzzle board) =>
    '${board.seed}/${board.startRow}/${board.endRow}/'
    '${board.starIndices.join(',')}/${board.solutionRotations.join(',')}/'
    '${board.tiles.map((tile) => '${tile.baseMask}:${tile.rotation}:${tile.isLocked}:${tile.couplingGroup}:${tile.kind.index}:${tile.oneWayEntry}:${tile.portalPeer}:${tile.gravityPeer}:${tile.gravityTurn}:${tile.circuit}').join('|')}';
