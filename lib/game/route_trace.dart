part of 'puzzle.dart';

enum TraceRejection {
  invalidCell,
  disconnected,
  incompatibleLane,
  repeatedLane,
  armedWeapon,
  prematureCompletion,
}

/// An immutable proposal. Rejected proposals always return the original board
/// and an empty action list, so callers cannot accidentally commit half a drag.
class TracePlan {
  TracePlan._(
    this.puzzle,
    List<int> actions,
    Set<int> changedCells, [
    this.rejection,
  ]) : actions = List.unmodifiable(actions),
       changedCells = Set.unmodifiable(changedCells);
  final Puzzle puzzle;
  final List<int> actions;
  final Set<int> changedCells;
  final TraceRejection? rejection;
  bool get accepted => rejection == null;
  String get message => switch (rejection) {
    TraceRejection.invalidCell => 'Trace inside the board.',
    TraceRejection.disconnected =>
      'Connect adjacent tiles or paired wormholes.',
    TraceRejection.incompatibleLane =>
      'This lane cannot turn that way. Check locks, arrows and linked tiles.',
    TraceRejection.repeatedLane =>
      'Use a different crossing lane, or backtrack to erase.',
    TraceRejection.armedWeapon =>
      'Visit the defense switch or charge a shield first.',
    TraceRejection.prematureCompletion =>
      'The rocket already reaches its destination before this extra turn.',
    null => 'Route aligned.',
  };
}

class _TraceVisit {
  _TraceVisit(this.cell);
  final int cell;
  int? incoming, outgoing;
  bool portalArrival = false;
}

class _TraceConstraint {
  _TraceConstraint(this.variables, this.tuples);
  final List<int> variables;
  final List<List<int>> tuples;
}

TracePlan _planTrace(
  Puzzle original,
  List<int> cells, {
  int? entryPort,
  int? exitPort,
}) {
  TracePlan reject(TraceRejection reason) =>
      TracePlan._(original, [], {}, reason);
  final count = original.tiles.length;
  bool portValid(int? value) =>
      value == null || [north, east, south, west].contains(value);
  if (cells.isEmpty ||
      cells.length > count * 2 ||
      cells.any((cell) => cell < 0 || cell >= count) ||
      !portValid(entryPort) ||
      !portValid(exitPort)) {
    return reject(TraceRejection.invalidCell);
  }
  // A pointer-down alone never turns a tile or competes with tap-to-rotate.
  if (cells.length == 1) return TracePlan._(original, [], {});
  final visits = cells.map(_TraceVisit.new).toList();
  visits.first.incoming =
      entryPort ??
      (cells.first == original.startRow * original.size ? west : null);
  visits.last.outgoing =
      exitPort ??
      (cells.last == original.endRow * original.size + original.size - 1
          ? east
          : null);
  // A lifted finger can resume at a paired portal exit. It is then tracing
  // the outgoing lane after teleportation, not entering the wormhole again.
  final firstTile = original.tiles[cells.first];
  final firstPeer = firstTile.portalPeer;
  if (visits.first.incoming == null &&
      firstTile.kind == TileKind.wormhole &&
      firstTile.isOneWay &&
      firstPeer != null &&
      firstPeer >= 0 &&
      firstPeer < count &&
      cells[1] != firstPeer &&
      original.tiles[firstPeer].kind == TileKind.wormhole &&
      original.tiles[firstPeer].portalPeer == cells.first) {
    visits.first.portalArrival = true;
  }
  for (var i = 0; i + 1 < visits.length; i++) {
    final a = visits[i], b = visits[i + 1];
    final tile = original.tiles[a.cell];
    if (tile.kind == TileKind.wormhole && !a.portalArrival) {
      final peer = original.tiles[b.cell];
      if (tile.portalPeer != b.cell ||
          peer.kind != TileKind.wormhole ||
          peer.portalPeer != a.cell ||
          !peer.isOneWay) {
        return reject(TraceRejection.disconnected);
      }
      b.portalArrival = true;
    } else {
      final ar = a.cell ~/ original.size, ac = a.cell % original.size;
      final br = b.cell ~/ original.size, bc = b.cell % original.size;
      if ((ar - br).abs() + (ac - bc).abs() != 1) {
        return reject(TraceRejection.disconnected);
      }
      a.outgoing = br < ar
          ? north
          : br > ar
          ? south
          : bc < ac
          ? west
          : east;
      b.incoming = _opposite(a.outgoing!);
    }
  }
  final byCell = <int, List<_TraceVisit>>{};
  for (final visit in visits) {
    byCell.putIfAbsent(visit.cell, () => []).add(visit);
  }
  for (final entry in byCell.entries) {
    if (entry.value.length > 1 &&
        ![
          TileKind.bridge,
          TileKind.crossway,
        ].contains(original.tiles[entry.key].kind)) {
      return reject(TraceRejection.repeatedLane);
    }
  }
  // Hazards are checked only when the player has explicitly traced from launch.
  // A local repair elsewhere has no claim about the incoming shield state.
  if (cells.first == original.startRow * original.size &&
      visits.first.incoming == west) {
    final disabled = <int>{};
    var shield = false;
    for (final visit in visits) {
      final tile = original.tiles[visit.cell];
      if (tile.kind == TileKind.weapon && !disabled.contains(tile.circuit)) {
        if (!shield) return reject(TraceRejection.armedWeapon);
        shield = false;
      }
      if (tile.kind == TileKind.shield) shield = true;
      if (tile.kind == TileKind.disarm && !disabled.add(tile.circuit)) {
        disabled.remove(tile.circuit);
      }
    }
  }

  // One variable is one legal tap target (a whole twin/triplet group). Each
  // traced tile adds an exact lane constraint; gravity-linked crossings add a
  // second dependency on the source well. Domains have at most four values.
  final representatives = <int>[];
  final variableForKey = <String, int>{};
  String keyFor(int cell) => original.tiles[cell].couplingGroup == 0
      ? 'cell:$cell'
      : 'group:${original.tiles[cell].couplingGroup}';
  for (final cell in cells) {
    if (original.tiles[cell].isLocked) continue;
    final key = keyFor(cell);
    if (!variableForKey.containsKey(key)) {
      variableForKey[key] = representatives.length;
      representatives.add(cell);
    }
  }
  int? variableFor(int cell) =>
      original.tiles[cell].isLocked ? null : variableForKey[keyFor(cell)];
  Puzzle withValues(List<int> values) {
    final tiles = List<Tile>.generate(count, (cell) {
      final variable = variableFor(cell);
      return variable == null
          ? original.tiles[cell]
          : original.tiles[cell].withRotation(
              original.tiles[cell].rotation + values[variable],
            );
    });
    return original.copyWithTiles(tiles);
  }

  bool matches(Puzzle board, List<_TraceVisit> laneVisits) {
    bool choose(int index, int occupied) {
      if (index == laneVisits.length) return true;
      final visit = laneVisits[index];
      final tile = board.visualTileAt(visit.cell);
      final incoming = visit.portalArrival
          ? tile.entryDirection
          : visit.incoming;
      if (visit.portalArrival && !tile.isOneWay) return false;
      for (final inlet
          in incoming == null ? [north, east, south, west] : [incoming]) {
        if (tile.connections & inlet == 0 ||
            tile.isOneWay && tile.entryDirection != inlet) {
          continue;
        }
        final outlet = board.outgoingAt(visit.cell, inlet);
        if (outlet == null ||
            visit.outgoing != null && outlet != visit.outgoing) {
          continue;
        }
        final lane = inlet | outlet;
        if (lane & occupied == 0 && choose(index + 1, occupied | lane)) {
          return true;
        }
      }
      return false;
    }

    return choose(0, 0);
  }

  final constraints = <_TraceConstraint>[];
  for (final entry in byCell.entries) {
    final cell = entry.key, tile = original.tiles[entry.key];
    final dependencies = <int>{};
    final own = variableFor(cell);
    if (own != null) dependencies.add(own);
    final peer = tile.gravityPeer;
    if (peer != null &&
        peer >= 0 &&
        peer < count &&
        [TileKind.bridge, TileKind.crossway].contains(tile.kind)) {
      final gravity = variableFor(peer);
      if (gravity != null) dependencies.add(gravity);
    }
    final variables = dependencies.toList()..sort();
    final tuples = <List<int>>[];
    final values = List<int>.filled(representatives.length, 0);
    void enumerate(int index) {
      if (index == variables.length) {
        if (matches(withValues(values), entry.value)) {
          tuples.add([for (final variable in variables) values[variable]]);
        }
        return;
      }
      for (var turn = 0; turn < 4; turn++) {
        values[variables[index]] = turn;
        enumerate(index + 1);
      }
    }

    enumerate(0);
    if (tuples.isEmpty) return reject(TraceRejection.incompatibleLane);
    constraints.add(_TraceConstraint(variables, tuples));
  }
  List<Set<int>>? propagate(List<Set<int>> domains) {
    var changed = true;
    while (changed) {
      changed = false;
      for (final constraint in constraints) {
        final compatible = constraint.tuples.where((tuple) {
          for (var i = 0; i < tuple.length; i++) {
            if (!domains[constraint.variables[i]].contains(tuple[i])) {
              return false;
            }
          }
          return true;
        }).toList();
        if (compatible.isEmpty) return null;
        for (var i = 0; i < constraint.variables.length; i++) {
          final variable = constraint.variables[i];
          final allowed = compatible.map((tuple) => tuple[i]).toSet();
          final keep = domains[variable].intersection(allowed);
          if (keep.isEmpty) return null;
          if (keep.length != domains[variable].length) {
            domains[variable] = keep;
            changed = true;
          }
        }
      }
    }
    return domains;
  }

  var searched = 0;
  List<int>? solve(List<Set<int>> candidates) {
    if (++searched > 4096) return null;
    final domains = propagate(candidates);
    if (domains == null) return null;
    var choice = -1;
    for (var i = 0; i < domains.length; i++) {
      if (domains[i].length > 1 &&
          (choice < 0 || domains[i].length < domains[choice].length)) {
        choice = i;
      }
    }
    if (choice < 0) return domains.map((domain) => domain.single).toList();
    final options = domains[choice].toList()..sort();
    for (final option in options) {
      final branch = domains.map((domain) => domain.toSet()).toList();
      branch[choice] = {option};
      final result = solve(branch);
      if (result != null) return result;
    }
    return null;
  }

  final values = solve([
    for (final _ in representatives) {0, 1, 2, 3},
  ]);
  if (values == null) return reject(TraceRejection.incompatibleLane);
  final remaining = <int>[
    for (var variable = 0; variable < values.length; variable++)
      for (var turn = 0; turn < values[variable]; turn++)
        representatives[variable],
  ];
  // A replay may never rotate an already solved board. Reorder independent
  // actions if needed; reject instead of recording an unverifiable sequence.
  var board = original;
  final actions = <int>[];
  while (remaining.isNotEmpty) {
    if (board.evaluate().solved) {
      return reject(TraceRejection.prematureCompletion);
    }
    var selected = -1;
    for (var i = 0; i < remaining.length; i++) {
      if (remaining.length == 1 ||
          !board.rotateAt(remaining[i]).evaluate().solved) {
        selected = i;
        break;
      }
    }
    if (selected < 0) return reject(TraceRejection.prematureCompletion);
    final cell = remaining.removeAt(selected);
    board = board.rotateAt(cell);
    actions.add(cell);
  }
  return TracePlan._(board, actions, {
    for (var cell = 0; cell < count; cell++)
      if (board.tiles[cell].rotation != original.tiles[cell].rotation) cell,
  });
}
