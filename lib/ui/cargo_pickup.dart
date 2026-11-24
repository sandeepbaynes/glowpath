import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../game/cargo.dart';
import 'cargo_art.dart';

/// One shared flight curve makes the pickup happen exactly as the courier
/// reaches its relay, including routes broken into separate wormhole runs.
class RouteFlightGeometry {
  RouteFlightGeometry._(this.metrics, this.centers);
  final List<ui.PathMetric> metrics;
  final Map<int, Offset> centers;
  late final double length = metrics.fold(0, (sum, m) => sum + m.length);
  final Map<int, double> _distances = {};
  static final Map<String, RouteFlightGeometry> _cache = {};
  static RouteFlightGeometry forBoard(
    List<int> cells,
    int gridSize,
    double tile,
    double rail,
    Size size,
  ) {
    final key = '${cells.join(',')}/$gridSize/$tile/$rail/$size';
    final cached = _cache[key];
    if (cached != null) return cached;
    final centers = <int, Offset>{
      for (final cell in cells)
        cell: Offset(
          rail + 1 + cell % gridSize * (tile + 3) + tile / 2,
          rail + 1 + cell ~/ gridSize * (tile + 3) + tile / 2,
        ),
    };
    final runs = <List<Offset>>[
      [Offset(7, centers[cells.first]!.dy)],
    ];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) {
        final a = cells[i - 1], b = cells[i];
        if ((a ~/ gridSize - b ~/ gridSize).abs() +
                (a % gridSize - b % gridSize).abs() >
            1) {
          runs.add(<Offset>[]);
        }
      }
      runs.last.add(centers[cells[i]]!);
    }
    runs.last.add(Offset(size.width - 7, centers[cells.last]!.dy));
    final path = Path();
    for (final run in runs) {
      path.moveTo(run.first.dx, run.first.dy);
      for (var i = 1; i < run.length - 1; i++) {
        final p = run[i], entering = p - run[i - 1], leaving = run[i + 1] - p;
        if (entering.distance == 0 || leaving.distance == 0) continue;
        final before = p - entering / entering.distance * tile * .18;
        final after = p + leaving / leaving.distance * tile * .18;
        path.lineTo(before.dx, before.dy);
        path.quadraticBezierTo(p.dx, p.dy, after.dx, after.dy);
      }
      path.lineTo(run.last.dx, run.last.dy);
    }
    final result = RouteFlightGeometry._(
      path.computeMetrics().toList(),
      centers,
    );
    // Only the handful of currently transitioning board sizes are retained.
    if (_cache.length >= 4) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }

  double distanceToCell(int cell) => _distances.putIfAbsent(cell, () {
    final center = centers[cell];
    if (center == null) return double.infinity;
    var closest = double.infinity, result = 0.0, before = 0.0;
    for (final metric in metrics) {
      for (var d = 0.0; d <= metric.length; d += 1.0) {
        final p = metric.getTangentForOffset(d)?.position;
        if (p == null) continue;
        final delta = (p - center).distanceSquared;
        if (delta < closest) {
          closest = delta;
          result = before + d;
        }
      }
      before += metric.length;
    }
    return result;
  });
}

double routeFlightEase(double t) =>
    t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;

double cargoPickupStart(double routeFraction) {
  final f = routeFraction.clamp(0.0, 1.0);
  final t = f < .5 ? math.pow(f / 4, 1 / 3) : 1 - math.pow((1 - f) / 4, 1 / 3);
  return (t * .56).toDouble();
}

class CargoPickupFrame {
  const CargoPickupFrame(this.position, this.radius, this.opacity, this.docked);
  final Offset position;
  final double radius, opacity;
  final bool docked;
  static CargoPickupFrame at(
    double progress,
    double start,
    Offset origin,
    Size size,
    double tile,
  ) {
    final u = ((progress - start) / (.96 - start)).clamp(0.0, 1.0);
    final hero = Offset(size.width * .5, size.height * .36);
    final hold = Offset(size.width - 31, size.height - 29);
    if (progress < start) return CargoPickupFrame(origin, tile * .16, 1, false);
    if (u < .43) {
      final t = u / .43;
      final travel = Curves.easeOutCubic.transform(t);
      final p = Offset.lerp(origin, hero, travel)!;
      final r = tile * (.16 + .48 * Curves.easeOutBack.transform(t));
      return CargoPickupFrame(p, r, 1, false);
    }
    final t = Curves.easeInCubic.transform(((u - .43) / .57).clamp(0.0, 1.0));
    final bend = Offset(size.width * .9, size.height * .14);
    final p =
        hero * ((1 - t) * (1 - t)) + bend * (2 * t * (1 - t)) + hold * (t * t);
    return CargoPickupFrame(
      p,
      tile * (.64 * (1 - t) + .07 * t),
      (1 - ((t - .88) / .12).clamp(0.0, 1.0)),
      u >= 1,
    );
  }
}

class RouteArrivalPainter extends CustomPainter {
  const RouteArrivalPainter({
    required this.cells,
    required this.tile,
    required this.progress,
    required this.rail,
    required this.gridSize,
    required this.trailColor,
    this.cargoKind,
    this.cargoCell,
  });
  final List<int> cells;
  final int gridSize;
  final Color trailColor;
  final double tile, progress, rail;
  final CargoKind? cargoKind;
  final int? cargoCell;
  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;
    final geometry = RouteFlightGeometry.forBoard(
      cells,
      gridSize,
      tile,
      rail,
      size,
    );
    if (geometry.metrics.isEmpty) return;
    final pickup =
        cargoKind != null && cargoCell != null && cells.contains(cargoCell);
    final end = pickup ? .56 : .82;
    final fraction = routeFlightEase((progress / end).clamp(0, 1));
    final distance = geometry.length * fraction;
    if (progress < end) {
      var preceding = 0.0;
      Offset? point;
      for (final metric in geometry.metrics) {
        for (var segment = 0; segment < 7; segment++) {
          final a = (distance - (7 - segment) * 7 - preceding).clamp(
            0.0,
            metric.length,
          );
          final b = (distance - (6 - segment) * 7 - preceding).clamp(
            0.0,
            metric.length,
          );
          if (b <= a) continue;
          canvas.drawPath(
            metric.extractPath(a, b),
            Paint()
              ..color = trailColor.withValues(alpha: .12 + segment * .12)
              ..strokeWidth = 1.1 + segment * .4
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round,
          );
        }
        if (distance >= preceding && distance <= preceding + metric.length) {
          point = metric.getTangentForOffset(distance - preceding)?.position;
        }
        preceding += metric.length;
      }
      if (point != null) {
        canvas.drawCircle(
          point,
          9,
          Paint()
            ..color = trailColor.withValues(alpha: .35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(point, 3.5, Paint()..color = Colors.white);
      }
    } else {
      final phase = ((progress - end) / .18).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(size.width - 7, geometry.centers[cells.last]!.dy),
        6 + Curves.easeOutCubic.transform(phase) * 26,
        Paint()
          ..color = trailColor.withValues(alpha: (1 - phase) * .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (!pickup) return;
    final start = cargoPickupStart(
      geometry.distanceToCell(cargoCell!) / geometry.length,
    );
    final frame = CargoPickupFrame.at(
      progress,
      start,
      geometry.centers[cargoCell]!,
      size,
      tile,
    );
    final hold = Offset(size.width - 31, size.height - 29);
    final glow = progress >= .9
        ? math.sin(((progress - .9) / .1).clamp(0.0, 1.0) * math.pi)
        : 0.0;
    drawCargoHold(canvas, hold, 34, glow: glow);
    if (progress > start && frame.opacity > 0) {
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + progress * 2;
        canvas.drawCircle(
          frame.position +
              Offset(math.cos(a), math.sin(a)) * frame.radius * 1.45,
          1.2,
          Paint()
            ..color = Color(cargoKind!.colorValue)
                .withValues(alpha: .5 * frame.opacity),
        );
      }
    }
    drawCargo(
      canvas,
      frame.position,
      frame.radius,
      cargoKind!,
      opacity: frame.opacity,
    );
  }

  @override
  bool shouldRepaint(RouteArrivalPainter old) =>
      progress != old.progress ||
      tile != old.tile ||
      rail != old.rail ||
      gridSize != old.gridSize ||
      trailColor != old.trailColor ||
      cargoKind != old.cargoKind ||
      cargoCell != old.cargoCell ||
      cells != old.cells;
}
