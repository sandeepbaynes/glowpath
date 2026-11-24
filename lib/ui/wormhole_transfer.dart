import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/puzzle.dart';
import 'design.dart';

/// A teleport actually taken by the source-connected route, in travel order.
class WormholeHop {
  const WormholeHop(this.entrance, this.exit, this.inlet, this.outlet);
  final int entrance, exit, inlet, outlet;
  String get identity => '$entrance>$exit';
}

List<WormholeHop> activeWormholeHops(Puzzle puzzle, PuzzleStatus status) {
  final route = status.route;
  if (route.isEmpty || route.first != puzzle.startRow * puzzle.size) return [];
  final result = <WormholeHop>[];
  for (var position = 0; position + 1 < route.length; position++) {
    final entrance = route[position], exit = route[position + 1];
    if (entrance < 0 ||
        entrance >= puzzle.tiles.length ||
        exit < 0 ||
        exit >= puzzle.tiles.length) {
      continue;
    }
    final entryTile = puzzle.visualTileAt(entrance);
    final exitTile = puzzle.visualTileAt(exit);
    if (entryTile.kind != TileKind.wormhole ||
        entryTile.portalPeer != exit ||
        exitTile.kind != TileKind.wormhole ||
        exitTile.portalPeer != entrance ||
        !exitTile.isOneWay) {
      continue;
    }
    final inlet = entryTile.isOneWay
        ? entryTile.entryDirection
        : position == 0
        ? west
        : _inletFrom(route[position - 1], entrance, puzzle.size);
    final outlet = puzzle.outgoingAt(exit, exitTile.entryDirection);
    if (inlet == 0 ||
        outlet == null ||
        !status.litCells.contains(entrance) ||
        !status.litCells.contains(exit)) {
      continue;
    }
    result.add(WormholeHop(entrance, exit, inlet, outlet));
    // The peer is a portal arrival, not another teleport. It can be followed
    // by an adjacent portal tile without falsely announcing a reverse hop.
    position++;
  }
  return result;
}

int _inletFrom(int previous, int cell, int size) {
  if (previous == cell - size) return north;
  if (previous == cell + size) return south;
  if (previous ~/ size == cell ~/ size) {
    if (previous == cell - 1) return west;
    if (previous == cell + 1) return east;
  }
  return 0;
}

/// One attention cue per connection, never a background animation loop.
/// Removing an active traversal removes its light immediately.
class WormholeTransfer extends StatefulWidget {
  const WormholeTransfer({
    super.key,
    required this.hops,
    required this.tileExtent,
    required this.rail,
    required this.gridSize,
    required this.reduceMotion,
    required this.highContrast,
  });
  static const duration = Duration(milliseconds: 900);
  final List<WormholeHop> hops;
  final double tileExtent, rail;
  final int gridSize;
  final bool reduceMotion, highContrast;

  @override
  State<WormholeTransfer> createState() => _WormholeTransferState();
}

class _WormholeTransferState extends State<WormholeTransfer>
    with TickerProviderStateMixin {
  final _active = <String>{};
  final _flights = <String, AnimationController>{};
  bool _still = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WormholeTransfer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    _still =
        widget.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final active = widget.hops.map((hop) => hop.identity).toSet();
    for (final key in _flights.keys.toList()) {
      if (!active.contains(key) || _still) {
        _flights.remove(key)!.dispose();
      }
    }
    if (!_still) {
      for (final key in active.difference(_active)) {
        _flights[key] = AnimationController(
          vsync: this,
          duration: WormholeTransfer.duration,
        )..forward();
      }
    }
    _active
      ..clear()
      ..addAll(active);
  }

  @override
  void dispose() {
    for (final controller in _flights.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: CustomPaint(
        key: const ValueKey('wormhole-transfer'),
        painter: WormholeTransferPainter(
          hops: widget.hops,
          flights: Map.unmodifiable(_flights),
          tileExtent: widget.tileExtent,
          rail: widget.rail,
          gridSize: widget.gridSize,
          highContrast: widget.highContrast,
        ),
      ),
    ),
  );
}

class WormholeTransferPainter extends CustomPainter {
  WormholeTransferPainter({
    required this.hops,
    required this.flights,
    required this.tileExtent,
    required this.rail,
    required this.gridSize,
    required this.highContrast,
  }) : super(repaint: Listenable.merge(flights.values.toList()));

  final List<WormholeHop> hops;
  final Map<String, Animation<double>> flights;
  final double tileExtent, rail;
  final int gridSize;
  final bool highContrast;

  Offset _center(int cell) => Offset(
    rail + (cell % gridSize) * (tileExtent + 3) + tileExtent / 2,
    rail + (cell ~/ gridSize) * (tileExtent + 3) + tileExtent / 2,
  );

  Offset lightPosition(WormholeHop hop, double progress, Size size) {
    final start = _center(hop.entrance), end = _center(hop.exit);
    final direction = end - start;
    if (direction.distance == 0) return start;
    var normal = Offset(-direction.dy, direction.dx) / direction.distance;
    final towardCenter = size.center(Offset.zero) - (start + end) / 2;
    if (normal.dx * towardCenter.dx + normal.dy * towardCenter.dy < 0) {
      normal = -normal;
    }
    final t = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    final lift = math.min(tileExtent * .65, direction.distance * .16);
    return Offset.lerp(start, end, t)! + normal * math.sin(t * math.pi) * lift;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final hop in hops) {
      final animation = flights[hop.identity];
      if (animation == null || animation.value >= 1) continue;
      final t = animation.value;
      final travel = ((t - .14) / .64).clamp(0.0, 1.0);
      final arrival = ((t - .78) / .22).clamp(0.0, 1.0);
      final radius = (tileExtent * .065).clamp(3.5, 7.0);
      final point = lightPosition(hop, travel, size);
      if (t >= .14 && t <= .78) {
        for (var sample = 4; sample > 0; sample--) {
          final behind = (travel - sample * .032).clamp(0.0, 1.0);
          canvas.drawCircle(
            lightPosition(hop, behind, size),
            radius * (1 - sample * .15),
            Paint()
              ..color = Palette.rust.withValues(alpha: .18 - sample * .025),
          );
        }
      }
      final strength = t < .14 ? t / .14 : 1 - arrival;
      if (!highContrast) {
        canvas.drawCircle(
          point,
          radius * 3,
          Paint()
            ..color = Palette.rust.withValues(alpha: .28 * strength)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = Palette.rust.withValues(alpha: strength),
      );
      canvas.drawCircle(
        point,
        radius * .42,
        Paint()..color = Palette.white.withValues(alpha: strength),
      );
      if (arrival > 0) {
        canvas.drawCircle(
          _center(hop.exit),
          tileExtent * (.16 + arrival * .12),
          Paint()
            ..color = Palette.rust.withValues(alpha: (1 - arrival) * .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(WormholeTransferPainter old) =>
      hops != old.hops ||
      flights != old.flights ||
      tileExtent != old.tileExtent ||
      rail != old.rail ||
      gridSize != old.gridSize ||
      highContrast != old.highContrast;
}
