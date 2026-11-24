import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/cargo.dart';
import 'design.dart';

/// Original specimen silhouettes, shared by the board, pickup and collection.
class CargoMark extends StatelessWidget {
  const CargoMark({
    super.key,
    required this.kind,
    this.size = 36,
    this.halo = true,
  });
  final CargoKind kind;
  final double size;
  final bool halo;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: CargoPainter(kind, halo: halo)),
    ),
  );
}

class CargoPainter extends CustomPainter {
  const CargoPainter(this.kind, {this.halo = true});
  final CargoKind kind;
  final bool halo;
  @override
  void paint(Canvas canvas, Size size) => drawCargo(
    canvas,
    size.center(Offset.zero),
    size.shortestSide * .34,
    kind,
    halo: halo,
  );
  @override
  bool shouldRepaint(CargoPainter old) => old.kind != kind || old.halo != halo;
}

void drawCargo(
  Canvas canvas,
  Offset center,
  double radius,
  CargoKind kind, {
  bool halo = true,
  double opacity = 1,
}) {
  if (radius <= 0 || opacity <= 0) return;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  final color = Color(kind.colorValue);
  Color tint(Color c, double a) => c.withValues(alpha: a * opacity);
  final bounds = Rect.fromCircle(center: Offset.zero, radius: radius);
  if (halo) {
    canvas.drawCircle(
      Offset.zero,
      radius * 1.6,
      Paint()
        ..shader = RadialGradient(colors: [tint(color, .25), tint(color, 0)])
            .createShader(bounds.inflate(radius * .6)),
    );
  }
  final outline = Paint()
    ..color = tint(Color.lerp(color, Colors.white, .65)!, .85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(.8, radius * .035);
  if (kind == CargoKind.moonPearl) {
    canvas.drawCircle(
      Offset.zero,
      radius * .76,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.45, -.55),
          radius: 1.2,
          colors: [
            tint(Colors.white, 1),
            tint(color, 1),
            tint(Palette.paper, 1),
          ],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.rotate(-.36);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.35,
        height: radius * .64,
      ),
      outline,
    );
    canvas.restore();
    canvas.drawCircle(
      Offset(-radius * .24, -radius * .26),
      radius * .11,
      Paint()..color = tint(Colors.white, .8),
    );
  } else if (kind == CargoKind.chronoCell) {
    final shell = Path()
      ..moveTo(-radius * .5, -radius)
      ..lineTo(radius * .5, -radius)
      ..lineTo(radius * .75, -radius * .68)
      ..lineTo(radius * .75, radius * .68)
      ..lineTo(radius * .5, radius)
      ..lineTo(-radius * .5, radius)
      ..lineTo(-radius * .75, radius * .68)
      ..lineTo(-radius * .75, -radius * .68)
      ..close();
    canvas.drawPath(
      shell,
      Paint()
        ..shader = LinearGradient(
          colors: [tint(color, .35), tint(Palette.paper, .9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
    );
    canvas.drawPath(shell, outline);
    final hourglass = Path()
      ..moveTo(-radius * .34, -radius * .6)
      ..lineTo(radius * .34, -radius * .6)
      ..lineTo(-radius * .34, radius * .6)
      ..lineTo(radius * .34, radius * .6)
      ..close();
    canvas.drawPath(hourglass, Paint()..color = tint(color, .85));
    canvas.drawCircle(
      Offset.zero,
      radius * .1,
      Paint()..color = tint(Colors.white, 1),
    );
  } else if (kind == CargoKind.routeLens) {
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset.zero,
        radius * (1 - i * .24),
        Paint()
          ..color = tint(color, .65 - i * .16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * (.06 + i * .02),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(-radius * .52, radius * .15)
        ..lineTo(-radius * .1, radius * .15)
        ..lineTo(-radius * .1, -radius * .35)
        ..lineTo(radius * .5, -radius * .35),
      outline..strokeWidth = radius * .1,
    );
    canvas.drawCircle(
      Offset(radius * .5, -radius * .35),
      radius * .12,
      Paint()..color = tint(Colors.white, .95),
    );
  } else {
    final sides = kind == CargoKind.dawnPrism ? 6 : 5;
    final points = List.generate(sides, (i) {
      final angle = -math.pi / 2 + i * math.pi * 2 / sides;
      return Offset(math.cos(angle) * radius * .8, math.sin(angle) * radius);
    });
    final shape = Path()..addPolygon(points, true);
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          colors: [
            tint(Color.lerp(color, Colors.white, .65)!, 1),
            tint(color, 1),
            tint(Color.lerp(color, Palette.paper, .6)!, 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
    );
    final facet = Offset(-radius * .14, -radius * .16);
    for (var i = 0; i < sides; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(facet.dx, facet.dy)
          ..lineTo(points[i].dx, points[i].dy)
          ..lineTo(points[(i + 1) % sides].dx, points[(i + 1) % sides].dy)
          ..close(),
        Paint()
          ..color = tint(
            i.isEven ? Colors.white : Palette.paper,
            i.isEven ? .15 : .12,
          ),
      );
    }
    canvas.drawPath(shape, outline);
    if (kind.isRare) {
      canvas.drawArc(
        bounds.inflate(radius * .3),
        -.85,
        math.pi * 1.3,
        false,
        outline..color = tint(color, .6),
      );
      canvas.drawCircle(
        Offset(radius * .9, -radius * .95),
        radius * .085,
        Paint()..color = tint(Colors.white, 1),
      );
    }
  }
  canvas.restore();
}

void drawCargoHold(
  Canvas canvas,
  Offset center,
  double size, {
  double glow = 0,
}) {
  final rect = Rect.fromCenter(center: center, width: size, height: size * .8);
  if (glow > 0) {
    canvas.drawCircle(
      center,
      size * .85,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Palette.light.withValues(alpha: glow * .4),
            Palette.light.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: size * .85)),
    );
  }
  final hull = Path()
    ..moveTo(rect.left, rect.top + size * .15)
    ..lineTo(rect.left + size * .14, rect.top)
    ..lineTo(rect.right - size * .14, rect.top)
    ..lineTo(rect.right, rect.top + size * .15)
    ..lineTo(rect.right - size * .08, rect.bottom)
    ..lineTo(rect.left + size * .08, rect.bottom)
    ..close();
  canvas.drawPath(
    hull,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF36444B), Color(0xFF111D29)],
      ).createShader(rect),
  );
  canvas.drawPath(
    hull,
    Paint()
      ..color = Palette.light.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3,
  );
  canvas.drawLine(
    Offset(rect.left + size * .12, rect.top + size * .2),
    Offset(rect.right - size * .12, rect.top + size * .2),
    Paint()
      ..color = Palette.light
      ..strokeWidth = size * .08
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(
    Path()
      ..moveTo(center.dx - size * .1, center.dy + size * .06)
      ..lineTo(center.dx, center.dy + size * .16)
      ..lineTo(center.dx + size * .1, center.dy + size * .06),
    Paint()
      ..color = Palette.rust
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
}

class CoinMark extends StatelessWidget {
  const CoinMark({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _CoinPainter()),
  );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = s.shortestSide * .43, p = s.center(Offset.zero);
    c.drawCircle(p, r, Paint()..color = Palette.light.withValues(alpha: .13));
    c.drawCircle(
      p,
      r,
      Paint()
        ..color = Palette.light
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    c.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - r * .55)
        ..lineTo(p.dx + r * .38, p.dy)
        ..lineTo(p.dx, p.dy + r * .55)
        ..lineTo(p.dx - r * .38, p.dy)
        ..close(),
      Paint()..color = Palette.light,
    );
  }

  @override
  bool shouldRepaint(_CoinPainter old) => false;
}
