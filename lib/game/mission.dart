/// Rocket-routing rules are independent of UI clocks and animation.
abstract final class MissionDirection {
  static const north = 1;
  static const east = 2;
  static const south = 4;
  static const west = 8;
}

enum CellKind {
  relay,
  lockedRelay,
  block,
  oneWay,
  wormhole,
  blackHole,
  whiteHole,
  slingshot,
  asteroid,
}

enum FlightTransition { adjacent, wormhole, slingshot, wrap }

enum FlightFailure {
  brokenConnection,
  blocked,
  wrongWay,
  wrongExit,
  missingStars,
  loop,
  asteroidCollision,
  unpairedWormhole,
  slingshotMiss,
}

class MissionCell {
  const MissionCell({
    this.kind = CellKind.relay,
    required this.baseMask,
    this.rotation = 0,
    this.baseInput = 0,
    this.portalPair,
    this.riskPercent = 0,
  });

  final CellKind kind;
  final int baseMask;
  final int rotation;
  final int baseInput;
  final int? portalPair;
  final int riskPercent;

  int get connections => _rotate(baseMask, rotation);
  int get input => _rotate(baseInput, rotation);
  int get output => connections & ~input;
  bool get rotatable => kind != CellKind.block && kind != CellKind.lockedRelay;

  MissionCell rotated() => rotatable ? withRotation(rotation + 1) : this;

  MissionCell withRotation(int value) => MissionCell(
    kind: kind,
    baseMask: baseMask,
    rotation: value % 4,
    baseInput: baseInput,
    portalPair: portalPair,
    riskPercent: riskPercent,
  );
}

class FlightStep {
  const FlightStep({
    required this.cellIndex,
    required this.incoming,
    this.outgoing,
    this.nextCell,
    this.transition = FlightTransition.adjacent,
  });

  final int cellIndex;
  final int incoming;
  final int? outgoing;
  final int? nextCell;
  final FlightTransition transition;
}

class FlightResult {
  FlightResult({
    required this.success,
    required List<FlightStep> steps,
    required Set<int> collectedStars,
    this.failure,
    this.failureCell,
  }) : steps = List.unmodifiable(steps),
       collectedStars = Set.unmodifiable(collectedStars);

  final bool success;
  final List<FlightStep> steps;
  final FlightFailure? failure;
  final int? failureCell;
  final Set<int> collectedStars;

  String get message => success
      ? 'All three signals collected. Landing confirmed.'
      : switch (failure) {
          FlightFailure.brokenConnection =>
            'The next relay does not connect to the incoming flight path.',
          FlightFailure.blocked =>
            'An asteroid block stops this route. Find a way around it.',
          FlightFailure.wrongWay =>
            'This directed relay was approached from the wrong side.',
          FlightFailure.wrongExit =>
            'The rocket left the grid away from the landing beacon.',
          FlightFailure.missingStars =>
            'The landing beacon needs all three signals.',
          FlightFailure.loop =>
            'The rocket returned to a visited relay. Break the loop.',
          FlightFailure.asteroidCollision => 'The marked asteroid shortcut caused a collision. The safe route avoids this risk.',
          FlightFailure.unpairedWormhole =>
            'This wormhole has no matching exit.',
          FlightFailure.slingshotMiss =>
            'The slingshot must land on a relay inside the grid.',
          null => 'The flight could not be completed.',
        };
}

class Mission {
  Mission._({
    required this.number,
    required this.title,
    required this.briefing,
    required this.timeLimitSeconds,
    required this.startRow,
    required this.endRow,
    required List<MissionCell> cells,
    required Set<int> starIndices,
    required List<int> referenceRotations,
    required List<int> referencePath,
    required this.parMoves,
    required this.wrapEdges,
    List<int>? riskRouteRotations,
  }) : cells = List.unmodifiable(cells),
       starIndices = Set.unmodifiable(starIndices),
       referenceRotations = List.unmodifiable(referenceRotations),
       referencePath = List.unmodifiable(referencePath),
       riskRouteRotations = riskRouteRotations == null
           ? null
           : List.unmodifiable(riskRouteRotations);

  static const campaignCount = 15;
  static const campaignVersion = 1;
  static const gridSize = 5;
  int get size => gridSize;
  final int number;
  final String title;
  final String briefing;
  final int timeLimitSeconds;
  final int startRow;
  final int endRow;
  final List<MissionCell> cells;
  final Set<int> starIndices;
  final List<int> referenceRotations;
  final List<int> referencePath;
  final int parMoves;
  final bool wrapEdges;

  /// An authored optional shortcut used for validation; the safe path avoids it.
  final List<int>? riskRouteRotations;

  List<String> get rules => List.unmodifiable([
    'Collect all three signals and leave through the right-hand landing beacon.',
    if (cells.any((cell) => cell.kind == CellKind.block))
      'Solid blocks cannot be entered or rotated.',
    if (cells.any((cell) => cell.kind == CellKind.lockedRelay))
      'Locked relays cannot rotate; route through their fixed connections.',
    if (cells.any((cell) => cell.kind == CellKind.oneWay))
      'One-way relays accept flight only at the tail of their arrow.',
    if (cells.any((cell) => cell.kind == CellKind.wormhole)) 'Enter a wormhole at its arrow tail; emerge from its partner’s arrow head.',
    if (cells.any((cell) => cell.kind == CellKind.blackHole)) 'Black-hole forks prefer a clockwise turn, then straight, then counterclockwise.',
    if (cells.any((cell) => cell.kind == CellKind.whiteHole)) 'White-hole forks prefer a counterclockwise turn, then straight, then clockwise.',
    if (cells.any((cell) => cell.kind == CellKind.slingshot)) 'Slingshots follow their arrow and leap over one cell; the landing relay must connect.',
    if (cells.any((cell) => cell.kind == CellKind.asteroid)) 'Marked asteroid fields show their collision chance. The safe detour avoids this risk.',
    if (wrapEdges) 'Edge gates wrap to the opposite edge in the same row or column. The landing beacon still ends the flight.',
  ]);

  factory Mission.campaign(int number) {
    if (number < 1 || number > campaignCount) {
      throw ArgumentError.value(number, 'number', 'Expected 1–$campaignCount.');
    }
    final spec = _campaign[number - 1];
    final cells = List<MissionCell>.generate(
      25,
      (index) => MissionCell(
        baseMask: index % 3 == 0 ? _n | _s : _n | _e,
        rotation: (index * 3 + number) % 4,
      ),
    );
    for (final index in spec.blocks) {
      cells[index] = const MissionCell(kind: CellKind.block, baseMask: 0);
    }
    for (final entry in spec.risks.entries) {
      cells[entry.key] = MissionCell(
        kind: CellKind.asteroid,
        baseMask: _e | _w,
        riskPercent: entry.value,
      );
    }
    for (var position = 0; position < spec.path.length; position++) {
      final index = spec.path[position];
      final kind = spec.kinds[index] ?? CellKind.relay;
      final previous = position == 0 ? null : spec.path[position - 1];
      final next = position == spec.path.length - 1
          ? null
          : spec.path[position + 1];
      final pair = spec.portals[index];
      final portalArrival = pair != null && previous == pair;
      final portalDeparture = pair != null && next == pair;
      final outgoing = portalDeparture
          ? _opposite(_direction(index, previous!, wrap: spec.wrap))
          : next == null
          ? _e
          : _direction(index, next, wrap: spec.wrap);
      final incoming = portalArrival
          ? _opposite(outgoing)
          : previous == null
          ? _w
          : _direction(index, previous, wrap: spec.wrap);
      final mask = kind == CellKind.blackHole || kind == CellKind.whiteHole
          ? _forkMask(incoming, outgoing, kind)
          : incoming | outgoing;
      cells[index] = MissionCell(
        kind: kind,
        baseMask: mask,
        baseInput: _directed(kind) ? incoming : 0,
        portalPair: pair,
      );
    }
    final reference = cells.map((cell) => cell.rotation).toList();
    final risky = spec.risks.isEmpty ? null : reference.toList();
    if (risky != null) {
      risky[11] = 2;
      risky[13] = 2;
    }
    for (final entry in spec.turns.entries) {
      if (!cells[entry.key].rotatable) {
        throw StateError('Cannot scramble a locked relay.');
      }
      cells[entry.key] = cells[entry.key].withRotation(
        reference[entry.key] - entry.value,
      );
    }
    return Mission._(
      number: number,
      title: spec.title,
      briefing: spec.briefing,
      timeLimitSeconds: spec.seconds,
      startRow: spec.path.first ~/ gridSize,
      endRow: spec.path.last ~/ gridSize,
      cells: cells,
      starIndices: spec.stars,
      referenceRotations: reference,
      referencePath: spec.path,
      parMoves: spec.turns.values.fold(0, (total, count) => total + count),
      wrapEdges: spec.wrap,
      riskRouteRotations: risky,
    );
  }

  Mission copyWithCells(List<MissionCell> replacement) {
    if (replacement.length != 25) throw ArgumentError('Expected 25 cells.');
    return Mission._(
      number: number,
      title: title,
      briefing: briefing,
      timeLimitSeconds: timeLimitSeconds,
      startRow: startRow,
      endRow: endRow,
      cells: replacement,
      starIndices: starIndices,
      referenceRotations: referenceRotations,
      referencePath: referencePath,
      parMoves: parMoves,
      wrapEdges: wrapEdges,
      riskRouteRotations: riskRouteRotations,
    );
  }

  Mission solvedCopy() => withRotations(referenceRotations);

  Mission withRotations(List<int> rotations) {
    if (rotations.length != 25) throw ArgumentError('Expected 25 rotations.');
    return copyWithCells(
      List.generate(25, (index) => cells[index].withRotation(rotations[index])),
    );
  }

  /// Returns the actual connected route. Failed entry cells are identified by
  /// failureCell but are not appended to the valid trace. No clock is read.
  FlightResult launch({int attempt = 1, bool ignoreRisk = false}) {
    final steps = <FlightStep>[];
    final stars = <int>{};
    final visited = <int>{};
    var index = startRow * size;
    var incoming = _w;
    var portalArrival = false;
    FlightResult fail(FlightFailure reason, int cell) => FlightResult(
      success: false,
      steps: steps,
      collectedStars: stars,
      failure: reason,
      failureCell: cell,
    );
    while (true) {
      if (visited.contains(index)) return fail(FlightFailure.loop, index);
      final cell = cells[index];
      if (cell.kind == CellKind.block) {
        return fail(FlightFailure.blocked, index);
      }
      if ((cell.connections & incoming) == 0) {
        return fail(FlightFailure.brokenConnection, index);
      }
      if (_directed(cell.kind) && incoming != cell.input) {
        return fail(FlightFailure.wrongWay, index);
      }
      if (!ignoreRisk &&
          cell.kind == CellKind.asteroid &&
          _riskRoll(number, index, attempt) < cell.riskPercent) {
        return fail(FlightFailure.asteroidCollision, index);
      }
      visited.add(index);
      if (starIndices.contains(index)) stars.add(index);
      if (cell.kind == CellKind.wormhole && !portalArrival) {
        final pair = cell.portalPair;
        if (pair == null ||
            pair < 0 ||
            pair >= cells.length ||
            cells[pair].kind != CellKind.wormhole ||
            cells[pair].portalPair != index) {
          steps.add(FlightStep(cellIndex: index, incoming: incoming));
          return fail(FlightFailure.unpairedWormhole, index);
        }
        steps.add(
          FlightStep(
            cellIndex: index,
            incoming: incoming,
            nextCell: pair,
            transition: FlightTransition.wormhole,
          ),
        );
        index = pair;
        incoming = cells[pair].input;
        portalArrival = true;
        continue;
      }
      portalArrival = false;
      final available = cell.connections & ~incoming;
      final outgoing =
          cell.kind == CellKind.blackHole || cell.kind == CellKind.whiteHole
          ? _forkExit(incoming, available, cell.kind)
          : available;
      if (outgoing == 0 || (outgoing & (outgoing - 1)) != 0) {
        steps.add(FlightStep(cellIndex: index, incoming: incoming));
        return fail(FlightFailure.brokenConnection, index);
      }
      final jump = cell.kind == CellKind.slingshot;
      final distance = jump ? 2 : 1;
      var row =
          index ~/ size +
          (outgoing == _s ? distance : 0) -
          (outgoing == _n ? distance : 0);
      var column =
          index % size +
          (outgoing == _e ? distance : 0) -
          (outgoing == _w ? distance : 0);
      var transition = jump
          ? FlightTransition.slingshot
          : FlightTransition.adjacent;
      if (row < 0 || row >= size || column < 0 || column >= size) {
        if (!jump &&
            outgoing == _e &&
            index % size == size - 1 &&
            index ~/ size == endRow) {
          steps.add(
            FlightStep(
              cellIndex: index,
              incoming: incoming,
              outgoing: outgoing,
            ),
          );
          if (!stars.containsAll(starIndices)) {
            return fail(FlightFailure.missingStars, index);
          }
          return FlightResult(
            success: true,
            steps: steps,
            collectedStars: stars,
          );
        }
        if (wrapEdges && !jump) {
          row = row % size;
          column = column % size;
          transition = FlightTransition.wrap;
        } else {
          steps.add(
            FlightStep(
              cellIndex: index,
              incoming: incoming,
              outgoing: outgoing,
              transition: transition,
            ),
          );
          return fail(
            jump ? FlightFailure.slingshotMiss : FlightFailure.wrongExit,
            index,
          );
        }
      }
      final next = row * size + column;
      steps.add(
        FlightStep(
          cellIndex: index,
          incoming: incoming,
          outgoing: outgoing,
          nextCell: next,
          transition: transition,
        ),
      );
      index = next;
      incoming = _opposite(outgoing);
    }
  }
}

const _n = MissionDirection.north;
const _e = MissionDirection.east;
const _s = MissionDirection.south;
const _w = MissionDirection.west;

int _rotate(int mask, int turns) {
  final rotation = turns % 4;
  return ((mask << rotation) | (mask >> (4 - rotation))) & 15;
}

int _opposite(int direction) => _rotate(direction, 2);

bool _directed(CellKind kind) =>
    kind == CellKind.oneWay ||
    kind == CellKind.wormhole ||
    kind == CellKind.slingshot;

List<int> _forkPriorities(int incoming, CellKind kind) {
  final travel = _opposite(incoming);
  return kind == CellKind.blackHole
      ? [_rotate(travel, 1), travel, _rotate(travel, 3)]
      : [_rotate(travel, 3), travel, _rotate(travel, 1)];
}

int _forkExit(int incoming, int available, CellKind kind) => _forkPriorities(
  incoming,
  kind,
).firstWhere((direction) => (available & direction) != 0, orElse: () => 0);

int _forkMask(int incoming, int outgoing, CellKind kind) {
  final priority = _forkPriorities(incoming, kind);
  final position = priority.indexOf(outgoing);
  if (position < 0 || position == priority.length - 1) {
    throw StateError('Authored fork cannot prefer its reference exit.');
  }
  return incoming | outgoing | priority[position + 1];
}

int _direction(int from, int to, {required bool wrap}) {
  final rowDelta = to ~/ 5 - from ~/ 5;
  final columnDelta = to % 5 - from % 5;
  if (rowDelta == 0 && columnDelta != 0) {
    if (wrap && columnDelta.abs() == 4) return columnDelta > 0 ? _w : _e;
    return columnDelta > 0 ? _e : _w;
  }
  if (columnDelta == 0 && rowDelta != 0) {
    if (wrap && rowDelta.abs() == 4) return rowDelta > 0 ? _n : _s;
    return rowDelta > 0 ? _s : _n;
  }
  throw StateError('Authored route has an unsupported connection.');
}

int _riskRoll(int mission, int cell, int attempt) {
  var state =
      (0x6d2b79f5 ^ mission ^ (cell << 8) ^ ((attempt & 0xffff) << 16)) &
      0xffffffff;
  state = (state ^ ((state << 13) & 0xffffffff)) & 0xffffffff;
  state = (state ^ (state >>> 17)) & 0xffffffff;
  state = (state ^ ((state << 5) & 0xffffffff)) & 0xffffffff;
  return state % 100;
}

class _Spec {
  const _Spec(
    this.title,
    this.briefing,
    this.seconds,
    this.path,
    this.stars,
    this.turns, {
    this.kinds = const {},
    this.blocks = const {},
    this.portals = const {},
    this.risks = const {},
    this.wrap = false,
  });
  final String title, briefing;
  final int seconds;
  final List<int> path;
  final Set<int> stars, blocks;
  final Map<int, int> turns, portals, risks;
  final Map<int, CellKind> kinds;
  final bool wrap;
}

const _campaign = <_Spec>[
  _Spec(
    'Luma departure',
    'Send the survey probe to Luma: turn the launch relay once, then launch. Your first flight is untimed.',
    0,
    [10, 11, 12, 13, 14],
    {11, 12, 13},
    {10: 1},
  ),
  _Spec(
    'Ember supply run',
    'Deliver supplies to Ember Station. Connect both bends before the launch window closes.',
    90,
    [5, 6, 7, 12, 17, 18, 19],
    {6, 12, 18},
    {7: 1, 17: 1},
  ),
  _Spec(
    'Viridian signal sweep',
    'Recover the Viridian survey signals. Collect all three stars before docking.',
    90,
    [15, 16, 11, 6, 7, 8, 13, 18, 19],
    {11, 7, 18},
    {16: 1, 6: 1, 18: 1},
  ),
  _Spec(
    'Cinder rescue',
    'Reach the Cinder rescue beacon. Solid debris blocks the center; route around it.',
    95,
    [10, 11, 6, 7, 8, 13, 14],
    {11, 7, 13},
    {11: 1, 6: 1, 13: 1},
    blocks: {12, 17, 22},
  ),
  _Spec(
    'Halo archive',
    'Link the Halo archive array. Fixed relays cannot turn; connect the movable sectors around them.',
    95,
    [15, 16, 11, 6, 7, 8, 13, 18, 19],
    {11, 7, 18},
    {16: 1, 6: 1, 8: 1, 18: 1},
    kinds: {
      11: CellKind.lockedRelay,
      7: CellKind.lockedRelay,
      13: CellKind.lockedRelay,
    },
  ),
  _Spec(
    'Zephyr courier',
    'Deliver a probe to Zephyr. Follow each gate arrow from tail to head; a backward gate stops the flight.',
    100,
    [0, 1, 6, 11, 12, 13, 14],
    {6, 12, 13},
    {1: 2, 6: 1, 11: 1, 13: 1},
    kinds: {1: CellKind.oneWay, 11: CellKind.oneWay},
  ),
  _Spec(
    'Mira rendezvous',
    'Meet the Mira relay crew. Enter one wormhole and aim its paired exit toward the next sector.',
    105,
    [5, 6, 7, 17, 18, 19],
    {6, 17, 18},
    {6: 1, 7: 1, 17: 1},
    kinds: {7: CellKind.wormhole, 17: CellKind.wormhole},
    portals: {7: 17, 17: 7},
  ),
  _Spec(
    'Nox survey',
    'Survey the Nox beacons. Black-hole forks prefer an open clockwise turn.',
    110,
    [5, 6, 11, 16, 17, 18, 19],
    {11, 16, 18},
    {6: 1, 16: 1, 18: 1},
    kinds: {6: CellKind.blackHole},
  ),
  _Spec(
    'Pearl observatory',
    'Reach Pearl Observatory. White-hole forks prefer an open counterclockwise turn.',
    110,
    [15, 16, 11, 6, 7, 8, 9],
    {11, 6, 8},
    {16: 1, 6: 1, 8: 1},
    kinds: {16: CellKind.whiteHole},
  ),
  _Spec(
    'Vesta rescue',
    'Reach the Vesta rescue signal. Aim the slingshot over one blocked cell toward the landing relay.',
    115,
    [5, 6, 11, 13, 18, 19],
    {6, 13, 18},
    {6: 1, 11: 1, 13: 1, 18: 1},
    kinds: {11: CellKind.slingshot},
    blocks: {12},
  ),
  _Spec(
    'Aster supply line',
    'Deliver supplies to Aster. The center shortcut risks a 25% collision; the upper detour avoids asteroids.',
    120,
    [15, 16, 11, 6, 7, 8, 13, 18, 19],
    {16, 11, 18},
    {16: 1, 11: 1, 8: 1, 13: 1},
    kinds: {11: CellKind.blackHole, 13: CellKind.blackHole},
    risks: {12: 25},
  ),
  _Spec(
    'Echo boundary',
    'Trace the Echo boundary beacon. Fly out the top and return at the bottom of the same column.',
    125,
    [10, 11, 6, 1, 21, 22, 23, 18, 13, 14],
    {6, 22, 13},
    {11: 1, 1: 1, 21: 1, 18: 1},
    blocks: {16},
    wrap: true,
  ),
  _Spec(
    'Lyra archive run',
    'Recover the Lyra archive. Link one-way gates and a fixed relay through the paired wormhole.',
    130,
    [0, 1, 6, 7, 18, 13, 14],
    {1, 6, 13},
    {0: 1, 1: 1, 7: 1, 18: 1, 13: 1},
    kinds: {
      1: CellKind.oneWay,
      6: CellKind.lockedRelay,
      7: CellKind.wormhole,
      18: CellKind.wormhole,
      13: CellKind.oneWay,
    },
    portals: {7: 18, 18: 7},
    blocks: {2, 8, 12, 17, 22},
  ),
  _Spec(
    'Solace evacuation',
    'Guide the Solace evacuation probe. Slingshot over debris, follow the arrow, then wrap through the top gate.',
    140,
    [15, 16, 18, 13, 8, 3, 23, 24],
    {16, 8, 23},
    {16: 1, 18: 1, 8: 2, 3: 1, 23: 1},
    kinds: {
      16: CellKind.slingshot,
      13: CellKind.lockedRelay,
      8: CellKind.oneWay,
    },
    blocks: {17},
    wrap: true,
  ),
  _Spec(
    'Meridian crossing',
    'Reach Meridian via wormhole and forks. The upper detour is safe; the asteroid shortcut risks 40% collision.',
    150,
    [0, 1, 15, 16, 11, 6, 7, 8, 13, 18, 19],
    {16, 11, 18},
    {1: 1, 15: 1, 16: 1, 11: 1, 6: 1, 13: 1},
    kinds: {
      1: CellKind.wormhole,
      15: CellKind.wormhole,
      11: CellKind.blackHole,
      13: CellKind.blackHole,
      6: CellKind.oneWay,
      7: CellKind.lockedRelay,
    },
    portals: {1: 15, 15: 1},
    blocks: {2, 3, 4},
    risks: {12: 40},
  ),
];
