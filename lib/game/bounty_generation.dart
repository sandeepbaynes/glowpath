part of 'puzzle.dart';

/// One salvage choice per five-route leg, beginning on Viridian. Other routes
/// retain the exact strategic generator, including all advanced mechanics.
Puzzle _bountyPlanet(int seed, int levelNumber, Difficulty difficulty) {
  if (levelNumber < 31 || (levelNumber - 31) % 5 != 0) {
    return _strategicPlanet(seed, levelNumber, difficulty);
  }
  final plan = VoyageProgression.forLevel(levelNumber);
  const size = 5;
  final random = _SeededRandom(seed ^ 0x424E5436, levelNumber, difficulty);
  final pair = _bountyRoutePairs[random.nextInt(_bountyRoutePairs.length)];
  final vertical = random.nextInt(2) == 1, horizontal = random.nextInt(2) == 1;
  List<int> transform(List<int> route) {
    final result = [
      for (final cell in route)
        (vertical ? 4 - cell ~/ 5 : cell ~/ 5) * 5 +
            (horizontal ? 4 - cell % 5 : cell % 5),
    ];
    return horizontal ? result.reversed.toList() : result;
  }

  final detour = transform(pair.$1), shortcut = transform(pair.$2);
  int entry(List<int> route, int p) =>
      p == 0 ? west : _directionBetween(route[p], route[p - 1], size);
  int exit(List<int> route, int p) => p == route.length - 1
      ? east
      : _directionBetween(route[p], route[p + 1], size);
  Map<int, (int, int)> ports(List<int> route) => {
    for (var p = 0; p < route.length; p++)
      route[p]: (entry(route, p), exit(route, p)),
  };
  final longPorts = ports(detour), shortPorts = ports(shortcut);
  final detourOnly = detour
      .where((cell) => !shortPorts.containsKey(cell))
      .toList();
  final cargo = detourOnly[detourOnly.length ~/ 2];
  final common = detour.where(shortPorts.containsKey).toList();
  final starPool = common
      .where((c) => c != detour.first && c != detour.last)
      .toList();
  final stars = <int>{
    for (var i = 0; i < 3; i++)
      starPool[((i * 2 + 1) * starPool.length ~/ 6).clamp(
        0,
        starPool.length - 1,
      )],
  };
  final tiles = List.generate(
    size * size,
    (_) => Tile(
      baseMask: random.nextInt(3) == 0 ? north | south : north | east,
      rotation: random.nextInt(4),
    ),
  );
  // Both witnesses use the same turn/straight geometry at shared cells. Their
  // branch endpoints can therefore be rerouted with ordinary legal rotations.
  for (final routePorts in [shortPorts, longPorts]) {
    for (final cell in routePorts.keys) {
      final p = routePorts[cell]!;
      tiles[cell] = Tile(baseMask: p.$1 | p.$2, isPath: true);
    }
  }
  final stable = common
      .where(
        (c) =>
            c != detour.first &&
            c != detour.last &&
            longPorts[c] == shortPorts[c],
      )
      .toList();
  final reserved = <int>{detour.first, detour.last, cargo};
  final candidates = stable.toList()..sort();
  random.shuffle(candidates);
  int? take(bool Function(int) eligible) {
    for (final cell in candidates) {
      if (!reserved.contains(cell) && eligible(cell)) {
        reserved.add(cell);
        return cell;
      }
    }
    return null;
  }

  // On salvage routes, hazards sit on the common trunk. Choosing the shortcut
  // never bypasses defense order, and choosing the cargo adds only visible risk.
  if (plan.hasWeapons && stable.length >= 2) {
    final control = stable.first, weapon = stable.last;
    reserved.addAll([control, weapon]);
    tiles[control] = tiles[control].copyWith(
      kind: plan.hasShields && plan.planetIndex.isOdd
          ? TileKind.shield
          : TileKind.disarm,
      circuit: 1,
    );
    tiles[weapon] = tiles[weapon].copyWith(kind: TileKind.weapon, circuit: 1);
  }
  if (plan.hasBridges) {
    final cell = take((c) => longPorts[c]!.$2 == _opposite(longPorts[c]!.$1));
    if (cell != null) {
      tiles[cell] = tiles[cell].copyWith(
        kind: TileKind.bridge,
        baseMask: 15,
        oneWayEntry: plan.planetIndex >= 14 ? longPorts[cell]!.$1 : 0,
      );
    }
  }
  if (plan.hasCrossways) {
    final cell = take((c) => longPorts[c]!.$2 != _opposite(longPorts[c]!.$1));
    if (cell != null) {
      final p = longPorts[cell]!;
      var rotation = 0;
      while (_crossExit(p.$1, rotation) != p.$2) {
        rotation++;
      }
      tiles[cell] = tiles[cell].copyWith(
        kind: TileKind.crossway,
        baseMask: 15,
        rotation: rotation,
        oneWayEntry: plan.planetIndex >= 14 ? _rotateMask(p.$1, -rotation) : 0,
      );
    }
  }
  int? black, white;
  for (final kind in [
    if (plan.hasBlackHoles) TileKind.blackHole,
    if (plan.hasWhiteHoles) TileKind.whiteHole,
  ]) {
    final cell = take(
      (c) => _forkMask(longPorts[c]!.$1, longPorts[c]!.$2, kind) != null,
    );
    if (cell == null) continue;
    tiles[cell] = tiles[cell].copyWith(
      kind: kind,
      baseMask: _forkMask(longPorts[cell]!.$1, longPorts[cell]!.$2, kind),
    );
    if (kind == TileKind.blackHole) {
      black = cell;
    } else {
      white = cell;
    }
  }
  if (plan.hasGravityForks) {
    for (final source in [?black, ?white]) {
      final pull = tiles[source].kind == TileKind.blackHole;
      final cell = take(
        (c) =>
            _gravityForkMask(
              c,
              longPorts[c]!.$1,
              longPorts[c]!.$2,
              source,
              pull,
              size,
            ) !=
            null,
      );
      if (cell == null) continue;
      tiles[cell] = tiles[cell].copyWith(
        kind: TileKind.fork,
        baseMask: _gravityForkMask(
          cell,
          longPorts[cell]!.$1,
          longPorts[cell]!.$2,
          source,
          pull,
          size,
        ),
        gravityPeer: source,
      );
      break;
    }
  }
  for (var i = 0; i < plan.lockedRelays; i++) {
    final cell = take((c) => tiles[c].kind == TileKind.relay);
    if (cell != null) tiles[cell] = tiles[cell].copyWith(isLocked: true);
  }
  for (var i = 0; i < plan.oneWayRelays; i++) {
    final cell = take((c) => tiles[c].kind == TileKind.relay);
    if (cell != null) {
      tiles[cell] = tiles[cell].copyWith(oneWayEntry: longPorts[cell]!.$1);
    }
  }
  // Linked cells can sit on either branch, but never at the switch points:
  // both certified solutions agree on the group's orientation.
  final linkable = <int>[
    for (final cell in {...detour, ...shortcut})
      if (!reserved.contains(cell) &&
          tiles[cell].kind == TileKind.relay &&
          !tiles[cell].isLocked &&
          (!longPorts.containsKey(cell) ||
              !shortPorts.containsKey(cell) ||
              longPorts[cell] == shortPorts[cell]))
        cell,
  ];
  random.shuffle(linkable);
  if (plan.hasTwins && linkable.length >= 2) {
    final count = plan.hasTriplets && linkable.length >= 3 ? 3 : 2;
    for (final cell in linkable.take(count)) {
      tiles[cell] = tiles[cell].copyWith(couplingGroup: 1);
    }
  }
  final reference = tiles.map((t) => t.rotation).toList();
  final alternate = reference.toList();
  for (final cell in shortcut) {
    if (longPorts[cell] == shortPorts[cell] || !longPorts.containsKey(cell)) {
      continue;
    }
    final p = shortPorts[cell]!;
    var rotation = 0;
    while (_rotateMask(tiles[cell].baseMask, rotation) != (p.$1 | p.$2)) {
      if (++rotation == 4) throw StateError('Incompatible salvage junction');
    }
    alternate[cell] = rotation;
  }
  final seenGroups = <int>{};
  final scrambles = <int>[
    for (final cell in {...detour, ...shortcut})
      if (!tiles[cell].isLocked &&
          (tiles[cell].couplingGroup == 0 ||
              seenGroups.add(tiles[cell].couplingGroup)))
        cell,
  ];
  random.shuffle(scrambles);
  for (final cell in scrambles.take(plan.baseScrambles)) {
    final turns = 1 + random.nextInt(3), group = tiles[cell].couplingGroup;
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
    startRow: detour.first ~/ size,
    endRow: detour.last ~/ size,
    tiles: tiles,
    starIndices: stars,
    solutionRotations: reference,
    bountyShortcutRotations: alternate,
    cargoCell: cargo,
    parMoves: par,
    label: 'Salvage corridor',
  );
  var result = build(0);
  if (result.evaluate().solved) {
    final first = scrambles.first;
    result = result.rotateAt(first);
    for (var i = 0; i < tiles.length; i++) {
      tiles[i] = result.tiles[i];
    }
  }
  result = build(result.solutionActions.length);
  final withCargo = result.solvedCopy().evaluate();
  final withoutCargo = result.copyWithTiles([
    for (var i = 0; i < tiles.length; i++) tiles[i].withRotation(alternate[i]),
  ]).evaluate();
  if (!withCargo.solved ||
      !withCargo.route.contains(cargo) ||
      !withoutCargo.solved ||
      withoutCargo.route.contains(cargo)) {
    throw StateError('Uncertified optional salvage route $levelNumber / $seed');
  }
  return result;
}

// Sixteen independently certified two-route geometries, with vertical and
// horizontal/reversed reflections. Every long path contains 19–23 cells; the
// shorter route bypasses optional cargo but shares all three mandatory stars.
// Runtime work is fixed and bounded; no search or retries are needed.
const _bountyRoutePairs = <(List<int>, List<int>)>[
  (
    [20, 15, 16, 21, 22, 23, 18, 13, 14, 9, 8, 7, 6, 11, 10, 5, 0, 1, 2, 3, 4],
    [20, 15, 16, 11, 10, 5, 0, 1, 2, 3, 4],
  ),
  (
    [
      20,
      15,
      10,
      5,
      0,
      1,
      2,
      7,
      8,
      3,
      4,
      9,
      14,
      19,
      18,
      13,
      12,
      11,
      16,
      21,
      22,
      23,
      24,
    ],
    [20, 15, 10, 5, 0, 1, 2, 7, 8, 13, 12, 11, 16, 21, 22, 23, 24],
  ),
  (
    [5, 6, 7, 2, 3, 8, 9, 14, 19, 18, 17, 12, 11, 16, 15, 20, 21, 22, 23, 24],
    [5, 6, 7, 12, 11, 16, 15, 20, 21, 22, 23, 24],
  ),
  (
    [10, 11, 16, 15, 20, 21, 22, 23, 18, 19, 14, 9, 8, 7, 6, 5, 0, 1, 2, 3, 4],
    [10, 11, 16, 17, 12, 13, 18, 19, 14, 9, 8, 7, 6, 5, 0, 1, 2, 3, 4],
  ),
  (
    [
      5,
      0,
      1,
      2,
      3,
      8,
      9,
      14,
      19,
      18,
      13,
      12,
      17,
      16,
      11,
      10,
      15,
      20,
      21,
      22,
      23,
      24,
    ],
    [5, 0, 1, 2, 3, 8, 7, 6, 11, 10, 15, 20, 21, 22, 23, 24],
  ),
  (
    [20, 21, 22, 17, 16, 15, 10, 5, 0, 1, 6, 7, 2, 3, 4, 9, 14, 13, 18, 19],
    [20, 21, 22, 17, 16, 15, 10, 5, 0, 1, 6, 7, 12, 13, 18, 19],
  ),
  (
    [0, 1, 6, 11, 10, 15, 16, 21, 22, 17, 18, 13, 14, 9, 8, 7, 2, 3, 4],
    [0, 1, 6, 11, 12, 17, 18, 13, 14, 9, 8, 7, 2, 3, 4],
  ),
  (
    [20, 15, 16, 11, 10, 5, 0, 1, 2, 7, 8, 9, 14, 19, 18, 17, 22, 23, 24],
    [20, 15, 16, 11, 12, 7, 8, 9, 14, 19, 18, 17, 22, 23, 24],
  ),
  (
    [15, 20, 21, 16, 11, 10, 5, 6, 1, 2, 3, 4, 9, 8, 13, 18, 23, 24, 19],
    [15, 20, 21, 16, 11, 12, 7, 8, 13, 18, 23, 24, 19],
  ),
  (
    [20, 15, 16, 17, 18, 23, 24, 19, 14, 9, 8, 13, 12, 11, 6, 5, 0, 1, 2, 3, 4],
    [20, 15, 16, 17, 18, 13, 12, 11, 6, 5, 0, 1, 2, 3, 4],
  ),
  (
    [20, 15, 16, 11, 10, 5, 6, 1, 2, 7, 12, 17, 18, 23, 24, 19, 14, 9, 8, 3, 4],
    [20, 15, 16, 21, 22, 17, 18, 23, 24, 19, 14, 9, 8, 3, 4],
  ),
  (
    [15, 20, 21, 16, 11, 12, 17, 22, 23, 18, 13, 14, 9, 8, 7, 6, 1, 2, 3, 4],
    [15, 20, 21, 16, 11, 10, 5, 6, 1, 2, 3, 4],
  ),
  (
    [
      5,
      0,
      1,
      2,
      7,
      8,
      3,
      4,
      9,
      14,
      13,
      18,
      17,
      16,
      11,
      10,
      15,
      20,
      21,
      22,
      23,
      24,
    ],
    [5, 0, 1, 2, 7, 6, 11, 10, 15, 20, 21, 22, 23, 24],
  ),
  (
    [20, 15, 16, 21, 22, 17, 12, 13, 8, 7, 6, 11, 10, 5, 0, 1, 2, 3, 4],
    [20, 15, 16, 11, 10, 5, 0, 1, 2, 3, 4],
  ),
  (
    [5, 6, 7, 12, 17, 16, 15, 20, 21, 22, 23, 24, 19, 18, 13, 8, 3, 4, 9],
    [5, 6, 7, 12, 17, 18, 13, 8, 3, 4, 9],
  ),
  (
    [20, 21, 22, 17, 16, 15, 10, 5, 6, 1, 2, 3, 4, 9, 8, 13, 18, 23, 24],
    [20, 21, 22, 17, 16, 15, 10, 5, 6, 11, 12, 7, 8, 13, 18, 23, 24],
  ),
];
