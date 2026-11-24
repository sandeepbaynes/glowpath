import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Original miniature flight trophies. Each award has its own silhouette and
/// story; these are painted geometry, not a rotated badge or downloaded icon.
class AchievementArtwork extends StatelessWidget {
  const AchievementArtwork({
    super.key,
    required this.id,
    required this.size,
    this.earned = true,
    this.phase,
  });

  final String id;
  final double size;
  final bool earned;
  final ValueListenable<double>? phase;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _AchievementPainter(id, earned, phase)),
      ),
    ),
  );
}

class _AchievementPainter extends CustomPainter {
  _AchievementPainter(this.id, this.earned, this.phase) : super(repaint: phase);
  final String id;
  final bool earned;
  final ValueListenable<double>? phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 240);
    final art = _AwardScene(canvas, earned, phase?.value ?? 0);
    art.atmosphere();
    switch (id) {
      case 'first_signal':
        art.signal();
      case 'navigator_5':
        art.planet();
      case 'navigator_25':
        art.galaxy();
      case 'navigator_100':
        art.explorer();
      case 'efficient_200':
        art.precision();
      case 'daily_trio':
        art.trio();
      case 'daily_7':
        art.sevenDays();
      case 'weekly_expedition':
        art.expedition();
      case 'weekly_4':
        art.seasons();
      case 'first_cargo':
        art.cargo();
      case 'cargo_5':
        art.cabinet();
      case 'rare_cargo':
        art.window();
      default:
        art.signal();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AchievementPainter old) =>
      old.id != id || old.earned != earned || old.phase != phase;
}

class _AwardScene {
  _AwardScene(this.c, this.earned, this.phase);
  final Canvas c;
  final bool earned;
  final double phase;
  static const gold = Color(0xFFECC991);
  static const mint = Color(0xFF9EDAD3);
  static const blue = Color(0xFF728FAF);
  static const lilac = Color(0xFFADA0CF);
  static const ivory = Color(0xFFEBE7DA);

  Color color(Color value, [double opacity = 1]) =>
      (earned ? value : Color.lerp(value, const Color(0xFF60748A), .64)!)
          .withValues(alpha: opacity * (earned ? 1 : .66));
  Paint fill(Color value, [double opacity = 1]) =>
      Paint()..color = color(value, opacity);
  Paint line(Color value, [double width = 1.4, double opacity = 1]) => Paint()
    ..color = color(value, opacity)
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  void path(List<Offset> points, Color tone, [double width = 1.5]) {
    final p = Path()..addPolygon(points, false);
    c.drawPath(p, line(tone, width));
  }

  void poly(List<Offset> points, Color tone, [double opacity = 1]) =>
      c.drawPath(Path()..addPolygon(points, true), fill(tone, opacity));

  void atmosphere() {
    final glow = Rect.fromCircle(center: const Offset(120, 120), radius: 115);
    c.drawCircle(
      const Offset(120, 120),
      115,
      Paint()
        ..shader = RadialGradient(
          colors: [color(mint, .085), color(blue, .025), Colors.transparent],
          stops: const [0, .55, 1],
        ).createShader(glow),
    );
    for (final (x, y, r) in const [
      (34.0, 62.0, 1.2),
      (198.0, 43.0, 1.1),
      (210.0, 160.0, .9),
      (47.0, 182.0, .8),
      (170.0, 207.0, .8),
      (84.0, 31.0, .8),
    ]) {
      final shimmer = .36 + .13 * math.sin(phase * math.pi * 2 + x);
      c.drawCircle(Offset(x, y), r, fill(ivory, shimmer));
    }
  }

  void orb(Offset at, double radius, Color tone) {
    final rect = Rect.fromCircle(center: at, radius: radius);
    c.drawCircle(
      at + const Offset(3, 7),
      radius,
      fill(const Color(0xFF01050B), .32),
    );
    c.drawCircle(
      at,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.48, -.6),
          radius: 1.1,
          colors: [
            color(Color.lerp(tone, ivory, .6)!),
            color(tone),
            color(const Color(0xFF122132)),
          ],
          stops: const [0, .5, 1],
        ).createShader(rect),
    );
    c.drawArc(
      rect.deflate(.8),
      math.pi * 1.05,
      math.pi * .65,
      false,
      line(ivory, 1, .48),
    );
  }

  void star(Offset at, double radius, {Color tone = gold, double tilt = 0}) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(tilt);
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final r = i.isEven ? radius : radius * .28;
      final point = Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        p.moveTo(point.dx, point.dy);
      } else {
        p.lineTo(point.dx, point.dy);
      }
    }
    p.close();
    c.drawPath(p, fill(tone));
    poly(
      [
        Offset.zero,
        Offset(0, -radius),
        Offset(radius * .2, -radius * .2),
        Offset(radius, 0),
      ],
      ivory,
      .45,
    );
    c.restore();
  }

  void signal() {
    c.drawOval(const Rect.fromLTWH(55, 185, 131, 15), fill(blue, .16));
    poly(const [
      Offset(108, 140),
      Offset(129, 140),
      Offset(143, 190),
      Offset(94, 190),
    ], blue);
    poly(
      const [
        Offset(108, 140),
        Offset(117, 140),
        Offset(112, 187),
        Offset(98, 187),
      ],
      mint,
      .65,
    );
    c.save();
    c.translate(115, 117);
    c.rotate(-.6);
    final bowl = Path()
      ..moveTo(-51, 0)
      ..quadraticBezierTo(0, 70, 51, 0)
      ..close();
    c.drawPath(
      bowl,
      Paint()
        ..shader = LinearGradient(colors: [color(ivory), color(blue)])
            .createShader(const Rect.fromLTWH(-51, 0, 102, 48)),
    );
    c.drawOval(
      const Rect.fromLTWH(-52, -12, 104, 24),
      fill(const Color(0xFF173044)),
    );
    c.drawOval(const Rect.fromLTWH(-52, -12, 104, 24), line(mint, 2));
    c.drawLine(const Offset(0, 18), const Offset(0, -29), line(ivory, 4));
    c.drawCircle(const Offset(0, -29), 5, fill(gold));
    c.restore();
    for (var i = 0; i < 3; i++) {
      c.drawArc(
        Rect.fromCircle(center: const Offset(137, 88), radius: 22 + i * 15),
        -1.6,
        .8,
        false,
        line(mint, 1.8, .8 - i * .2),
      );
    }
    star(const Offset(179, 42), 9);
  }

  void planet() {
    c.save();
    c.translate(118, 125);
    c.rotate(-.35);
    c.drawOval(const Rect.fromLTWH(-91, -26, 182, 52), line(gold, 8, .5));
    c.restore();
    orb(const Offset(118, 125), 58, mint);
    c.save();
    c.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(118, 125), radius: 58)),
    );
    for (var i = 0; i < 4; i++) {
      final p = Path()
        ..moveTo(58, 98 + i * 20)
        ..cubicTo(97, 77 + i * 20, 137, 128 + i * 20, 181, 101 + i * 20);
      c.drawPath(p, line(ivory, 4, .13));
    }
    c.restore();
    c.save();
    c.translate(118, 125);
    c.rotate(-.35);
    c.drawArc(
      const Rect.fromLTWH(-91, -26, 182, 52),
      0,
      math.pi,
      false,
      line(gold, 7),
    );
    c.drawArc(
      const Rect.fromLTWH(-94, -29, 188, 58),
      0,
      math.pi,
      false,
      line(ivory, 1, .65),
    );
    c.restore();
    orb(const Offset(175, 49), 15, blue);
    for (var i = 0; i < 5; i++) {
      c.drawCircle(Offset(86 + i * 16.0, 210), 2.5, fill(gold, .8));
    }
  }

  void galaxy() {
    c.save();
    c.translate(120, 123);
    c.rotate(-.35);
    c.scale(1, .67);
    for (var arm = 0; arm < 3; arm++) {
      final p = Path();
      for (var i = 0; i <= 80; i++) {
        final t = i / 80.0, r = 7 + t * 89, a = t * 4.6 + arm * math.pi * 2 / 3;
        final x = math.cos(a) * r, y = math.sin(a) * r;
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      c.drawPath(p, line(lilac, 19, .06));
      c.drawPath(p, line(lilac, 8, .18));
      c.drawPath(p, line(mint, 2, .85));
      for (var i = 2; i < 13; i++) {
        final t = i / 13, r = 7 + t * 89, a = t * 4.6 + arm * math.pi * 2 / 3;
        c.drawCircle(
          Offset(math.cos(a) * r, math.sin(a) * r),
          i % 3 == 0 ? 2.2 : 1.3,
          fill(ivory, .8),
        );
      }
    }
    c.drawCircle(
      Offset.zero,
      15,
      Paint()
        ..shader = RadialGradient(
          colors: [color(ivory), color(gold, .55), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 15)),
    );
    c.restore();
    star(const Offset(190, 61), 10, tone: mint);
  }

  void explorer() {
    final horizon = Path()
      ..moveTo(34, 190)
      ..quadraticBezierTo(120, 130, 210, 190);
    c.drawPath(horizon, line(blue, 2, .6));
    c.save();
    c.translate(121, 108);
    c.rotate(.43);
    for (var i = 0; i < 5; i++) {
      c.drawLine(
        Offset(-42 + i * 21.0, 45),
        Offset(-42 + i * 21.0, 82),
        line(mint, 1, .15),
      );
    }
    rocket(Offset.zero, 1.0);
    c.restore();
    for (final p in const [Offset(58, 73), Offset(181, 55), Offset(192, 134)]) {
      star(p, 6, tone: ivory);
    }
    c.drawArc(
      const Rect.fromLTWH(43, 40, 157, 155),
      -2.9,
      1.05,
      false,
      line(lilac, 2, .8),
    );
  }

  void rocket(Offset at, double scale) {
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(scale);
    poly(const [Offset(-8, 40), Offset(0, 75), Offset(8, 40)], gold, .8);
    poly(const [Offset(-5, 40), Offset(0, 61), Offset(5, 40)], ivory);
    poly(const [Offset(-13, 17), Offset(-30, 41), Offset(-12, 37)], mint);
    poly(const [Offset(13, 17), Offset(30, 41), Offset(12, 37)], blue);
    final hull = Path()
      ..moveTo(0, -49)
      ..cubicTo(-23, -23, -17, 24, -11, 42)
      ..lineTo(11, 42)
      ..cubicTo(17, 24, 23, -23, 0, -49)
      ..close();
    c.drawPath(
      hull,
      Paint()
        ..shader = LinearGradient(
          colors: [color(ivory), color(mint), color(blue)],
        ).createShader(const Rect.fromLTWH(-17, -49, 34, 91)),
    );
    c.drawCircle(const Offset(0, -7), 9, fill(const Color(0xFF102337)));
    c.drawCircle(const Offset(0, -7), 9, line(ivory, 1.3, .7));
    c.drawArc(
      Rect.fromCircle(center: Offset(0, -7), radius: 6),
      -2.8,
      1.5,
      false,
      line(mint, 2, .8),
    );
    c.restore();
  }

  void precision() {
    final route = Path()
      ..moveTo(42, 162)
      ..lineTo(83, 162)
      ..quadraticBezierTo(96, 162, 96, 149)
      ..lineTo(96, 96)
      ..quadraticBezierTo(96, 82, 110, 82)
      ..lineTo(190, 82);
    c.drawPath(route, line(mint, 19, .07));
    c.drawPath(route, line(blue, 12));
    c.drawPath(route, line(ivory, 4));
    for (final p in const [Offset(70, 162), Offset(96, 119), Offset(151, 82)]) {
      star(p, 12);
    }
    c.drawCircle(const Offset(42, 162), 6, fill(mint));
    c.drawCircle(const Offset(190, 82), 11, line(gold, 2.5));
    path(const [Offset(141, 154), Offset(155, 168), Offset(183, 135)], mint, 4);
    path(const [Offset(46, 64), Offset(46, 48), Offset(64, 48)], blue, 1);
    path(const [Offset(192, 178), Offset(192, 195), Offset(175, 195)], blue, 1);
  }

  void trio() {
    final p = Path()
      ..moveTo(51, 149)
      ..quadraticBezierTo(75, 78, 120, 84)
      ..quadraticBezierTo(164, 85, 192, 146);
    c.drawPath(p, line(mint, 2, .6));
    star(const Offset(51, 149), 22);
    star(const Offset(120, 84), 30, tone: ivory);
    star(const Offset(192, 146), 22);
    c.drawArc(
      const Rect.fromLTWH(64, 148, 112, 60),
      0,
      math.pi,
      false,
      line(blue, 2, .65),
    );
    c.drawCircle(const Offset(120, 184), 4, fill(mint));
  }

  void sevenDays() {
    orb(const Offset(120, 120), 33, gold);
    for (var i = 0; i < 7; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 7;
      final at = Offset(120 + math.cos(a) * 77, 120 + math.sin(a) * 77);
      c.drawLine(
        Offset(120 + math.cos(a) * 44, 120 + math.sin(a) * 44),
        Offset(120 + math.cos(a) * 58, 120 + math.sin(a) * 58),
        line(gold, 1, .4),
      );
      orb(at, 10, i.isEven ? mint : ivory);
    }
    star(const Offset(111, 113), 13, tone: ivory);
  }

  void expedition() {
    final route = Path()
      ..moveTo(44, 180)
      ..cubicTo(29, 110, 188, 160, 183, 57);
    c.drawPath(route, line(blue, 13, .18));
    c.drawPath(route, line(mint, 2));
    for (final (i, p) in const [
      Offset(44, 180),
      Offset(78, 139),
      Offset(123, 127),
      Offset(164, 107),
      Offset(183, 57),
    ].indexed) {
      c.drawCircle(p, 7, fill(blue));
      c.drawCircle(p, 3, fill(i == 4 ? gold : ivory));
    }
    c.drawLine(const Offset(183, 57), const Offset(183, 27), line(ivory, 2));
    poly(const [Offset(184, 27), Offset(211, 33), Offset(184, 42)], gold);
    rocket(const Offset(65, 69), .45);
    path(
      const [Offset(101, 181), Offset(123, 181), Offset(123, 169)],
      gold,
      1.2,
    );
  }

  void seasons() {
    for (final (i, at) in const [
      Offset(84, 80),
      Offset(155, 80),
      Offset(84, 152),
      Offset(155, 152),
    ].indexed) {
      final tone = [mint, gold, lilac, blue][i];
      orb(at, 27, tone);
      c.drawArc(
        Rect.fromCircle(center: at, radius: 34),
        -.6,
        math.pi * 1.1,
        false,
        line(tone, 1, .6),
      );
    }
    star(const Offset(120, 116), 14);
    c.drawLine(
      const Offset(79, 206),
      const Offset(161, 206),
      line(gold, 1, .55),
    );
    for (var i = 0; i < 4; i++) {
      c.drawCircle(Offset(90 + i * 20.0, 206), 2.5, fill(ivory));
    }
  }

  void crystal(Offset at, double scale, Color tone) {
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(scale);
    poly(const [
      Offset(0, -39),
      Offset(24, -12),
      Offset(20, 24),
      Offset(0, 40),
      Offset(-20, 24),
      Offset(-24, -12),
    ], tone);
    poly(const [
      Offset(0, -39),
      Offset(0, 40),
      Offset(-20, 24),
      Offset(-24, -12),
    ], Color.lerp(tone, ivory, .55)!);
    poly(const [Offset(0, -39), Offset(24, -12), Offset(0, -5)], ivory, .55);
    poly(
      const [Offset(0, -5), Offset(24, -12), Offset(20, 24), Offset(0, 40)],
      blue,
      .55,
    );
    path(const [Offset(-24, -12), Offset(0, -5), Offset(24, -12)], ivory, 1);
    c.restore();
  }

  void cargo() {
    c.drawOval(const Rect.fromLTWH(63, 177, 114, 21), fill(blue, .2));
    poly(const [
      Offset(61, 157),
      Offset(120, 137),
      Offset(179, 157),
      Offset(120, 184),
    ], blue);
    poly(
      const [
        Offset(61, 157),
        Offset(120, 184),
        Offset(120, 200),
        Offset(61, 174),
      ],
      mint,
      .6,
    );
    poly(
      const [
        Offset(120, 184),
        Offset(179, 157),
        Offset(179, 174),
        Offset(120, 200),
      ],
      blue,
      .85,
    );
    crystal(const Offset(120, 99), 1.1, mint);
    star(const Offset(179, 78), 10);
    path(const [Offset(66, 99), Offset(66, 122), Offset(77, 129)], gold, 1.2);
    path(
      const [Offset(175, 119), Offset(175, 133), Offset(163, 139)],
      gold,
      1.2,
    );
  }

  void cabinet() {
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(41, 48, 158, 148),
      const Radius.circular(14),
    );
    c.drawRRect(frame, fill(blue, .13));
    c.drawRRect(frame, line(mint, 1.4, .7));
    c.drawLine(const Offset(47, 119), const Offset(193, 119), line(blue, 2));
    crystal(const Offset(82, 86), .58, mint);
    orb(const Offset(155, 86), 19, ivory);
    crystal(const Offset(77, 154), .46, lilac);
    star(const Offset(121, 153), 17);
    orb(const Offset(166, 153), 13, gold);
    c.drawLine(
      const Offset(51, 202),
      const Offset(189, 202),
      line(gold, 2, .5),
    );
    c.drawCircle(const Offset(120, 40), 3, fill(gold));
  }

  void window() {
    c.save();
    c.clipPath(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(51, 38, 138, 164),
          const Radius.circular(64),
        ),
      ),
    );
    c.drawRect(
      const Rect.fromLTWH(51, 38, 69, 164),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color(gold, .08), color(gold, .42)],
        ).createShader(const Rect.fromLTWH(51, 38, 69, 164)),
    );
    c.drawRect(const Rect.fromLTWH(120, 38, 69, 164), fill(lilac, .15));
    orb(const Offset(79, 124), 29, gold);
    c.drawCircle(const Offset(159, 78), 18, fill(ivory));
    c.drawCircle(const Offset(168, 70), 18, fill(const Color(0xFF253047)));
    c.drawLine(
      const Offset(45, 154),
      const Offset(195, 154),
      line(mint, 1.2, .6),
    );
    c.restore();
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(51, 38, 138, 164),
        const Radius.circular(64),
      ),
      line(blue, 2, .8),
    );
    crystal(const Offset(120, 144), .9, lilac);
    star(const Offset(198, 72), 8, tone: mint);
  }
}
