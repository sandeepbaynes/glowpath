import 'dart:math' as math;

import 'voyage_progression.dart';

part 'route_trace.dart';
part 'strategic_generation.dart';
part 'bounty_generation.dart';

/// Clockwise connection bits: north, east, south, west.
const int north = 1;
const int east = 2;
const int south = 4;
const int west = 8;

enum Difficulty { gentle, balanced, bright }

/// Persist with shared/daily puzzle identifiers when a backend is introduced.
/// Version 2 fixes native/web seed mixing and defines the PRNG and shuffle.
/// Bump this whenever generation changes an existing seed's board.
const int puzzleGeneratorVersion = 2;

enum TileKind {
  relay,
  bridge,
  crossway,
  fork,
  blackHole,
  whiteHole,
  wormhole,
  weapon,
  disarm,
  shield,
}

enum PuzzleFailure {
  brokenConnection,
  wrongWay,
  wrongExit,
  missingStars,
  loop,
  unpairedWormhole,
  weaponHit,
}

/// A rotatable channel. Multiple lanes are independent; linked groups share
/// one quarter-turn action. Gravity adds a visible, fixed orientation offset.
class Tile {
  const Tile({
    required this.baseMask,
    this.rotation = 0,
    this.isPath = false,
    this.isLocked = false,
    this.oneWayEntry = 0,
    this.kind = TileKind.relay,
    this.couplingGroup = 0,
    this.portalPeer,
    this.gravityPeer,
    this.gravityTurn = 0,
    this.circuit = 0,
  }) : assert(baseMask > 0 && baseMask <= 15),
       assert(
         oneWayEntry == 0 ||
             ((baseMask & oneWayEntry) != 0 &&
                 (oneWayEntry & (oneWayEntry - 1)) == 0),
       );
  final int baseMask,
      rotation,
      oneWayEntry,
      couplingGroup,
      gravityTurn,
      circuit;
  final bool isPath, isLocked;
  final TileKind kind;
  final int? portalPeer, gravityPeer;
  int get routeRotation => (rotation + gravityTurn) % 4;
  int get connections => _rotateMask(baseMask, routeRotation);
  int get entryDirection => _rotateMask(oneWayEntry, routeRotation);
  bool get isOneWay => oneWayEntry != 0;
  String get mechanicLabel => switch (kind) {
    TileKind.relay =>
      couplingGroup > 0
          ? 'Linked relay $couplingGroup'
          : isLocked
          ? 'Fixed relay'
          : isOneWay
          ? 'One-way relay'
          : 'Relay',
    TileKind.bridge => 'Bridge',
    TileKind.crossway => 'Crossway',
    TileKind.fork => 'Gravity fork',
    TileKind.blackHole => 'Black-hole pull',
    TileKind.whiteHole => 'White-hole push',
    TileKind.wormhole => 'Wormhole',
    TileKind.weapon => 'Weapon $circuit',
    TileKind.disarm => 'Defense switch $circuit',
    TileKind.shield => 'Shield charger',
  };
  Tile copyWith({
    int? rotation,
    bool? isLocked,
    int? oneWayEntry,
    TileKind? kind,
    int? couplingGroup,
    int? portalPeer,
    int? gravityPeer,
    int? gravityTurn,
    int? circuit,
    int? baseMask,
    bool? isPath,
  }) => Tile(
    baseMask: baseMask ?? this.baseMask,
    rotation: (rotation ?? this.rotation) % 4,
    isPath: isPath ?? this.isPath,
    isLocked: isLocked ?? this.isLocked,
    oneWayEntry: oneWayEntry ?? this.oneWayEntry,
    kind: kind ?? this.kind,
    couplingGroup: couplingGroup ?? this.couplingGroup,
    portalPeer: portalPeer ?? this.portalPeer,
    gravityPeer: gravityPeer ?? this.gravityPeer,
    gravityTurn: gravityTurn ?? this.gravityTurn,
    circuit: circuit ?? this.circuit,
  );
  Tile withRotation(int value) => copyWith(rotation: value);
  bool orientationMatches(Tile other) =>
      connections == other.connections &&
      entryDirection == other.entryDirection &&
      (kind != TileKind.crossway ||
          routeRotation % 2 == other.routeRotation % 2);
  Tile rotated() => isLocked ? this : withRotation(rotation + 1);
}

class PuzzleStatus {
  PuzzleStatus({
    required this.solved,
    required Set<int> litCells,
    required Set<int> collectedStars,
    this.blockedAt,
    this.failure,
    List<int> route = const [],
    Map<int, int> litPorts = const {},
  }) : litCells = Set<int>.unmodifiable(litCells),
       collectedStars = Set<int>.unmodifiable(collectedStars),
       route = List<int>.unmodifiable(route),
       litPorts = Map<int, int>.unmodifiable(litPorts);
  final bool solved;
  final Set<int> litCells, collectedStars;
  final int? blockedAt;
  final PuzzleFailure? failure;
  final List<int> route;
  final Map<int, int> litPorts;
  String get message => solved
      ? 'All three stars delivered. Mission complete.'
      : switch (failure) {
          PuzzleFailure.brokenConnection =>
            'The route breaks here. Align the next channel.',
          PuzzleFailure.wrongWay =>
            'Wrong-way entry. Follow the arrow from its tail.',
          PuzzleFailure.wrongExit =>
            'Route the rocket to the gold destination beacon.',
          PuzzleFailure.missingStars =>
            'Collect all three stars before docking.',
          PuzzleFailure.loop =>
            'This route loops back on itself. Open a route to the exit.',
          PuzzleFailure.unpairedWormhole =>
            'This wormhole needs a matching exit.',
          PuzzleFailure.weaponHit =>
            'Weapon armed. Route through its switch or charge a shield first.',
          null => 'Connect the launch beacon to the destination through all three stars.',
        };
}

/// Exact analysis of every geometrically legal route on a small relay board.
/// This does not use the generator's reference solution or par target.
class RelayRouteAnalysis {
  const RelayRouteAnalysis({
    required this.minimumMoves,
    required this.minimumCells,
    required this.routeCount,
  });

  final int? minimumMoves, minimumCells;
  final int routeCount;
}

class Puzzle {
  Puzzle._({
    required this.size,
    required this.seed,
    required this.levelNumber,
    required this.startRow,
    required this.endRow,
    required List<Tile> tiles,
    required Set<int> starIndices,
    required List<int> solutionRotations,
    required this.parMoves,
    required this.label,
    this.cargoCell,
    List<int>? bountyShortcutRotations,
  }) : tiles = List<Tile>.unmodifiable(tiles),
       starIndices = Set<int>.unmodifiable(starIndices),
       solutionRotations = List<int>.unmodifiable(solutionRotations),
       bountyShortcutRotations = bountyShortcutRotations == null
           ? null
           : List<int>.unmodifiable(bountyShortcutRotations);

  /// Three authored Journey lessons, separate from the version-2 generator.
  /// Their seed is an identifier only; the teaching layout is fixed per level.
  factory Puzzle.introduction({required int levelNumber, int seed = 0}) {
    if (levelNumber < 1 || levelNumber > 3) {
      throw ArgumentError.value(
        levelNumber,
        'levelNumber',
        'Expected 1, 2 or 3.',
      );
    }
    const size = 5;
    const paths = <List<int>>[
      [10, 11, 12, 13, 14],
      [5, 6, 7, 12, 17, 18, 19],
      [15, 16, 11, 6, 7, 8, 13, 18, 19],
    ];
    const stars = <Set<int>>[
      {11, 12, 13},
      {6, 12, 18},
      {11, 7, 18},
    ];
    const turnsToSolution = <Map<int, int>>[
      {10: 1},
      {7: 1, 17: 1, 19: 1},
      {16: 1, 6: 1, 8: 2, 18: 1},
    ];
    const titles = ['First launch', 'Around the bend', 'Three stars home'];
    final path = paths[levelNumber - 1];
    final tiles = List<Tile>.generate(
      size * size,
      (index) => Tile(
        baseMask: (index + levelNumber) % 3 == 0 ? north | south : north | east,
        rotation: (index * 3 + levelNumber) % 4,
      ),
    );
    for (var position = 0; position < path.length; position++) {
      final cell = path[position];
      final incoming = position == 0
          ? west
          : _directionBetween(cell, path[position - 1], size);
      final outgoing = position == path.length - 1
          ? east
          : _directionBetween(cell, path[position + 1], size);
      final mask = incoming | outgoing;
      final baseMask = mask == (north | south) || mask == (east | west)
          ? north | south
          : north | east;
      var rotation = 0;
      while (_rotateMask(baseMask, rotation) != mask) {
        rotation++;
      }
      tiles[cell] = Tile(baseMask: baseMask, rotation: rotation, isPath: true);
    }
    final solutionRotations = tiles.map((tile) => tile.rotation).toList();
    final turns = turnsToSolution[levelNumber - 1];
    for (final entry in turns.entries) {
      final tile = tiles[entry.key];
      tiles[entry.key] = Tile(
        baseMask: tile.baseMask,
        rotation: (tile.rotation - entry.value) % 4,
        isPath: true,
      );
    }
    return Puzzle._(
      size: size,
      seed: seed,
      levelNumber: levelNumber,
      startRow: path.first ~/ size,
      endRow: path.last ~/ size,
      tiles: tiles,
      starIndices: stars[levelNumber - 1],
      solutionRotations: solutionRotations,
      parMoves: turns.values.fold(0, (total, count) => total + count),
      label: titles[levelNumber - 1],
    );
  }

  /// Generates a bounded, deterministic route without backtracking or retries.
  ///
  /// The route visits each column once, moving vertically within that column
  /// before continuing east. It therefore cannot intersect itself. Feasibility
  /// checks leave enough vertical distance for the requested path length.
  factory Puzzle.generate({
    required int seed,
    int levelNumber = 1,
    Difficulty difficulty = Difficulty.balanced,
  }) {
    if (levelNumber < 1) {
      throw ArgumentError.value(
        levelNumber,
        'levelNumber',
        'Must be positive.',
      );
    }

    const size = 5;
    final random = _SeededRandom(seed, levelNumber, difficulty);
    final startRow = random.nextInt(size);
    final scrambledCount = math.min(
      21,
      3 + difficulty.index * 2 + (levelNumber - 1) ~/ 3,
    );
    final minimumLength = math.min(
      23,
      math.max(
        scrambledCount + 2,
        9 + difficulty.index * 2 + (levelNumber - 1) ~/ 4,
      ),
    );
    final requiredVerticalSteps = minimumLength - size;
    final path = <int>[];
    var row = startRow;
    var verticalSteps = 0;

    for (var column = 0; column < size; column++) {
      path.add(row * size + column);
      final remainingColumns = size - column - 1;
      final candidates = <int>[];
      for (var targetRow = 0; targetRow < size; targetRow++) {
        final distance = (targetRow - row).abs();
        final remainingCapacity = remainingColumns == 0
            ? 0
            : math.max(targetRow, size - 1 - targetRow) +
                  (remainingColumns - 1) * (size - 1);
        if (verticalSteps + distance + remainingCapacity >=
            requiredVerticalSteps) {
          candidates.add(targetRow);
        }
      }

      // At least one candidate exists: even the center starting row can reach
      // a 23-cell route, the maximum requested minimum length.
      final targetRow = candidates[random.nextInt(candidates.length)];
      final step = targetRow > row ? 1 : -1;
      while (row != targetRow) {
        row += step;
        verticalSteps++;
        path.add(row * size + column);
      }
    }
    final endRow = row;

    final tiles = List<Tile>.generate(
      size * size,
      (_) => Tile(
        baseMask: random.nextInt(3) == 0 ? north | south : north | east,
        rotation: random.nextInt(4),
      ),
    );
    for (var position = 0; position < path.length; position++) {
      final cell = path[position];
      final incoming = position == 0
          ? west
          : _directionBetween(cell, path[position - 1], size);
      final outgoing = position == path.length - 1
          ? east
          : _directionBetween(cell, path[position + 1], size);
      final mask = incoming | outgoing;
      final straight = mask == (north | south) || mask == (east | west);
      final baseMask = straight ? north | south : north | east;
      final rotation = List<int>.generate(
        4,
        (turn) => turn,
      ).firstWhere((turn) => _rotateMask(baseMask, turn) == mask);
      tiles[cell] = Tile(baseMask: baseMask, rotation: rotation, isPath: true);
    }
    final solutionRotations = tiles.map((tile) => tile.rotation).toList();

    // Place one star in each third of the route's interior, never at an exit.
    final interiorLength = path.length - 2;
    final starIndices = <int>{};
    for (var third = 0; third < 3; third++) {
      final first = third * interiorLength ~/ 3;
      final last = (third + 1) * interiorLength ~/ 3;
      starIndices.add(path[1 + first + random.nextInt(last - first)]);
    }

    final scrambleCandidates = path.skip(1).toList();
    random.shuffle(scrambleCandidates);
    final cellsToScramble = <int>[
      path.first,
      ...scrambleCandidates.take(scrambledCount - 1),
    ];
    for (final cell in cellsToScramble) {
      final tile = tiles[cell];
      final turnsToSolution = tile.baseMask == (north | south)
          ? 1
          : 1 + random.nextInt(3);
      tiles[cell] = Tile(
        baseMask: tile.baseMask,
        rotation: (tile.rotation - turnsToSolution) % 4,
        isPath: true,
      );
    }

    Puzzle build() => Puzzle._(
      size: size,
      seed: seed,
      levelNumber: levelNumber,
      startRow: startRow,
      endRow: endRow,
      tiles: tiles,
      starIndices: starIndices,
      solutionRotations: solutionRotations,
      parMoves: List<int>.generate(
        tiles.length,
        (cell) => (solutionRotations[cell] - tiles[cell].rotation) % 4,
      ).fold(0, (total, turns) => total + turns),
      label: _levelNames[(levelNumber - 1) % _levelNames.length],
    );

    var puzzle = build();
    if (puzzle.evaluate().solved) {
      // A scrambled route could theoretically find an alternative through
      // distractors. Close its entrance to guarantee a playable initial board.
      final cell = path.first;
      var tile = tiles[cell];
      while ((tile.connections & west) != 0) {
        tile = tile.rotated();
      }
      tiles[cell] = tile;
      puzzle = build();
    }
    return puzzle;
  }

  /// New Voyage/challenge layout. The legacy factories above remain unchanged
  /// so a saved generated-v2 or intro-v1 board can be resumed exactly.
  /// Every route has a known solution and contains all three collectable stars.
  factory Puzzle.voyage({
    required int seed,
    required int levelNumber,
    Difficulty difficulty = Difficulty.balanced,
  }) {
    if (levelNumber < 1) {
      throw ArgumentError.value(
        levelNumber,
        'levelNumber',
        'Must be positive.',
      );
    }
    final progression = LegacyVoyageProgression.forLevel(levelNumber);
    final size = progression.size;
    final random = _SeededRandom(seed ^ 0x4f524249, levelNumber, difficulty);
    final startRow = random.nextInt(size);
    final paceAdjustment = levelNumber <= 3 ? 0 : difficulty.index - 1;
    final scrambleCount = math.max(
      1,
      progression.baseScrambles + paceAdjustment,
    );
    // This is attainable even when the entrance starts in the middle row.
    final maximumMinimumLength = size * size - size ~/ 2;
    final minimumLength = math.min(
      maximumMinimumLength,
      math.max(
        progression.minimumRouteLength,
        scrambleCount + progression.lockedRelays + 2,
      ),
    );
    final requiredVerticalSteps = minimumLength - size;
    final path = <int>[];
    var row = startRow;
    var verticalSteps = 0;
    for (var column = 0; column < size; column++) {
      path.add(row * size + column);
      final remainingColumns = size - column - 1;
      final candidates = <int>[];
      for (var targetRow = 0; targetRow < size; targetRow++) {
        final distance = (targetRow - row).abs();
        final remainingCapacity = remainingColumns == 0
            ? 0
            : math.max(targetRow, size - 1 - targetRow) +
                  (remainingColumns - 1) * (size - 1);
        if (verticalSteps + distance + remainingCapacity >=
            requiredVerticalSteps) {
          candidates.add(targetRow);
        }
      }
      final targetRow = candidates[random.nextInt(candidates.length)];
      final step = targetRow > row ? 1 : -1;
      while (row != targetRow) {
        row += step;
        verticalSteps++;
        path.add(row * size + column);
      }
    }
    final tiles = List<Tile>.generate(
      size * size,
      (_) => Tile(
        baseMask: random.nextInt(3) == 0 ? north | south : north | east,
        rotation: random.nextInt(4),
      ),
    );
    final incomingDirections = <int, int>{};
    for (var position = 0; position < path.length; position++) {
      final cell = path[position];
      final incoming = position == 0
          ? west
          : _directionBetween(cell, path[position - 1], size);
      final outgoing = position == path.length - 1
          ? east
          : _directionBetween(cell, path[position + 1], size);
      incomingDirections[cell] = incoming;
      final mask = incoming | outgoing;
      final baseMask = mask == (north | south) || mask == (east | west)
          ? north | south
          : north | east;
      var rotation = 0;
      while (_rotateMask(baseMask, rotation) != mask) {
        rotation++;
      }
      tiles[cell] = Tile(baseMask: baseMask, rotation: rotation, isPath: true);
    }

    final interior = path.sublist(1, path.length - 1);
    random.shuffle(interior);
    final locked = interior.take(progression.lockedRelays).toSet();
    final directional = interior
        .where((cell) => !locked.contains(cell))
        .take(progression.oneWayRelays)
        .toSet();
    for (final cell in [...locked, ...directional]) {
      final tile = tiles[cell];
      tiles[cell] = Tile(
        baseMask: tile.baseMask,
        rotation: tile.rotation,
        isPath: true,
        isLocked: locked.contains(cell),
        oneWayEntry: directional.contains(cell)
            ? _rotateMask(incomingDirections[cell]!, -tile.rotation)
            : 0,
      );
    }
    final solutionRotations = tiles.map((tile) => tile.rotation).toList();
    final starIndices = <int>{};
    final interiorLength = path.length - 2;
    for (var third = 0; third < 3; third++) {
      final first = third * interiorLength ~/ 3;
      final last = (third + 1) * interiorLength ~/ 3;
      starIndices.add(path[1 + first + random.nextInt(last - first)]);
    }
    final others = path
        .skip(1)
        .where((cell) => !locked.contains(cell) && !directional.contains(cell))
        .toList();
    random.shuffle(others);
    // New directional relays always participate in the puzzle, rather than
    // being correctly aligned decorative additions.
    final scrambled = <int>[
      path.first,
      ...directional,
      ...others,
    ].take(scrambleCount);
    for (final cell in scrambled) {
      final tile = tiles[cell];
      final turns =
          levelNumber <= 3 ||
              (tile.baseMask == (north | south) && !tile.isOneWay)
          ? 1
          : 1 + random.nextInt(3);
      tiles[cell] = tile.withRotation(tile.rotation - turns);
    }

    int target() {
      var taps = 0;
      for (var cell = 0; cell < tiles.length; cell++) {
        final tile = tiles[cell];
        if (tile.isLocked) continue;
        final goal = tile.withRotation(solutionRotations[cell]);
        var turned = tile;
        while (!turned.orientationMatches(goal)) {
          turned = turned.rotated();
          taps++;
        }
      }
      return taps;
    }

    Puzzle build() => Puzzle._(
      size: size,
      seed: seed,
      levelNumber: levelNumber,
      startRow: startRow,
      endRow: row,
      tiles: tiles,
      starIndices: starIndices,
      solutionRotations: solutionRotations,
      parMoves: target(),
      label: progression.stageName,
    );
    var puzzle = build();
    if (puzzle.evaluate().solved) {
      var entrance = tiles[path.first];
      while ((entrance.connections & west) != 0) {
        entrance = entrance.rotated();
      }
      tiles[path.first] = entrance;
      puzzle = build();
    }
    return puzzle;
  }

  /// Version-four campaign: endless fifteen-route planets, with a certified
  /// reference route and scramble made only from legal player actions.
  factory Puzzle.planet({
    required int seed,
    required int levelNumber,
    Difficulty difficulty = Difficulty.balanced,
  }) {
    if (levelNumber < 1) throw ArgumentError.value(levelNumber, 'levelNumber');
    final plan = PlanetV4Progression.forLevel(levelNumber);
    final size = plan.size;
    final random = _SeededRandom(seed ^ 0x504c4e54, levelNumber, difficulty);
    var startRow = random.nextInt(size);
    final minLength = math.min(
      size * size - size ~/ 2,
      plan.minimumRouteLength + (plan.planetIndex >= 7 ? 3 : 0),
    );
    final requiredVerticalSteps = minLength - size;
    final rawPath = <int>[];
    var row = startRow, verticalSteps = 0;
    for (var column = 0; column < size; column++) {
      rawPath.add(row * size + column);
      final remainingColumns = size - column - 1;
      final candidates = <int>[];
      for (var targetRow = 0; targetRow < size; targetRow++) {
        final distance = (targetRow - row).abs();
        final remainingCapacity = remainingColumns == 0
            ? 0
            : math.max(targetRow, size - 1 - targetRow) +
                  (remainingColumns - 1) * (size - 1);
        if (verticalSteps + distance + remainingCapacity >=
            requiredVerticalSteps) {
          candidates.add(targetRow);
        }
      }
      final targetRow = candidates[random.nextInt(candidates.length)];
      final step = targetRow > row ? 1 : -1;
      while (row != targetRow) {
        row += step;
        verticalSteps++;
        rawPath.add(row * size + column);
      }
    }
    if (plan.planetIndex == 1) {
      // A complete winding route requires reasoning across the whole board.
      // Exclude the two obvious row-wise snakes; retain six Hamiltonian
      // geometries with six bends, including paths that travel left again.
      final opening =
          _openingRelayPaths[random.nextInt(_openingRelayPaths.length)];
      rawPath
        ..clear()
        ..addAll(opening);
      startRow = opening.first ~/ size;
      row = opening.last ~/ size;
    }
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
      final source =
          (plan.planetIndex.isEven ? black : white) ?? black ?? white!;
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
    if (plan.planetIndex == 1) {
      // Eight tiles must change, with a certified 12–16 clockwise taps to any
      // winning route. Resampling is bounded; the constructive fallback also
      // has exactly twelve taps and is checked by the independent enumerator.
      bool fairOpening(Puzzle candidate) {
        final analysis = candidate.relayRouteAnalysis!;
        return analysis.minimumMoves != null &&
            analysis.minimumMoves! >= 12 &&
            analysis.minimumMoves! <= 16 &&
            analysis.minimumCells == 9;
      }

      for (var attempt = 0; attempt < 12 && !fairOpening(result); attempt++) {
        for (var i = 0; i < tiles.length; i++) {
          tiles[i] = tiles[i].withRotation(reference[i]);
        }
        for (final cell in toScramble) {
          final mask = tiles[cell].connections;
          final turns = mask == (north | south) || mask == (east | west)
              ? 1
              : 1 + random.nextInt(3);
          tiles[cell] = tiles[cell].withRotation(reference[cell] - turns);
        }
        result = build(0);
      }
      if (!fairOpening(result)) {
        var extraTurns = 4;
        for (var i = 0; i < tiles.length; i++) {
          tiles[i] = tiles[i].withRotation(reference[i]);
        }
        for (final cell in toScramble) {
          final mask = tiles[cell].connections;
          final isBend = mask != (north | south) && mask != (east | west);
          final extra = isBend ? math.min(2, extraTurns) : 0;
          extraTurns -= extra;
          tiles[cell] = tiles[cell].withRotation(reference[cell] - 1 - extra);
        }
        result = build(0);
        if (!fairOpening(result)) {
          throw StateError('Uncertified opening $levelNumber / $seed');
        }
      }
    }
    if (result.evaluate().solved) {
      final cell = representatives.first;
      result = result.rotateAt(cell);
      for (var i = 0; i < tiles.length; i++) {
        tiles[i] = result.tiles[i];
      }
    }
    result = build(result.solutionActions.length);
    if (!result.solvedCopy().evaluate().solved) {
      throw StateError('Invalid certified planet $levelNumber / $seed');
    }
    return result;
  }

  /// Version-five routes add deliberate alternatives and meaningful star choices.
  factory Puzzle.strategicPlanet({
    required int seed,
    required int levelNumber,
    Difficulty difficulty = Difficulty.balanced,
  }) => _strategicPlanet(seed, levelNumber, difficulty);

  /// Version-six Voyage routes introduce optional salvage detours. Existing
  /// generators remain frozen so older saved boards reconstruct exactly.
  factory Puzzle.bountyPlanet({
    required int seed,
    required int levelNumber,
    Difficulty difficulty = Difficulty.balanced,
  }) => _bountyPlanet(seed, levelNumber, difficulty);

  /// Certified bounded-search reserves, also exposed for offline content audits.
  factory Puzzle.strategicReserve({
    required int seed,
    required int levelNumber,
  }) => VoyageProgression.forLevel(levelNumber).size == 4
      ? _strategicReserve(seed, levelNumber)
      : _advancedStrategicReserve(seed, levelNumber);

  StrategicRouteAnalysis? get strategicRouteAnalysis =>
      _analyzeStrategicRoutes(this);

  /// Explicit fixtures and authored teaching routes use the same evaluator.
  factory Puzzle.authored({
    required int size,
    required int startRow,
    required int endRow,
    required List<Tile> tiles,
    required Set<int> starIndices,
    List<int>? solutionRotations,
    int seed = 0,
    int levelNumber = 1,
    int? cargoCell,
  }) => Puzzle._(
    size: size,
    seed: seed,
    levelNumber: levelNumber,
    startRow: startRow,
    endRow: endRow,
    tiles: tiles,
    starIndices: starIndices,
    solutionRotations:
        solutionRotations ?? tiles.map((t) => t.rotation).toList(),
    parMoves: 0,
    label: 'Training route',
    cargoCell: cargoCell,
  );

  Puzzle rotateAt(int index) {
    if (index < 0 || index >= tiles.length || tiles[index].isLocked) {
      return this;
    }
    final group = tiles[index].couplingGroup;
    return copyWithTiles(
      List.generate(
        tiles.length,
        (i) => i == index || group != 0 && tiles[i].couplingGroup == group
            ? tiles[i].rotated()
            : tiles[i],
      ),
    );
  }

  /// Align only the lanes drawn by the player, using legal clockwise actions.
  /// This never consults the reference solution or mutates this board.
  TracePlan planTrace(List<int> cells, {int? entryPort, int? exitPort}) =>
      _planTrace(this, cells, entryPort: entryPort, exitPort: exitPort);

  /// Legal clockwise actions to reach the certified reference from this state.
  /// Group members are corrected together, including hint and replay callers.
  List<int> get solutionActions {
    var board = this;
    final actions = <int>[];
    final handledGroups = <int>{};
    final reference = solvedCopy();
    for (var i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      if (tile.isLocked ||
          tile.couplingGroup != 0 && !handledGroups.add(tile.couplingGroup)) {
        continue;
      }
      final members = tile.couplingGroup == 0
          ? [i]
          : [
              for (var j = 0; j < tiles.length; j++)
                if (tiles[j].couplingGroup == tile.couplingGroup) j,
            ];
      var count = 0;
      while (members.any(
            (j) => !board.tiles[j].orientationMatches(reference.tiles[j]),
          ) &&
          count++ < 4) {
        actions.add(i);
        board = board.rotateAt(i);
      }
      if (members.any(
        (j) => !board.tiles[j].orientationMatches(reference.tiles[j]),
      )) {
        throw StateError('Unreachable coupled orientation');
      }
    }
    return List.unmodifiable(actions);
  }

  /// Exhaustive simple-path search for 3×3 ordinary relay boards. A two-port
  /// relay cannot be revisited by a successful route, so this enumerates all
  /// possible solutions, including shortcuts unrelated to the reference.
  /// Returns null for larger boards or mechanics needing a different solver.
  RelayRouteAnalysis? get relayRouteAnalysis {
    if (size != 3 ||
        tiles.any(
          (tile) =>
              tile.kind != TileKind.relay ||
              tile.couplingGroup != 0 ||
              tile.gravityPeer != null ||
              tile.gravityTurn != 0 ||
              [
                    north,
                    east,
                    south,
                    west,
                  ].where((port) => tile.baseMask & port != 0).length !=
                  2,
        )) {
      return null;
    }
    int? minimumMoves, minimumCells;
    var routeCount = 0;
    final requiredStars = starIndices.fold(
      0,
      (bits, cell) => bits | (1 << cell),
    );

    int? cost(int cell, int inlet, int outlet) {
      final tile = tiles[cell];
      for (var turns = 0; turns < (tile.isLocked ? 1 : 4); turns++) {
        final candidate = tile.withRotation(tile.rotation + turns);
        if (candidate.connections == (inlet | outlet) &&
            (!candidate.isOneWay || candidate.entryDirection == inlet)) {
          return turns;
        }
      }
      return null;
    }

    void visit(int cell, int inlet, int seen, int moves, int count) {
      seen |= 1 << cell;
      if (cell == endRow * size + size - 1 &&
          seen & requiredStars == requiredStars) {
        final exitCost = cost(cell, inlet, east);
        if (exitCost != null) {
          final total = moves + exitCost;
          minimumMoves = minimumMoves == null
              ? total
              : math.min(minimumMoves!, total);
          minimumCells = minimumCells == null
              ? count
              : math.min(minimumCells!, count);
          routeCount++;
        }
      }
      for (final outlet in [north, east, south, west]) {
        if (outlet == inlet) continue;
        final next = _adjacentCell(cell, outlet, size);
        if (next == null || seen & (1 << next) != 0) continue;
        final turns = cost(cell, inlet, outlet);
        if (turns != null) {
          visit(next, _opposite(outlet), seen, moves + turns, count + 1);
        }
      }
    }

    visit(startRow * size, west, 0, 0, 1);
    return RelayRouteAnalysis(
      minimumMoves: minimumMoves,
      minimumCells: minimumCells,
      routeCount: routeCount,
    );
  }

  final int size;
  final int seed;
  final int levelNumber;
  final int startRow;
  final int endRow;
  final List<Tile> tiles;
  final Set<int> starIndices;
  final List<int> solutionRotations;

  /// Clockwise taps from the initial board to the supplied reference solution.
  /// This is a reference target, not a claim of the mathematically optimal route.
  final int parMoves;
  final String label;
  final int? cargoCell;
  bool get isBountyRoute => cargoCell != null;

  /// Certified no-cargo witness for offline content audits. Player-facing hints
  /// use the normal reference, and no route is exposed by the game interface.
  final List<int>? bountyShortcutRotations;

  Puzzle copyWithTiles(List<Tile> newTiles) {
    if (newTiles.length != size * size) {
      throw ArgumentError.value(
        newTiles.length,
        'newTiles.length',
        'Expected ${size * size} tiles.',
      );
    }
    return Puzzle._(
      size: size,
      seed: seed,
      levelNumber: levelNumber,
      startRow: startRow,
      endRow: endRow,
      tiles: newTiles,
      starIndices: starIndices,
      solutionRotations: solutionRotations,
      parMoves: parMoves,
      label: label,
      cargoCell: cargoCell,
      bountyShortcutRotations: bountyShortcutRotations,
    );
  }

  Puzzle solvedCopy() => copyWithTiles(
    List<Tile>.generate(
      tiles.length,
      (cell) => tiles[cell].withRotation(solutionRotations[cell]),
    ),
  );

  /// Traces ordered lanes, including revisits through independent crossings.
  /// All hazards are deterministic and visible before the rocket launches.
  PuzzleStatus evaluate() {
    final litCells = <int>{}, collectedStars = <int>{};
    final route = <int>[];
    final litPorts = <int, int>{};
    final seen = <String>{};
    final disabledCircuits = <int>{};
    var shield = false, portalArrival = false;
    var cell = startRow * size, incoming = west;
    PuzzleStatus stopped(PuzzleFailure failure) => PuzzleStatus(
      solved: false,
      litCells: litCells,
      collectedStars: collectedStars,
      blockedAt: cell,
      route: route,
      litPorts: litPorts,
      failure: failure,
    );
    for (var step = 0; step < size * size * 16; step++) {
      final tile = visualTileAt(cell);
      final state =
          '$cell/$incoming/$portalArrival/$shield/${disabledCircuits.toList()..sort()}';
      if (!seen.add(state)) return stopped(PuzzleFailure.loop);
      if ((tile.connections & incoming) == 0) {
        return stopped(PuzzleFailure.brokenConnection);
      }
      if (tile.isOneWay && tile.entryDirection != incoming) {
        return stopped(PuzzleFailure.wrongWay);
      }
      if (tile.kind == TileKind.weapon &&
          !disabledCircuits.contains(tile.circuit)) {
        if (!shield) return stopped(PuzzleFailure.weaponHit);
        shield = false;
      }
      if (tile.kind == TileKind.disarm) {
        if (!disabledCircuits.add(tile.circuit)) {
          disabledCircuits.remove(tile.circuit);
        }
      }
      if (tile.kind == TileKind.shield) shield = true;
      litCells.add(cell);
      route.add(cell);
      if (starIndices.contains(cell)) collectedStars.add(cell);
      final outgoing = outgoingAt(cell, incoming);
      if (outgoing == null) return stopped(PuzzleFailure.brokenConnection);
      litPorts[cell] = (litPorts[cell] ?? 0) | incoming | outgoing;
      if (tile.kind == TileKind.wormhole && !portalArrival) {
        final peer = tile.portalPeer;
        if (peer == null ||
            peer < 0 ||
            peer >= tiles.length ||
            tiles[peer].kind != TileKind.wormhole ||
            tiles[peer].portalPeer != cell ||
            !tiles[peer].isOneWay) {
          return stopped(PuzzleFailure.unpairedWormhole);
        }
        cell = peer;
        incoming = tiles[peer].entryDirection;
        portalArrival = true;
        continue;
      }
      portalArrival = false;
      final row = cell ~/ size, column = cell % size;
      final nextRow =
          row + (outgoing == south ? 1 : 0) - (outgoing == north ? 1 : 0);
      final nextColumn =
          column + (outgoing == east ? 1 : 0) - (outgoing == west ? 1 : 0);
      if (nextRow < 0 ||
          nextRow >= size ||
          nextColumn < 0 ||
          nextColumn >= size) {
        if (outgoing != east || column != size - 1 || row != endRow) {
          return stopped(PuzzleFailure.wrongExit);
        }
        if (!collectedStars.containsAll(starIndices)) {
          return stopped(PuzzleFailure.missingStars);
        }
        return PuzzleStatus(
          solved: true,
          litCells: litCells,
          collectedStars: collectedStars,
          route: route,
          litPorts: litPorts,
        );
      }
      cell = nextRow * size + nextColumn;
      incoming = _opposite(outgoing);
    }
    return stopped(PuzzleFailure.loop);
  }

  /// Gravity lanes respond to their source well's rotation. This is a real
  /// dependency: adjusting the well can change a remote bend or directed inlet.
  /// Saved rotations remain raw; painters and tracing use this resolved tile.
  Tile visualTileAt(int cell) {
    final tile = tiles[cell];
    final peer = tile.gravityPeer;
    if (peer == null ||
        peer < 0 ||
        peer >= tiles.length ||
        (tile.kind != TileKind.bridge && tile.kind != TileKind.crossway)) {
      return tile;
    }
    final source = tiles[peer];
    final phase =
        source.rotation * (source.kind == TileKind.whiteHole ? -1 : 1);
    return tile.copyWith(gravityTurn: (tile.gravityTurn + phase) % 4);
  }

  /// The actual lane selected by one inlet; painters may use this for previews.
  int? outgoingAt(int cell, int incoming) {
    final tile = visualTileAt(cell);
    if ((tile.connections & incoming) == 0) return null;
    if (tile.kind == TileKind.bridge) return _opposite(incoming);
    if (tile.kind == TileKind.crossway) {
      return _crossExit(incoming, tile.routeRotation);
    }
    final candidates = [
      for (final port in [north, east, south, west])
        if (port != incoming && tile.connections & port != 0) port,
    ];
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.single;
    if (tile.kind == TileKind.fork && tile.gravityPeer != null) {
      final source = tile.gravityPeer!;
      if (source < 0 || source >= tiles.length) return null;
      final pull = tiles[source].kind == TileKind.blackHole;
      candidates.sort(
        (a, b) => _gravityCompare(cell, a, b, source, pull, size),
      );
      return candidates.first;
    }
    if (tile.kind == TileKind.blackHole || tile.kind == TileKind.whiteHole) {
      final priority = _forkPriority(incoming, tile.kind);
      return priority.firstWhere(candidates.contains);
    }
    return null;
  }

  /// Call after solving; a solved board always earns between 100 and 200.
  int scoreForMoves(int moves) => puzzleScore(moves: moves, parMoves: parMoves);
}

/// Score for a completed puzzle, with no bonus beyond the 200-point cap.
int puzzleScore({required int moves, required int parMoves}) =>
    100 + math.max(0, 100 - 5 * math.max(0, moves - parMoves));

/// A versioned uint32 sequence with identical native Dart and JavaScript output.
/// Seeds are normalized to their low 32 bits. Each shift is masked before the
/// next operation; no multiplication can lose JavaScript integer precision.
class _SeededRandom {
  _SeededRandom(int seed, int levelNumber, Difficulty difficulty) {
    var state = _xorshift32((seed & _uint32Mask) ^ 0x9e3779b9);
    state = _xorshift32(state ^ (levelNumber & _uint32Mask));
    state = _xorshift32(
      state ^ ((difficulty.index + 1) << 24) ^ puzzleGeneratorVersion,
    );
    // Xorshift32's all-zero state is absorbing, so use a fixed nonzero fallback.
    _state = state == 0 ? 0x6d2b79f5 : state;
  }

  static const _uint32Mask = 0xffffffff;
  late int _state;

  int nextInt(int upperBound) {
    assert(upperBound > 0);
    _state = _xorshift32(_state);
    return _state % upperBound;
  }

  /// Explicit Fisher–Yates order is part of the generator version contract.
  void shuffle<T>(List<T> values) {
    for (var last = values.length - 1; last > 0; last--) {
      final selected = nextInt(last + 1);
      final value = values[last];
      values[last] = values[selected];
      values[selected] = value;
    }
  }

  static int _xorshift32(int value) {
    var state = value & _uint32Mask;
    state = (state ^ ((state << 13) & _uint32Mask)) & _uint32Mask;
    state = (state ^ (state >>> 17)) & _uint32Mask;
    return (state ^ ((state << 5) & _uint32Mask)) & _uint32Mask;
  }
}

int _rotateMask(int mask, int rotation) {
  final turns = rotation % 4;
  return ((mask << turns) | (mask >> (4 - turns))) & 15;
}

int _directionBetween(int from, int to, int size) {
  if (to == from - size) return north;
  if (to == from + 1) return east;
  if (to == from + size) return south;
  if (to == from - 1) return west;
  throw StateError('Route cells must be adjacent.');
}

int? _adjacentCell(int cell, int port, int size) {
  final row = cell ~/ size, column = cell % size;
  return switch (port) {
    north when row > 0 => cell - size,
    east when column < size - 1 => cell + 1,
    south when row < size - 1 => cell + size,
    west when column > 0 => cell - 1,
    _ => null,
  };
}

// Enumerated once, instead of retrying random walks. There are only six
// nine-cell, six-bend routes between the left and right edges of a 3×3 grid.
final List<List<int>> _openingRelayPaths = (() {
  final routes = <List<int>>[];
  void visit(List<int> path, int seen) {
    final cell = path.last;
    if (path.length == 9) {
      if (cell % 3 != 2) return;
      var bends = 0;
      for (var i = 0; i < path.length; i++) {
        final inlet = i == 0
            ? west
            : _directionBetween(path[i], path[i - 1], 3);
        final outlet = i == 8
            ? east
            : _directionBetween(path[i], path[i + 1], 3);
        if (_opposite(inlet) != outlet) bends++;
      }
      if (bends == 6) routes.add(List<int>.unmodifiable(path));
      return;
    }
    for (final port in [north, east, south, west]) {
      final next = _adjacentCell(cell, port, 3);
      if (next != null && seen & (1 << next) == 0) {
        visit([...path, next], seen | (1 << next));
      }
    }
  }

  for (final start in [0, 3, 6]) {
    visit([start], 1 << start);
  }
  return List<List<int>>.unmodifiable(routes);
})();

const _levelNames = <String>[
  'First light',
  'Warm current',
  'Quiet corners',
  'Copper crossing',
  'Golden hour',
  'Soft circuit',
  'Afterglow',
  'Little detour',
  'Amber trail',
  'Northern lights',
  'Bright idea',
  'Winding down',
  'Sunbeam',
  'Evening ember',
  'Three wishes',
  'Light garden',
  'Gentle zigzag',
  'Spark parade',
  'Twilight turn',
  'Radiance',
  'Hidden lantern',
  'Firefly lane',
  'Solar drift',
  'Luminous loop',
  'Daybreak',
  'Golden thread',
  'Starlit way',
  'Brilliant bend',
  'Aurora',
  'Full glow',
];

int _opposite(int port) => _rotateMask(port, 2);
int _crossExit(int incoming, int rotation) {
  final local = _rotateMask(incoming, -rotation);
  return _rotateMask(switch (local) {
    north => east,
    east => north,
    south => west,
    west => south,
    _ => 0,
  }, rotation);
}

List<int> _forkPriority(int incoming, TileKind kind) {
  final travel = _opposite(incoming);
  return [
    _rotateMask(travel, kind == TileKind.blackHole ? 1 : -1),
    travel,
    _rotateMask(travel, kind == TileKind.blackHole ? -1 : 1),
  ];
}

int? _forkMask(int incoming, int outgoing, TileKind kind) {
  final priority = _forkPriority(incoming, kind);
  final rank = priority.indexOf(outgoing);
  if (rank < 0 || rank >= 2) return null;
  return incoming | outgoing | priority[rank + 1];
}

int _gravityDistance(int cell, int port, int source, int size) {
  final row =
      cell ~/ size +
      (port == south
          ? 1
          : port == north
          ? -1
          : 0);
  final col =
      cell % size +
      (port == east
          ? 1
          : port == west
          ? -1
          : 0);
  return (row - source ~/ size).abs() + (col - source % size).abs();
}

int _gravityCompare(int cell, int a, int b, int source, bool pull, int size) {
  final difference =
      _gravityDistance(cell, a, source, size) -
      _gravityDistance(cell, b, source, size);
  return difference == 0
      ? a.compareTo(b)
      : pull
      ? difference
      : -difference;
}

int? _gravityForkMask(
  int cell,
  int incoming,
  int outgoing,
  int source,
  bool pull,
  int size,
) {
  for (final extra in [north, east, south, west]) {
    if (extra != incoming &&
        extra != outgoing &&
        _gravityCompare(cell, outgoing, extra, source, pull, size) < 0) {
      return incoming | outgoing | extra;
    }
  }
  return null;
}

int _gravityQuarter(int cell, int source, bool pull, int size) {
  final dy = source ~/ size - cell ~/ size, dx = source % size - cell % size;
  final direction = dx.abs() >= dy.abs()
      ? dx >= 0
            ? east
            : west
      : dy >= 0
      ? south
      : north;
  return [
    north,
    east,
    south,
    west,
  ].indexOf(pull ? direction : _opposite(direction));
}
