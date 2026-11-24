part of 'puzzle.dart';

Puzzle? _createStrategicCandidate({
  required int seed,
  required int levelNumber,
  required Difficulty difficulty,
  required int attempt,
}) {
  if (levelNumber < 1) throw ArgumentError.value(levelNumber, 'levelNumber');
  final plan = VoyageProgression.forLevel(levelNumber);
  final size = plan.size;
  final random = _SeededRandom(
    seed ^ 0x53545235 ^ (attempt * 7919),
    levelNumber,
    difficulty,
  );
  var startRow = random.nextInt(size);
  final minLength = math.min(
    size * size - size ~/ 2,
    plan.minimumRouteLength + (plan.planetIndex >= 7 ? 3 : 0),
  );
  final rawPath = _strategicPath(random, size, minLength);
  startRow = rawPath.first ~/ size;
  var row = rawPath.last ~/ size;
  final path = rawPath.toList();
  int? portalA, portalB;
  if (plan.hasWormholes) {
    // A genuine non-adjacent shortcut. Its skipped cells become distractors.
    const a = 3;
    final b = a + 4;
    portalA = path[a];
    portalB = path[b];
    path.removeRange(a + 1, b);
  }
  final tiles = List<Tile>.generate(
    size * size,
    (_) => Tile(
      baseMask: random.nextInt(3) == 0 ? north | south : north | east,
      rotation: random.nextInt(4),
    ),
  );
  final incoming = <int, int>{}, outgoing = <int, int>{};
  for (var p = 0; p < path.length; p++) {
    final cell = path[p];
    final inPort = p == 0
        ? west
        : cell == portalB
        ? _opposite(_directionBetween(cell, path[p + 1], size))
        : _directionBetween(cell, path[p - 1], size);
    final outPort = p == path.length - 1
        ? east
        : cell == portalA
        ? _opposite(inPort)
        : _directionBetween(cell, path[p + 1], size);
    incoming[cell] = inPort;
    outgoing[cell] = outPort;
    final mask = inPort | outPort;
    tiles[cell] = Tile(
      baseMask: mask,
      isPath: true,
      kind: cell == portalA || cell == portalB
          ? TileKind.wormhole
          : TileKind.relay,
      oneWayEntry: cell == portalA || cell == portalB ? inPort : 0,
      portalPeer: cell == portalA
          ? portalB
          : cell == portalB
          ? portalA
          : null,
    );
  }
  final reserved = <int>{path.first, path.last, ?portalA, ?portalB};
  final interior = path.sublist(1, path.length - 1)
    ..removeWhere(reserved.contains);
  random.shuffle(interior);
  int? take(bool Function(int) eligible) {
    for (final cell in interior) {
      if (!reserved.contains(cell) && eligible(cell)) {
        reserved.add(cell);
        return cell;
      }
    }
    return null;
  }

  // Defense order is part of the route, never an unseen random roll.
  if (plan.hasWeapons) {
    final candidates = path
        .skip(1)
        .take(path.length - 2)
        .where((c) => !reserved.contains(c))
        .toList();
    final control = candidates[0], weapon = candidates[candidates.length - 2];
    reserved.addAll([control, weapon]);
    tiles[control] = tiles[control].copyWith(
      kind: plan.hasShields && plan.planetIndex.isOdd
          ? TileKind.shield
          : TileKind.disarm,
      circuit: 1,
    );
    tiles[weapon] = tiles[weapon].copyWith(kind: TileKind.weapon, circuit: 1);
    if (plan.hasShields) {
      final extra = candidates.firstWhere((c) => !reserved.contains(c));
      reserved.add(extra);
      tiles[extra] = tiles[extra].copyWith(
        kind: tiles[control].kind == TileKind.shield
            ? TileKind.disarm
            : TileKind.shield,
        circuit: 2,
      );
      final secondWeapon = candidates.last;
      reserved.add(secondWeapon);
      tiles[secondWeapon] = tiles[secondWeapon].copyWith(
        kind: TileKind.weapon,
        circuit: 2,
      );
    }
  }
  for (var i = 0; i < plan.lockedRelays; i++) {
    final cell = take((_) => true);
    if (cell != null) tiles[cell] = tiles[cell].copyWith(isLocked: true);
  }
  if (plan.hasBridges) {
    final cell = take((c) => outgoing[c] == _opposite(incoming[c]!));
    if (cell != null) {
      tiles[cell] = tiles[cell].copyWith(
        kind: TileKind.bridge,
        baseMask: 15,
        oneWayEntry: plan.planetIndex >= 14 ? incoming[cell] : 0,
      );
    }
  }
  if (plan.hasCrossways) {
    final cell = take((c) => outgoing[c] != _opposite(incoming[c]!));
    if (cell != null) {
      var rotation = 0;
      while (_crossExit(incoming[cell]!, rotation) != outgoing[cell]) {
        rotation++;
      }
      tiles[cell] = tiles[cell].copyWith(
        kind: TileKind.crossway,
        baseMask: 15,
        rotation: rotation,
        oneWayEntry: plan.planetIndex >= 14
            ? _rotateMask(incoming[cell]!, -rotation)
            : 0,
      );
    }
  }
  int? black, white;
  for (final kind in [
    if (plan.hasBlackHoles) TileKind.blackHole,
    if (plan.hasWhiteHoles) TileKind.whiteHole,
  ]) {
    final cell = take(
      (c) => _forkMask(incoming[c]!, outgoing[c]!, kind) != null,
    );
    if (cell != null) {
      tiles[cell] = tiles[cell].copyWith(
        kind: kind,
        baseMask: _forkMask(incoming[cell]!, outgoing[cell]!, kind),
      );
      if (kind == TileKind.blackHole) {
        black = cell;
      } else {
        white = cell;
      }
    }
  }
  if (plan.hasGravityForks) {
    final sources = [?black, ?white];
    var placed = false;
    for (final source in sources) {
      if (placed) break;
      final pull = tiles[source].kind == TileKind.blackHole;
      final cell = take(
        (c) =>
            _gravityForkMask(
              c,
              incoming[c]!,
              outgoing[c]!,
              source,
              pull,
              size,
            ) !=
            null,
      );
      if (cell != null) {
        tiles[cell] = tiles[cell].copyWith(
          kind: TileKind.fork,
          baseMask: _gravityForkMask(
            cell,
            incoming[cell]!,
            outgoing[cell]!,
            source,
            pull,
            size,
          ),
          gravityPeer: source,
        );
        placed = true;
      }
    }
  }
  if (plan.hasGravityLanes && (black != null || white != null)) {
    final source = (plan.planetIndex.isEven ? black : white) ?? black ?? white!;
    for (var cell = 0; cell < tiles.length; cell++) {
      final tile = tiles[cell];
      if (tile.kind != TileKind.bridge && tile.kind != TileKind.crossway) {
        continue;
      }
      final turn = _gravityQuarter(
        cell,
        source,
        tiles[source].kind == TileKind.blackHole,
        size,
      );
      tiles[cell] = tile.copyWith(
        gravityPeer: source,
        gravityTurn: turn,
        rotation: tile.rotation - turn,
      );
    }
  }
  for (var i = 0; i < plan.oneWayRelays; i++) {
    final cell = take((_) => true);
    if (cell != null) {
      tiles[cell] = tiles[cell].copyWith(oneWayEntry: incoming[cell]);
    }
  }
  // Linked cells are deliberately separated along the route. A late tap can
  // disturb an earlier segment, but every legal scramble has an inverse.
  final linkable = path
      .where((c) => !tiles[c].isLocked && tiles[c].kind != TileKind.wormhole)
      .toList();
  if (plan.hasTwins && linkable.length >= 2) {
    for (final cell in [linkable[1], linkable[linkable.length - 2]]) {
      tiles[cell] = tiles[cell].copyWith(couplingGroup: 1);
    }
  }
  if (plan.hasTriplets) {
    final candidates = linkable
        .where((c) => tiles[c].couplingGroup == 0)
        .toList();
    for (final cell in [
      candidates[0],
      candidates[candidates.length ~/ 2],
      candidates.last,
    ]) {
      tiles[cell] = tiles[cell].copyWith(couplingGroup: 2);
    }
  }
  final reference = tiles.map((t) => t.rotation).toList();
  final stars = <int>{
    path[path.length ~/ 4],
    path[path.length ~/ 2],
    path[path.length * 3 ~/ 4],
  };
  final representatives = <int>[];
  final groups = <int>{};
  for (final cell in path) {
    final tile = tiles[cell];
    if (tile.isLocked || tile.kind == TileKind.bridge && !tile.isOneWay) {
      continue;
    }
    if (tile.couplingGroup != 0 && !groups.add(tile.couplingGroup)) continue;
    representatives.add(cell);
  }
  random.shuffle(representatives);
  final toScramble = representatives
      .take(math.min(representatives.length, plan.baseScrambles))
      .toList();
  for (final cell in toScramble) {
    final group = tiles[cell].couplingGroup;
    final selected = tiles[cell];
    final halfTurnSymmetric =
        !selected.isOneWay &&
        (selected.kind == TileKind.crossway ||
            selected.connections == (north | south) ||
            selected.connections == (east | west));
    final turns = halfTurnSymmetric
        ? 1 + 2 * random.nextInt(2)
        : 1 + random.nextInt(3);
    for (var i = 0; i < tiles.length; i++) {
      if (i == cell || group != 0 && tiles[i].couplingGroup == group) {
        tiles[i] = tiles[i].withRotation(tiles[i].rotation - turns);
      }
    }
  }
  Puzzle build(int par) => Puzzle._(
    size: size,
    seed: seed,
    levelNumber: levelNumber,
    startRow: startRow,
    endRow: row,
    tiles: tiles,
    starIndices: stars,
    solutionRotations: reference,
    parMoves: par,
    label: plan.stageName,
  );
  var result = build(0);
  if (result.evaluate().solved) {
    final cell = representatives.first;
    result = result.rotateAt(cell);
    for (var i = 0; i < tiles.length; i++) {
      tiles[i] = result.tiles[i];
    }
  }
  result = build(result.solutionActions.length);
  if (!result.solvedCopy().evaluate().solved) {
    return null;
  }
  return result;
}

List<int> _strategicPath(_SeededRandom random, int size, int minimum) {
  for (var attempt = 0; attempt < 12; attempt++) {
    final length = math.min(size * size - 2, minimum + random.nextInt(3));
    final path = <int>[random.nextInt(size) * size];
    final seen = <int>{path.first};
    var visits = 0;
    bool search(bool westward) {
      if (++visits > 6000) return false;
      final cell = path.last;
      if (path.length == length) return cell % size == size - 1 && westward;
      if (size - 1 - cell % size > length - path.length) return false;
      final next = <int>[
        if (cell % size > 0) cell - 1,
        if (cell % size < size - 1) cell + 1,
        if (cell >= size) cell - size,
        if (cell < size * (size - 1)) cell + size,
      ]..removeWhere(seen.contains);
      random.shuffle(next);
      for (final target in next) {
        path.add(target);
        seen.add(target);
        if (search(westward || target == cell - 1)) return true;
        path.removeLast();
        seen.remove(target);
      }
      return false;
    }

    if (search(false)) return path;
  }
  // A legal fixed winding blueprint bounds even adversarial path searches.
  // Early worlds still pass the strategy filter or use a certified reserve.
  return size == 4
      ? [4, 5, 1, 2, 3, 7, 6, 10, 9, 8, 12, 13, 14, 15]
      : [
          10,
          11,
          6,
          5,
          0,
          1,
          2,
          7,
          12,
          17,
          16,
          15,
          20,
          21,
          22,
          23,
          18,
          13,
          8,
          3,
          4,
          9,
          14,
          19,
          24,
        ];
}

/// Decision-based quality measurements for the first two strategic planets.
/// Every finish route is enumerated with locks, arrow direction and shared
/// quarter-turn constraints; the supplied reference path does not define a win.
class StrategicRouteAnalysis {
  const StrategicRouteAnalysis({
    required this.solutionCount,
    required this.starlessFinishRoutes,
    required this.decisionPoints,
    required this.minimumMoves,
    required this.routeCount,
  });
  final int solutionCount, starlessFinishRoutes, decisionPoints, routeCount;
  final int? minimumMoves;
}

class _StrategyRoutes {
  final routes = <String, ({List<int> cells, int moves})>{};
  final decisions = <int>{};
  bool capped = false;
}

_StrategyRoutes _strategyRoutes(Puzzle board) {
  final result = _StrategyRoutes();
  final reference = board.solvedCopy().evaluate().route;
  var nodes = 0;
  List<int> options(int cell, int inlet, int outlet, Map<int, int> groups) {
    final tile = board.tiles[cell];
    final forced = tile.couplingGroup == 0 ? null : groups[tile.couplingGroup];
    final values = <int>[];
    for (var delta = 0; delta < (tile.isLocked ? 1 : 4); delta++) {
      if (forced != null && forced != delta) continue;
      final turned = tile.withRotation(tile.rotation + delta);
      if (turned.connections == (inlet | outlet) &&
          (!turned.isOneWay || turned.entryDirection == inlet)) {
        values.add(delta);
        if (tile.couplingGroup == 0) break;
      }
    }
    return values;
  }

  void visit(
    int cell,
    int inlet,
    List<int> prefix,
    Map<int, int> groups,
    int moves,
  ) {
    if (++nodes > 12000) {
      result.capped = true;
      return;
    }
    final path = [...prefix, cell];
    var hasLane = false;
    for (final outlet in [north, east, south, west]) {
      if (outlet == inlet) continue;
      final finish =
          cell == board.endRow * board.size + board.size - 1 && outlet == east;
      final next = _adjacentCell(cell, outlet, board.size);
      if (!finish && (next == null || path.contains(next))) continue;
      for (final delta in options(cell, inlet, outlet, groups)) {
        hasLane = true;
        final group = board.tiles[cell].couplingGroup;
        final cost =
            moves + (group == 0 || !groups.containsKey(group) ? delta : 0);
        final following = group == 0 ? groups : {...groups, group: delta};
        if (finish) {
          final key = path.join(',');
          final existing = result.routes[key];
          if (existing == null || cost < existing.moves) {
            result.routes[key] = (cells: path, moves: cost);
          }
        } else {
          visit(next!, _opposite(outlet), path, following, cost);
        }
      }
    }
    if (hasLane) {
      var divergent = 0;
      while (divergent < path.length &&
          divergent < reference.length &&
          path[divergent] == reference[divergent]) {
        divergent++;
      }
      if (divergent > 0 &&
          divergent < reference.length &&
          path.length >= divergent + 2) {
        result.decisions.add(divergent - 1);
      }
    }
  }

  visit(board.startRow * board.size, west, [], {}, 0);
  return result;
}

Puzzle _strategyStars(Puzzle board, Set<int> stars) => Puzzle._(
  size: board.size,
  seed: board.seed,
  levelNumber: board.levelNumber,
  startRow: board.startRow,
  endRow: board.endRow,
  tiles: board.tiles,
  starIndices: stars,
  solutionRotations: board.solutionRotations,
  parMoves: board.parMoves,
  label: board.label,
);

Puzzle _strategicPlanet(int seed, int levelNumber, Difficulty difficulty) {
  final plan = VoyageProgression.forLevel(levelNumber);
  if (plan.size > 4) {
    for (var attempt = 0; attempt < 24; attempt++) {
      final candidate = _createStrategicCandidate(
        seed: seed,
        levelNumber: levelNumber,
        difficulty: difficulty,
        attempt: attempt,
      );
      if (candidate != null && _hasStrategyMechanics(candidate)) {
        return candidate;
      }
    }
    return _advancedStrategicReserve(seed, levelNumber);
  }
  for (var attempt = 0; attempt < 96; attempt++) {
    final candidate = _createStrategicCandidate(
      seed: seed,
      levelNumber: levelNumber,
      difficulty: difficulty,
      attempt: attempt,
    );
    if (candidate == null) continue;
    final routes = _strategyRoutes(candidate);
    if (routes.capped ||
        routes.routes.length < 2 ||
        routes.decisions.length < 2) {
      continue;
    }
    final reference = candidate.solvedCopy().evaluate().route;
    final interior = reference.sublist(1, reference.length - 1);
    final placements = <({Set<int> stars, double spread, int order})>[];
    for (var a = 0; a < interior.length - 4; a++) {
      for (var b = a + 2; b < interior.length - 2; b++) {
        for (var c = b + 2; c < interior.length; c++) {
          placements.add((
            stars: {interior[a], interior[b], interior[c]},
            order: a * 256 + b * 16 + c,
            spread:
                (a + 1 - reference.length / 4).abs() +
                (b + 1 - reference.length / 2).abs() +
                (c + 1 - reference.length * 3 / 4).abs(),
          ));
        }
      }
    }
    placements.sort((a, b) {
      final spread = a.spread.compareTo(b.spread);
      return spread == 0 ? a.order.compareTo(b.order) : spread;
    });
    for (final placement in placements) {
      final winners = routes.routes.values
          .where((route) => placement.stars.every(route.cells.contains))
          .toList();
      if (winners.length == 1 && winners.first.moves >= 5) {
        return _strategyStars(candidate, placement.stars);
      }
    }
  }
  return _strategicReserve(seed, levelNumber);
}

StrategicRouteAnalysis? _analyzeStrategicRoutes(Puzzle board) {
  if (board.size != 4 ||
      board.tiles.any(
        (tile) => tile.kind != TileKind.relay || tile.gravityPeer != null,
      )) {
    return null;
  }
  final routes = _strategyRoutes(board);
  if (routes.capped) return null;
  final winners = routes.routes.values
      .where((route) => board.starIndices.every(route.cells.contains))
      .toList();
  return StrategicRouteAnalysis(
    solutionCount: winners.length,
    starlessFinishRoutes: routes.routes.length - winners.length,
    decisionPoints: routes.decisions.length,
    minimumMoves: winners.isEmpty
        ? null
        : winners.map((route) => route.moves).reduce(math.min),
    routeCount: routes.routes.length,
  );
}

/// Fixed reserves meet the same two-decision, unique-goal and star-choice
/// requirements as generated openings. Seed reflections change presentation
/// without weakening certification. They bound latency instead of throwing or
/// silently accepting an easier candidate when a search budget is exhausted.
Puzzle _strategicReserve(int seed, int levelNumber) {
  final twin = VoyageProgression.forLevel(levelNumber).hasTwins;
  final records = twin
      ? const [
          (6, 3, false, 0),
          (10, 0, false, 0),
          (12, 0, true, 0),
          (5, 0, false, 0),
          (3, 3, false, 0),
          (12, 3, false, 0),
          (5, 0, false, 0),
          (3, 0, false, 0),
          (6, 1, false, 1),
          (9, 1, false, 0),
          (5, 3, false, 0),
          (6, 0, false, 0),
          (9, 0, false, 0),
          (3, 3, false, 0),
          (3, 1, false, 0),
          (9, 1, false, 1),
        ]
      : const [
          (3, 0, false, 0),
          (5, 2, false, 0),
          (6, 1, false, 0),
          (12, 1, false, 0),
          (12, 2, false, 0),
          (6, 1, false, 0),
          (9, 0, false, 0),
          (5, 3, false, 0),
          (3, 0, false, 0),
          (9, 0, false, 0),
          (6, 0, false, 0),
          (9, 3, false, 0),
          (3, 2, false, 0),
          (5, 0, false, 0),
          (3, 2, false, 0),
          (10, 3, false, 0),
        ];
  final reference = twin
      ? [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0]
      : [0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0];
  var start = twin ? 3 : 1, end = twin ? 2 : 3;
  final vertical = seed & 1 != 0;
  int position(int cell) =>
      (vertical ? 3 - cell ~/ 4 : cell ~/ 4) * 4 + cell % 4;
  int mirrorMask(int mask) => vertical
      ? (mask & (east | west)) | ((mask & north) << 2) | ((mask & south) >> 2)
      : mask;
  if (vertical) {
    start = 3 - start;
    end = 3 - end;
  }
  final sign = vertical ? -1 : 1;
  final tiles = List<Tile>.filled(16, const Tile(baseMask: north | south));
  final goal = List<int>.filled(16, 0);
  for (var cell = 0; cell < 16; cell++) {
    final source = records[cell];
    tiles[position(cell)] = Tile(
      baseMask: mirrorMask(source.$1),
      rotation: (source.$2 * sign) % 4,
      isLocked: source.$3,
      couplingGroup: source.$4,
    );
    goal[position(cell)] = (reference[cell] * sign) % 4;
  }
  Puzzle make(int par) => Puzzle._(
    size: 4,
    seed: seed,
    levelNumber: levelNumber,
    startRow: start,
    endRow: end,
    tiles: tiles,
    starIndices: (twin ? {5, 2, 14} : {5, 3, 10}).map(position).toSet(),
    solutionRotations: goal,
    parMoves: par,
    label: VoyageProgression.forLevel(levelNumber).stageName,
  );
  final initial = make(0);
  final path = initial.solvedCopy().evaluate().route.toSet();
  for (var cell = 0; cell < 16; cell++) {
    tiles[cell] = tiles[cell].copyWith(isPath: path.contains(cell));
  }
  return make(initial.solutionActions.length);
}

bool _hasStrategyMechanics(Puzzle board) {
  final plan = VoyageProgression.forLevel(board.levelNumber);
  int count(TileKind kind) =>
      board.tiles.where((tile) => tile.kind == kind).length;
  return board.tiles.where((tile) => tile.isLocked).length ==
          plan.lockedRelays &&
      board.tiles
              .where((tile) => tile.kind == TileKind.relay && tile.isOneWay)
              .length ==
          plan.oneWayRelays &&
      board.tiles.where((tile) => tile.couplingGroup == 1).length ==
          (plan.hasTwins ? 2 : 0) &&
      board.tiles.where((tile) => tile.couplingGroup == 2).length ==
          (plan.hasTriplets ? 3 : 0) &&
      count(TileKind.bridge) == (plan.hasBridges ? 1 : 0) &&
      count(TileKind.crossway) == (plan.hasCrossways ? 1 : 0) &&
      count(TileKind.wormhole) == (plan.hasWormholes ? 2 : 0) &&
      count(TileKind.blackHole) == (plan.hasBlackHoles ? 1 : 0) &&
      count(TileKind.whiteHole) == (plan.hasWhiteHoles ? 1 : 0) &&
      count(TileKind.fork) == (plan.hasGravityForks ? 1 : 0) &&
      count(TileKind.weapon) ==
          (plan.hasWeapons ? (plan.hasShields ? 2 : 1) : 0) &&
      count(TileKind.shield) == (plan.hasShields ? 1 : 0) &&
      count(TileKind.disarm) == (plan.hasWeapons ? 1 : 0);
}

Puzzle _advancedStrategicReserve(int seed, int levelNumber) {
  final planet = VoyageProgression.forLevel(levelNumber).planetIndex;
  final canonicalPlanet = planet >= 14 ? (planet.isEven ? 14 : 15) : planet;
  final source = _createStrategicCandidate(
    seed: 0,
    levelNumber: (canonicalPlanet - 1) * 15 + 1,
    difficulty: Difficulty.balanced,
    attempt: 0,
  )!;
  final plan = VoyageProgression.forLevel(levelNumber);
  final random = _SeededRandom(
    seed ^ 0x52455335,
    levelNumber,
    Difficulty.balanced,
  );
  var board = source.solvedCopy();
  final groups = <int>{};
  final representatives = board.evaluate().route.where((cell) {
    final tile = board.tiles[cell];
    if (tile.isLocked || tile.kind == TileKind.bridge && !tile.isOneWay) {
      return false;
    }
    return tile.couplingGroup == 0 || groups.add(tile.couplingGroup);
  }).toList();
  random.shuffle(representatives);
  for (final cell in representatives.take(plan.baseScrambles)) {
    final tile = board.tiles[cell];
    final symmetric =
        !tile.isOneWay &&
        (tile.kind == TileKind.crossway ||
            tile.connections == (north | south) ||
            tile.connections == (east | west));
    final turns = symmetric ? 1 : 1 + random.nextInt(3);
    for (var turn = 0; turn < turns; turn++) {
      board = board.rotateAt(cell);
    }
  }
  if (board.evaluate().solved) board = board.rotateAt(representatives.first);
  return Puzzle._(
    size: source.size,
    seed: seed,
    levelNumber: levelNumber,
    startRow: source.startRow,
    endRow: source.endRow,
    tiles: board.tiles,
    starIndices: source.starIndices,
    solutionRotations: source.solutionRotations,
    parMoves: board.solutionActions.length,
    label: plan.stageName,
  );
}
