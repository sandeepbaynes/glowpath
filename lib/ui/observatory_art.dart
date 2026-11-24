import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// Small, deliberately drawn astronomical marks shared by the field guide,
/// collection and mission resources. These are illustrations, not controls.
class OrbitalEmblem extends StatelessWidget {
  const OrbitalEmblem({
    super.key,
    this.size = 44,
    this.color = Palette.light,
    this.variant = 0,
    this.active = true,
  });
  final double size;
  final Color color;
  final int variant;
  final bool active;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: OrbitalEmblemPainter(
          color: color,
          variant: variant,
          active: active,
        ),
      ),
    ),
  );
}

class OrbitalEmblemPainter extends CustomPainter {
  const OrbitalEmblemPainter({
    required this.color,
    this.variant = 0,
    this.active = true,
  });
  final Color color;
  final int variant;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), r = size.shortestSide * .43;
    final tint = active ? color : Palette.secondary;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [tint.withValues(alpha: .13), tint.withValues(alpha: .015)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center,
      r,
      edge..color = tint.withValues(alpha: active ? .35 : .15),
    );
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12, direction = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + direction * r * .86,
        center + direction * r * (i % 6 == 0 ? .72 : .81),
        Paint()
          ..strokeWidth = .65
          ..color = tint.withValues(alpha: .35),
      );
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.4 + variant * .34);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.45, height: r * .6),
      edge..color = tint.withValues(alpha: .55),
    );
    canvas.restore();
    final star = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final radius = r * (i.isEven ? .5 : .13);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.white.withValues(alpha: active ? 1 : .35),
            tint,
            tint.withValues(alpha: .4),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(center, r * .05, Paint()..color = Palette.paper);
  }

  @override
  bool shouldRepaint(OrbitalEmblemPainter old) =>
      old.color != color || old.variant != variant || old.active != active;
}

class MissionIllustration extends StatelessWidget {
  const MissionIllustration({
    super.key,
    this.kind = 'route',
    this.color = Palette.rust,
  });
  final String kind;
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _RoutePlate(kind, color),
      child: const SizedBox.expand(),
    ),
  );
}

String illustrationFor(IconData icon) {
  if ([Icons.link_rounded, Icons.sync_rounded].contains(icon)) return 'linked';
  if (icon == Icons.all_inclusive_rounded) return 'portal';
  if ([Icons.shield_rounded, Icons.shield_outlined].contains(icon)) {
    return 'defense';
  }
  if ([Icons.layers_rounded, Icons.alt_route_rounded].contains(icon)) {
    return 'crossing';
  }
  if ([
    Icons.blur_circular_rounded,
    Icons.flare_rounded,
    Icons.call_split_rounded,
  ].contains(icon)) {
    return 'gravity';
  }
  return 'route';
}

class _RoutePlate extends CustomPainter {
  const _RoutePlate(this.kind, this.color);
  final String kind;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 320, size.height / 120);
    canvas.save();
    canvas.translate(
      (size.width - 320 * scale) / 2,
      (size.height - 120 * scale) / 2,
    );
    canvas.scale(scale);
    final guide = Paint()
      ..color = Palette.secondary.withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (final x in [32.0, 96.0, 160.0, 224.0, 288.0]) {
      canvas.drawLine(Offset(x, 12), Offset(x, 108), guide);
      canvas.drawLine(Offset(x - 3, 108), Offset(x + 3, 108), guide);
    }
    for (final y in [34.0, 78.0]) {
      canvas.drawLine(Offset(12, y), Offset(308, y), guide);
    }
    final path = Path()
      ..moveTo(25, 78)
      ..lineTo(84, 78)
      ..quadraticBezierTo(96, 78, 96, 66)
      ..lineTo(96, 46)
      ..quadraticBezierTo(96, 34, 108, 34)
      ..lineTo(148, 34)
      ..quadraticBezierTo(160, 34, 160, 46)
      ..lineTo(160, 66)
      ..quadraticBezierTo(160, 78, 172, 78)
      ..lineTo(212, 78)
      ..quadraticBezierTo(224, 78, 224, 66)
      ..lineTo(224, 46)
      ..quadraticBezierTo(224, 34, 236, 34)
      ..lineTo(292, 34);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    for (final p in [
      const Offset(96, 34),
      const Offset(160, 78),
      const Offset(224, 34),
    ]) {
      canvas.drawCircle(p, 10, Paint()..color = Palette.paper);
      final star = Path()
        ..moveTo(p.dx, p.dy - 6)
        ..lineTo(p.dx + 1.8, p.dy - 1.8)
        ..lineTo(p.dx + 6, p.dy)
        ..lineTo(p.dx + 1.8, p.dy + 1.8)
        ..lineTo(p.dx, p.dy + 6)
        ..lineTo(p.dx - 1.8, p.dy + 1.8)
        ..lineTo(p.dx - 6, p.dy)
        ..lineTo(p.dx - 1.8, p.dy - 1.8)
        ..close();
      canvas.drawPath(star, Paint()..color = Palette.light);
    }
    canvas.drawPath(
      Path()
        ..moveTo(38, 78)
        ..lineTo(22, 72)
        ..lineTo(26, 78)
        ..lineTo(22, 84)
        ..close(),
      Paint()..color = Palette.white,
    );
    canvas.drawCircle(
      const Offset(292, 34),
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.light,
    );
    canvas.drawCircle(const Offset(292, 34), 3, Paint()..color = Palette.light);
    if (kind != 'route') {
      final centers = kind == 'linked' || kind == 'portal'
          ? [const Offset(96, 56), const Offset(224, 56)]
          : [const Offset(160, 56)];
      for (final p in centers) {
        canvas.drawCircle(p, 15, Paint()..color = Palette.paper);
        canvas.drawCircle(
          p,
          14,
          Paint()
            ..color = color.withValues(alpha: .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        if (kind == 'defense') {
          canvas.drawPath(
            Path()
              ..moveTo(p.dx - 7, p.dy - 6)
              ..lineTo(p.dx, p.dy - 9)
              ..lineTo(p.dx + 7, p.dy - 6)
              ..lineTo(p.dx + 6, p.dy + 4)
              ..lineTo(p.dx, p.dy + 10)
              ..lineTo(p.dx - 6, p.dy + 4)
              ..close(),
            Paint()
              ..color = Palette.light.withValues(alpha: .6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        } else {
          canvas.drawOval(
            Rect.fromCenter(
              center: p,
              width: kind == 'crossing' ? 20 : 16,
              height: kind == 'portal' ? 8 : 16,
            ),
            Paint()
              ..color = Palette.light
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoutePlate old) => old.kind != kind || old.color != color;
}
