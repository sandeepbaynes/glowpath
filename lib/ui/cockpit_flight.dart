import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/mission.dart';
import 'design.dart';

/// A route-derived, procedural 3D flight view, rendered through perspective
/// projection onto Flutter Canvas. This is geometry, not a movie or Blender
/// asset. Grid positions supply lateral/vertical bends; successive flight steps
/// add forward depth. The caller owns the finite 0–1 flight animation.
class CockpitFlight extends StatelessWidget {
  const CockpitFlight({
    super.key,
    required this.mission,
    required this.result,
    required this.progress,
    this.reducedMotion = false,
  });

  final Mission mission;
  final FlightResult result;
  final double progress;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final route = _FlightRoute(mission, result);
    final p = progress.clamp(0.0, 1.0);
    final cursor = (p / .8).clamp(0.0, 1.0) * route.length;
    final count = route.stars.where((star) => star.position <= cursor).length;
    final still =
        reducedMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final status = p >= 1
        ? result.success
              ? 'Docked'
              : 'Rocket lost in space'
        : p >= .8
        ? result.success
              ? 'Docking'
              : 'Off course'
        : 'Following the planned route';
    return Semantics(
      label:
          'Cockpit. $status. $count of ${mission.starIndices.length} stars collected.',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.hasBoundedWidth ? constraints.maxWidth : 360,
              height: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 320,
              child: ClipRect(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _CockpitPainter(
                      route: route,
                      progress: p,
                      reducedMotion: still,
                      textScale: MediaQuery.textScalerOf(context)
                          .scale(1)
                          .clamp(1.0, 1.5),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _P3 {
  const _P3(this.x, this.y, this.z);
  final double x, y, z;
  _P3 operator +(_P3 other) => _P3(x + other.x, y + other.y, z + other.z);
  _P3 operator -(_P3 other) => _P3(x - other.x, y - other.y, z - other.z);
  _P3 operator *(double scale) => _P3(x * scale, y * scale, z * scale);
  double dot(_P3 other) => x * other.x + y * other.y + z * other.z;
  _P3 cross(_P3 other) => _P3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );
  double get magnitude => math.sqrt(dot(this));
  _P3 get unit =>
      magnitude < .0001 ? const _P3(0, 0, 1) : this * (1 / magnitude);
}

class _StarPass {
  const _StarPass(this.position, this.cell);
  final double position;
  final int cell;
}

class _FlightRoute {
  _FlightRoute(this.mission, this.result) {
    points.add(_P3(-9.3, (2 - mission.startRow) * 3.2, 0));
    final seen = <int>{};
    for (var i = 0; i < result.steps.length; i++) {
      final step = result.steps[i];
      points.add(
        _P3(
          (step.cellIndex % 5 - 2) * 3.2,
          (2 - step.cellIndex ~/ 5) * 3.2,
          (i + 1) * 5.8,
        ),
      );
      if (mission.starIndices.contains(step.cellIndex) &&
          result.collectedStars.contains(step.cellIndex) &&
          seen.add(step.cellIndex)) {
        stars.add(_StarPass((i + 1).toDouble(), step.cellIndex));
      }
      final transition = step.transition.name.toLowerCase();
      if (i + 1 < result.steps.length &&
          (transition.contains('worm') ||
              transition.contains('wrap') ||
              transition.contains('teleport'))) {
        jumpSegments[i + 1] = transition;
      }
    }
    if (result.success) {
      points.add(_P3(9.3, (2 - mission.endRow) * 3.2, points.last.z + 5.8));
    } else {
      final out = result.steps.isEmpty
          ? 2
          : result.steps.last.outgoing ?? _opposite(result.steps.last.incoming);
      final direction = _direction(out);
      points.add(points.last + _P3(direction.dx * 4, -direction.dy * 4, 6));
    }
  }

  final Mission mission;
  final FlightResult result;
  final points = <_P3>[];
  final stars = <_StarPass>[];
  final jumpSegments = <int, String>{};
  double get length => (points.length - 1).toDouble();

  _P3 sample(double position) {
    final bounded = position.clamp(0.0, length);
    final index = math.min(bounded.floor(), points.length - 2);
    final t = bounded - index;
    if (jumpSegments.containsKey(index)) {
      return t < .5 ? points[index] : points[index + 1];
    }
    final a = index > 0 && !jumpSegments.containsKey(index - 1)
        ? points[index - 1]
        : points[index];
    final b = points[index], c = points[index + 1];
    final d = index + 2 < points.length && !jumpSegments.containsKey(index + 1)
        ? points[index + 2]
        : c;
    // Catmull–Rom interpolation eases into each real grid turn.
    return (b * 2 +
            (c - a) * t +
            (a * 2 - b * 5 + c * 4 - d) * (t * t) +
            (a * -1 + b * 3 - c * 3 + d) * (t * t * t)) *
        .5;
  }

  _P3 tangent(double position) {
    if (jumpSegments.containsKey(position.floor())) {
      return const _P3(0, 0, 1);
    }
    return (sample(position + .035) - sample(position - .035)).unit;
  }

  bool crossesJump(double a, double b) {
    for (final segment in jumpSegments.keys) {
      if (a < segment + 1 && b > segment) return true;
    }
    return false;
  }
}

Offset _direction(int mask) => switch (mask) {
  1 => const Offset(0, -1),
  2 => const Offset(1, 0),
  4 => const Offset(0, 1),
  8 => const Offset(-1, 0),
  _ => const Offset(1, 0),
};

int _opposite(int mask) => switch (mask) {
  1 => 4,
  2 => 8,
  4 => 1,
  8 => 2,
  _ => 2,
};

class _Camera {
  _Camera(this.position, this.forward, this.size, this.bank)
    : right = const _P3(0, 1, 0).cross(forward).unit {
    up = forward.cross(right).unit;
  }
  final _P3 position, forward, right;
  late final _P3 up;
  final Size size;
  final double bank;
  double get focalLength => math.min(size.width, size.height) * .92;

  Offset? project(_P3 point) {
    final relative = point - position;
    final depth = relative.dot(forward);
    if (depth <= .12) return null;
    final x = relative.dot(right), y = relative.dot(up);
    final rolledX = x * math.cos(bank) - y * math.sin(bank);
    final rolledY = x * math.sin(bank) + y * math.cos(bank);
    return Offset(
      size.width / 2 + rolledX * focalLength / depth,
      size.height * .43 - rolledY * focalLength / depth,
    );
  }
}

class _TunnelRing {
  const _TunnelRing(this.position, this.vertices, this.depth);
  final double position, depth;
  final List<Offset?> vertices;
}

class _CockpitPainter extends CustomPainter {
  const _CockpitPainter({
    required this.route,
    required this.progress,
    required this.reducedMotion,
    required this.textScale,
  });
  final _FlightRoute route;
  final double progress, textScale;
  final bool reducedMotion;

  double get cursor => (progress / .8).clamp(0.0, 1.0) * route.length;
  int get collected =>
      route.stars.where((star) => star.position <= cursor).length;
  double get ending => ((progress - .8) / .2).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF040914),
    );
    _starfield(canvas, size, reducedMotion ? 0 : cursor * .2);
    if (reducedMotion) {
      _overview(canvas, size);
      _frame(canvas, size, opacity: 1);
      return;
    }
    final exterior = !route.result.success && ending > .08;
    final fade = exterior
        ? _smooth(((ending - .08) / .32).clamp(0.0, 1.0))
        : 0.0;
    if (fade < 1) {
      final direction = route.tangent(math.min(cursor, route.length - .03));
      final turn =
          route.tangent(cursor + .22).x - route.tangent(cursor - .22).x;
      final camera = _Camera(
        route.sample(cursor),
        direction,
        size,
        (turn * .65).clamp(-.2, .2),
      );
      _tunnel(canvas, size, camera);
      _stars(canvas, size, camera);
      _jump(canvas, size);
      if (route.result.success && ending > 0) _dock(canvas, size, ending);
      _frame(canvas, size, opacity: 1 - fade);
    }
    if (exterior) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF040914).withValues(alpha: fade),
      );
      _starfield(canvas, size, cursor * .2, opacity: fade);
      _exterior(canvas, size, ending, fade);
    }
  }

  void _tunnel(Canvas canvas, Size size, _Camera camera) {
    final rings = <_TunnelRing>[];
    // The failed trace ends at its last connected relay. The extra camera
    // segment continues into open space; it must not invent another tunnel.
    final tunnelEnd = route.result.success
        ? route.length
        : route.result.steps.length.toDouble();
    for (
      var t = cursor + .11;
      t <= math.min(tunnelEnd, cursor + 5.8);
      t += .14
    ) {
      if (route.jumpSegments.containsKey(t.floor())) continue;
      final center = route.sample(t);
      final direction = route.tangent(t);
      final right = const _P3(0, 1, 0).cross(direction).unit;
      final up = direction.cross(right).unit;
      final vertices = <Offset?>[];
      for (var side = 0; side < 12; side++) {
        final angle = side / 12 * math.pi * 2 + math.pi / 12;
        vertices.add(
          camera.project(
            center +
                right * (math.cos(angle) * 2.3) +
                up * (math.sin(angle) * 2.3),
          ),
        );
      }
      rings.add(
        _TunnelRing(
          t,
          vertices,
          (center - camera.position).dot(camera.forward),
        ),
      );
    }
    for (var ringIndex = rings.length - 1; ringIndex > 0; ringIndex--) {
      final far = rings[ringIndex], near = rings[ringIndex - 1];
      if (route.crossesJump(near.position, far.position)) continue;
      final fog = (far.depth / 32).clamp(0.0, 1.0);
      for (var side = 0; side < 12; side++) {
        final next = (side + 1) % 12;
        final a = near.vertices[side], b = far.vertices[side];
        final c = far.vertices[next], d = near.vertices[next];
        if (a == null || b == null || c == null || d == null) continue;
        final panel = Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..lineTo(d.dx, d.dy)
          ..close();
        final base = side.isEven
            ? const Color(0xFF193148)
            : const Color(0xFF102337);
        canvas.drawPath(
          panel,
          Paint()..color = Color.lerp(base, const Color(0xFF07101E), fog * .8)!,
        );
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = (side % 3 == 0 ? Palette.rust : Palette.line).withValues(
              alpha: (1 - fog * .85) * (side % 3 == 0 ? .6 : .35),
            )
            ..strokeWidth = side % 3 == 0 ? 1.5 : .7,
        );
        if (ringIndex % 3 == 0) {
          canvas.drawLine(
            a,
            d,
            Paint()
              ..color = Palette.pipe.withValues(alpha: (1 - fog) * .35)
              ..strokeWidth = 1.2,
          );
        }
      }
    }
  }

  void _stars(Canvas canvas, Size size, _Camera camera) {
    for (final star in route.stars) {
      final delta = star.position - cursor;
      if (delta < -.12 || delta > 5.5) continue;
      final world = route.sample(star.position);
      final projected = camera.project(world);
      final depth = (world - camera.position).dot(camera.forward);
      if (projected != null && depth > .15) {
        final radius = (camera.focalLength * .29 / depth).clamp(3.0, 42.0);
        canvas.drawCircle(
          projected,
          radius * 1.9,
          Paint()..color = Palette.light.withValues(alpha: .08),
        );
        _star(canvas, projected, radius, Palette.light);
        canvas.drawCircle(
          projected,
          radius * .17,
          Paint()..color = Palette.white,
        );
      }
      if (delta.abs() < .16) {
        final strength = 1 - delta.abs() / .16;
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = Palette.light.withValues(alpha: strength * .075),
        );
        final center = Offset(size.width / 2, size.height * .43);
        for (var i = 0; i < 8; i++) {
          final angle = i / 8 * math.pi * 2;
          final radial = Offset(math.cos(angle), math.sin(angle));
          canvas.drawLine(
            center + radial * (26 + (1 - strength) * 32),
            center + radial * (34 + (1 - strength) * 40),
            Paint()
              ..color = Palette.light.withValues(alpha: strength * .8)
              ..strokeWidth = 1.3,
          );
        }
      }
    }
  }

  void _jump(Canvas canvas, Size size) {
    final segment = cursor.floor();
    final kind = route.jumpSegments[segment];
    if (kind == null) return;
    final local = cursor - segment;
    final strength = 1 - (local - .5).abs() * 2;
    final color = kind.contains('wrap')
        ? Palette.rust
        : const Color(0xFFB9A1FF);
    final center = Offset(size.width / 2, size.height * .43);
    final radius = size.shortestSide * (.18 + local * .65);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        center,
        radius + i * 9,
        Paint()
          ..color = color.withValues(alpha: strength * (.5 - i * .1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 3 : 1,
      );
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: strength * .14),
    );
    _text(
      canvas,
      kind.contains('wrap') ? 'EDGE TRANSIT' : 'WORMHOLE TRANSIT',
      Offset(size.width / 2, size.height * .19),
      11 * textScale,
      color,
    );
  }

  void _dock(Canvas canvas, Size size, double phase) {
    final center = Offset(size.width / 2, size.height * .43);
    final radius = size.shortestSide * (.12 + _smooth(phase) * .19);
    canvas.drawCircle(center, radius * 1.14, Paint()..color = Palette.board);
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Palette.rust.withValues(alpha: .09),
    );
    for (var i = 0; i < 12; i++) {
      final angle = i / 12 * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle + .06,
        math.pi / 6 - .12,
        false,
        Paint()
          ..color = i < phase * 12 ? Palette.rust : Palette.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }
    canvas.drawCircle(
      center,
      radius * .73,
      Paint()
        ..color = Palette.light.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    for (var i = 0; i < 3; i++) {
      _star(
        canvas,
        center + Offset((i - 1) * radius * .35, 0),
        radius * .1,
        i < collected ? Palette.light : Palette.line,
      );
    }
    _text(
      canvas,
      phase > .96 ? 'DOCKED' : 'DOCKING',
      center + Offset(0, radius * .43),
      11 * textScale,
      Palette.white,
    );
  }

  void _overview(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * .15,
      size.height * .13,
      size.width * .7,
      size.height * .52,
    );
    final side = math.min(rect.width / 5, rect.height / 5);
    final origin = Offset(
      size.width / 2 - side * 2,
      size.height * .39 - side * 2,
    );
    Offset cell(int index) =>
        origin + Offset(index % 5 * side, index ~/ 5 * side);
    for (var i = 0; i < 25; i++) {
      canvas.drawCircle(cell(i), 1.7, Paint()..color = Palette.line);
    }
    for (var i = 0; i < route.result.steps.length; i++) {
      final step = route.result.steps[i];
      final here = cell(step.cellIndex);
      final reached = i + 1 <= cursor;
      if (i + 1 < route.result.steps.length) {
        final next = cell(route.result.steps[i + 1].cellIndex);
        final jumping = route.jumpSegments.containsKey(i + 1);
        canvas.drawLine(
          here,
          next,
          Paint()
            ..color = (jumping ? const Color(0xFFB9A1FF) : Palette.rust)
                .withValues(alpha: reached ? .7 : .15)
            ..strokeWidth = jumping ? 1 : 2,
        );
        if (jumping) {
          canvas.drawCircle(
            here,
            5,
            Paint()
              ..color = const Color(0xFFB9A1FF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
      if (route.mission.starIndices.contains(step.cellIndex)) {
        _star(canvas, here, 5, reached ? Palette.light : Palette.secondary);
      } else {
        canvas.drawCircle(
          here,
          reached ? 3.4 : 2,
          Paint()..color = reached ? Palette.rust : Palette.line,
        );
      }
    }
    _text(
      canvas,
      ending > 0
          ? route.result.success
                ? progress >= 1
                      ? 'DOCKED'
                      : 'DOCKING'
                : 'OFF COURSE'
          : 'FLIGHT PLAN',
      Offset(size.width / 2, size.height * .1),
      12 * textScale,
      ending > 0 && !route.result.success
          ? const Color(0xFFFF987D)
          : Palette.white,
    );
  }

  void _frame(Canvas canvas, Size size, {required double opacity}) {
    if (opacity <= 0) return;
    Color shade(Color color, [double alpha = 1]) =>
        color.withValues(alpha: alpha * opacity);
    final w = size.width, h = size.height;
    final left = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * .52)
      ..lineTo(w * .075, h * .62)
      ..lineTo(w * .16, h * .84)
      ..lineTo(w * .38, h * .88)
      ..lineTo(w * .42, h)
      ..close();
    final right = Path()
      ..moveTo(w, h)
      ..lineTo(w, h * .52)
      ..lineTo(w * .925, h * .62)
      ..lineTo(w * .84, h * .84)
      ..lineTo(w * .62, h * .88)
      ..lineTo(w * .58, h)
      ..close();
    for (final hull in [left, right]) {
      canvas.drawPath(hull, Paint()..color = shade(const Color(0xFF091423)));
      canvas.drawPath(
        hull,
        Paint()
          ..color = shade(Palette.line, .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final frame = Paint()
      ..color = shade(Palette.line, .75)
      ..strokeWidth = 5;
    canvas.drawLine(Offset(0, h * .04), Offset(w * .12, 0), frame);
    canvas.drawLine(Offset(w, h * .04), Offset(w * .88, 0), frame);
    canvas.drawLine(
      Offset(w * .08, h * .64),
      Offset(w * .16, h * .83),
      Paint()
        ..color = shade(Palette.rust, .7)
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      Offset(w * .92, h * .64),
      Offset(w * .84, h * .83),
      Paint()
        ..color = shade(Palette.rust, .7)
        ..strokeWidth = 1.4,
    );
    final center = Offset(w / 2, h * .43);
    final hud = Paint()
      ..color = shade(Palette.rust, .7)
      ..strokeWidth = 1;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawLine(
        center + Offset(sign * 13, 0),
        center + Offset(sign * 25, 0),
        hud,
      );
      canvas.drawLine(
        center + Offset(0, sign * 13),
        center + Offset(0, sign * 20),
        hud,
      );
    }
    canvas.drawCircle(
      center,
      3,
      Paint()
        ..color = shade(Palette.rust, .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _text(
      canvas,
      '$collected / ${route.mission.starIndices.length}',
      Offset(w * .21, h * .91),
      18 * textScale,
      shade(Palette.light),
    );
    _text(
      canvas,
      'STARS',
      Offset(w * .21, h * .975),
      9 * textScale,
      shade(Palette.secondary),
    );
    final mode = ending > 0
        ? route.result.success
              ? 'DOCK'
              : 'DRIFT'
        : 'FLIGHT';
    _text(
      canvas,
      mode,
      Offset(w * .79, h * .91),
      13 * textScale,
      shade(Palette.rust),
    );
    _text(
      canvas,
      'ROUTE ${math.min(cursor.floor() + 1, math.max(1, route.result.steps.length))}',
      Offset(w * .79, h * .975),
      9 * textScale,
      shade(Palette.secondary),
    );
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(w * .455 + i * w * .022, h * .95),
        Offset(w * .455 + i * w * .022, h * .965),
        Paint()
          ..color = shade(i < progress * 5 ? Palette.rust : Palette.line)
          ..strokeWidth = 2,
      );
    }
  }

  void _starfield(
    Canvas canvas,
    Size size,
    double travel, {
    double opacity = 1,
  }) {
    for (var i = 0; i < 85; i++) {
      final x = ((i * 137 + 47) % 997) / 997 * size.width;
      final y =
          (((i * 71 + 29) % 491) / 491 * size.height + travel * (i % 3 + 1)) %
          size.height;
      canvas.drawCircle(
        Offset(x, y),
        i % 11 == 0 ? 1.3 : .65,
        Paint()
          ..color = (i % 11 == 0 ? Palette.light : Palette.pipe).withValues(
            alpha: opacity * (i % 4 == 0 ? .5 : .25),
          ),
      );
    }
  }

  void _exterior(Canvas canvas, Size size, double phase, double opacity) {
    final retreat = _smooth(phase);
    final out = route.result.steps.isEmpty
        ? 2
        : route.result.steps.last.outgoing ??
              _opposite(route.result.steps.last.incoming);
    final direction = _direction(out);
    final position = _P3(
      direction.dx * retreat * 2.5,
      -direction.dy * retreat * 2.5,
      5 + retreat * 22,
    );
    final forward = _P3(direction.dx * .5, -direction.dy * .5, 1).unit;
    final right = const _P3(0, 1, 0).cross(forward).unit;
    final up = forward.cross(right).unit;
    final camera = _Camera(
      const _P3(0, 0, 0),
      const _P3(0, 0, 1),
      size,
      -.12 * retreat,
    );
    final vertices = <_P3>[
      position + forward * 1.6,
      position + right * .38,
      position + up * .32,
      position - right * .38,
      position - up * .32,
      position - forward * 1.2,
      position - forward * .8 + right * .85,
      position - forward * .8 - right * .85,
    ];
    final faces = <(List<int>, Color)>[
      ([0, 1, 2], Palette.white),
      ([0, 2, 3], Palette.pipe),
      ([0, 3, 4], Palette.line),
      ([0, 4, 1], Palette.secondary),
      ([1, 5, 2], Palette.pipe),
      ([2, 5, 3], Palette.secondary),
      ([3, 5, 4], Palette.line),
      ([4, 5, 1], Palette.secondary),
      ([1, 6, 5], Palette.rust),
      ([3, 5, 7], Palette.rust),
    ];
    faces.sort(
      (a, b) => b.$1
          .map((i) => vertices[i].z)
          .reduce((a, b) => a + b)
          .compareTo(a.$1.map((i) => vertices[i].z).reduce((a, b) => a + b)),
    );
    for (final (indices, color) in faces) {
      final points = indices
          .map((index) => camera.project(vertices[index]))
          .toList();
      if (points.any((point) => point == null)) continue;
      final mesh = Path()..moveTo(points.first!.dx, points.first!.dy);
      for (final point in points.skip(1)) {
        final vertex = point!;
        mesh.lineTo(vertex.dx, vertex.dy);
      }
      canvas.drawPath(
        mesh..close(),
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
    _text(
      canvas,
      'OFF COURSE',
      Offset(size.width / 2, size.height * .77),
      14 * textScale,
      const Color(0xFFFF987D).withValues(alpha: opacity),
    );
    _text(
      canvas,
      '$collected / ${route.mission.starIndices.length} STARS',
      Offset(size.width / 2, size.height * .85),
      11 * textScale,
      Palette.secondary.withValues(alpha: opacity),
    );
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              radius *
              (i.isEven ? 1 : .43);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    double fontSize,
    Color color,
  ) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Atkinson',
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: .8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(_CockpitPainter old) =>
      progress != old.progress ||
      route.mission != old.route.mission ||
      route.result != old.route.result ||
      reducedMotion != old.reducedMotion ||
      textScale != old.textScale;
}

double _smooth(double value) => value * value * (3 - 2 * value);
