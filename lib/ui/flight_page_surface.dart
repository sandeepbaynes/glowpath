import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// A bounded, non-scrolling carousel surface. Arrow controls remain the primary
/// accessible alternative; dragging never changes a setting or mission timer.
class FlightPageSurface extends StatefulWidget {
  const FlightPageSurface({
    super.key,
    required this.child,
    required this.reduceMotion,
    this.onPrevious,
    this.onNext,
  });
  final Widget child;
  final bool reduceMotion;
  final VoidCallback? onPrevious, onNext;
  @override
  State<FlightPageSurface> createState() => _FlightPageSurfaceState();
}

class _FlightPageSurfaceState extends State<FlightPageSurface> {
  double _drag = 0;
  bool _dragging = false, _cancelled = false;

  void _release([DragEndDetails? details]) {
    final velocity = details?.primaryVelocity ?? 0;
    final goNext =
        !_cancelled && details != null && (_drag < -42 || velocity < -420);
    final goPrevious =
        !_cancelled && details != null && (_drag > 42 || velocity > 420);
    setState(() {
      _dragging = false;
      _drag = 0;
    });
    if (goNext) {
      widget.onNext?.call();
    } else if (goPrevious) {
      widget.onPrevious?.call();
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          widget.onPrevious?.call(),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          widget.onNext?.call(),
    },
    child: Focus(
      child: Listener(
        onPointerDown: (_) => _cancelled = false,
        onPointerCancel: (_) => _cancelled = true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (details) => setState(
            () => _drag = (_drag + details.delta.dx).clamp(-140, 140),
          ),
          onHorizontalDragEnd: _release,
          onHorizontalDragCancel: () => _release(),
          child: AnimatedContainer(
            duration: _dragging || widget.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              widget.reduceMotion ? 0 : _drag / (1 + _drag.abs() / 90) * .22,
              0,
              0,
            ),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

/// Original diagram artwork drawn in the same channel, metal and glow palette
/// as the game board. These marks explain a mechanic instead of decorating it.
class FlightLessonArt extends StatelessWidget {
  const FlightLessonArt({
    super.key,
    this.kind = 'route',
    this.highContrast = false,
    this.haptics = true,
    this.centerGlyph,
  });
  final String kind;
  final bool highContrast, haptics;
  final Widget? centerGlyph;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _LessonPainter(kind, highContrast, haptics),
      child: centerGlyph == null
          ? const SizedBox.expand()
          : Center(child: centerGlyph),
    ),
  );
}

class _LessonPainter extends CustomPainter {
  const _LessonPainter(this.kind, this.highContrast, this.haptics);
  final String kind;
  final bool highContrast, haptics;

  @override
  void paint(Canvas canvas, Size size) {
    final routePlate = ['route', 'stars', 'adjust'].contains(kind);
    final artHeight = routePlate
        ? 220.0
        : kind == 'feel'
        ? 60.0
        : 160.0;
    final scale = math.min(size.width / 360, size.height / artHeight);
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - artHeight * scale) / 2,
    );
    canvas.scale(scale);
    const accent = Palette.rust;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final glow = Rect.fromCenter(
      center: const Offset(180, 80),
      width: 340,
      height: 160,
    );
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: .09), accent.withValues(alpha: 0)],
        ).createShader(glow),
    );
    if (kind == 'feel') {
      for (final x in [48.0, 114.0, 180.0, 246.0, 312.0]) {
        final rect = Rect.fromCenter(
          center: Offset(x, 30),
          width: 60,
          height: 50,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()..color = Palette.tile,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          line
            ..strokeWidth = .7
            ..color = Palette.line,
        );
      }
      canvas.drawLine(
        const Offset(20, 30),
        const Offset(340, 30),
        line
          ..strokeWidth = 12
          ..color = accent.withValues(alpha: .06),
      );
      canvas.drawLine(
        const Offset(20, 30),
        const Offset(340, 30),
        line
          ..strokeWidth = highContrast ? 8 : 5
          ..color = highContrast ? Palette.white : accent,
      );
      if (highContrast) {
        for (final x in [48.0, 114.0, 246.0, 312.0]) {
          canvas.drawCircle(Offset(x, 30), 3, Paint()..color = Palette.paper);
        }
      }
      const cursor = Offset(180, 30);
      canvas.drawCircle(cursor, 14, Paint()..color = Palette.board);
      canvas.drawCircle(
        cursor,
        12,
        line
          ..strokeWidth = 1
          ..color = Palette.white.withValues(alpha: .6),
      );
      canvas.drawCircle(cursor, 4, Paint()..color = Palette.white);
      if (haptics) {
        for (final radius in [20.0, 26.0]) {
          canvas.drawArc(
            Rect.fromCircle(center: cursor, radius: radius),
            -.8,
            1.6,
            false,
            line
              ..strokeWidth = 1
              ..color = accent.withValues(alpha: .5),
          );
          canvas.drawArc(
            Rect.fromCircle(center: cursor, radius: radius),
            math.pi - .8,
            1.6,
            false,
            line,
          );
        }
      }
    } else if ([
      'lock',
      'direction',
      'linked',
      'portal',
      'pull',
      'push',
      'defense',
      'shield',
    ].contains(kind)) {
      final pair = kind == 'linked' || kind == 'portal' || kind == 'defense';
      final centers = pair
          ? [const Offset(110, 80), const Offset(250, 80)]
          : [const Offset(180, 80)];
      final tone = kind == 'linked' ? const Color(0xFFC7B0EC) : accent;
      canvas.drawLine(
        const Offset(26, 80),
        const Offset(334, 80),
        line
          ..strokeWidth = 5
          ..color = tone.withValues(alpha: .65),
      );
      for (final (index, p) in centers.indexed) {
        final plate = Rect.fromCenter(center: p, width: 84, height: 84);
        canvas.drawRRect(
          RRect.fromRectAndRadius(plate, const Radius.circular(18)),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF20364B), Palette.board],
            ).createShader(plate),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(plate, const Radius.circular(18)),
          line
            ..strokeWidth = 1
            ..color = Palette.line,
        );
        if (kind == 'lock') {
          canvas.drawLine(
            p + const Offset(-42, 0),
            p + const Offset(42, 0),
            line
              ..strokeWidth = 7
              ..color = Palette.secondary,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: 27, height: 23),
              const Radius.circular(5),
            ),
            Paint()..color = Palette.board,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: 27, height: 23),
              const Radius.circular(5),
            ),
            line
              ..strokeWidth = 1.6
              ..color = Palette.light,
          );
          canvas.drawArc(
            Rect.fromCenter(
              center: p + const Offset(0, -10),
              width: 15,
              height: 17,
            ),
            math.pi,
            math.pi,
            false,
            line,
          );
          canvas.drawCircle(p, 2, Paint()..color = Palette.light);
        } else if (kind == 'direction') {
          canvas.drawLine(
            p + const Offset(-42, 0),
            p + const Offset(42, 0),
            line
              ..strokeWidth = 7
              ..color = accent,
          );
          for (final dx in [-18.0, 0.0, 18.0]) {
            _chevron(canvas, p + Offset(dx, 0), Palette.paper);
          }
        } else if (kind == 'linked') {
          final elbow = Path()
            ..moveTo(p.dx - 42, p.dy)
            ..lineTo(p.dx - 9, p.dy)
            ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - 9)
            ..lineTo(p.dx, p.dy - 42);
          canvas.drawPath(
            elbow,
            line
              ..strokeWidth = 6
              ..color = tone,
          );
          canvas.drawCircle(
            p + const Offset(20, 23),
            8,
            line
              ..strokeWidth = 1.5
              ..color = tone,
          );
          canvas.drawCircle(p + const Offset(20, 23), 2, Paint()..color = tone);
          canvas.drawArc(
            Rect.fromCircle(center: p, radius: 53),
            -.65,
            1.3,
            false,
            line
              ..strokeWidth = 1
              ..color = tone.withValues(alpha: .6),
          );
        } else if (kind == 'portal') {
          for (var i = 0; i < 4; i++) {
            canvas.drawOval(
              Rect.fromCenter(center: p, width: 32 + i * 7, height: 46 + i * 4),
              line
                ..strokeWidth = 1.2
                ..color = tone.withValues(alpha: .8 - i * .15),
            );
          }
          canvas.drawOval(
            Rect.fromCenter(center: p, width: 27, height: 40),
            Paint()..color = Palette.paper,
          );
          canvas.drawCircle(
            p + const Offset(0, 30),
            2,
            Paint()..color = Palette.light,
          );
        } else if (kind == 'pull' || kind == 'push') {
          canvas.drawCircle(
            p,
            21,
            Paint()..color = kind == 'pull' ? Palette.paper : Palette.white,
          );
          for (final radius in [26.0, 32.0]) {
            canvas.drawArc(
              Rect.fromCircle(center: p, radius: radius),
              -.5,
              4.6,
              false,
              line
                ..strokeWidth = 1
                ..color = Palette.light.withValues(alpha: .7),
            );
          }
          for (final sign in [-1.0, 1.0]) {
            canvas.save();
            canvas.translate(p.dx + sign * 65, p.dy);
            canvas.rotate(
              kind == 'pull'
                  ? (sign < 0 ? 0 : math.pi)
                  : (sign < 0 ? math.pi : 0),
            );
            _chevron(canvas, Offset.zero, Palette.light);
            canvas.restore();
          }
        } else if (kind == 'defense' && index == 0) {
          for (final delta in [const Offset(-10, 12), const Offset(10, -12)]) {
            canvas.drawCircle(p + delta, 7, Paint()..color = Palette.paper);
            canvas.drawCircle(
              p + delta,
              6,
              line
                ..strokeWidth = 1.5
                ..color = tone,
            );
          }
          canvas.drawLine(
            p + const Offset(-10, 12),
            p + const Offset(10, -12),
            line
              ..strokeWidth = 4
              ..color = Palette.white,
          );
          canvas.drawCircle(
            p + const Offset(10, -12),
            3,
            Paint()..color = tone,
          );
        } else if (kind == 'shield') {
          final shield = Path()
            ..moveTo(p.dx - 20, p.dy - 20)
            ..lineTo(p.dx, p.dy - 27)
            ..lineTo(p.dx + 20, p.dy - 20)
            ..lineTo(p.dx + 16, p.dy + 9)
            ..quadraticBezierTo(p.dx + 10, p.dy + 22, p.dx, p.dy + 27)
            ..quadraticBezierTo(p.dx - 10, p.dy + 22, p.dx - 16, p.dy + 9)
            ..close();
          canvas.drawPath(shield, Paint()..color = tone.withValues(alpha: .14));
          canvas.drawPath(
            shield,
            line
              ..strokeWidth = 2
              ..color = tone,
          );
          canvas.drawPath(
            Path()
              ..moveTo(p.dx - 9, p.dy)
              ..lineTo(p.dx - 2, p.dy + 8)
              ..lineTo(p.dx + 11, p.dy - 8),
            line
              ..strokeWidth = 2
              ..color = Palette.white,
          );
        } else {
          canvas.drawCircle(
            p,
            16,
            line
              ..strokeWidth = 2
              ..color = Palette.light,
          );
          for (final delta in [
            const Offset(-25, 0),
            const Offset(25, 0),
            const Offset(0, -25),
            const Offset(0, 25),
          ]) {
            canvas.drawLine(p + delta * .8, p + delta * 1.15, line);
          }
          canvas.drawLine(
            p + const Offset(-20, 20),
            p + const Offset(20, -20),
            line
              ..strokeWidth = 3
              ..color = tone,
          );
        }
      }
      if (pair) _chevron(canvas, const Offset(180, 80), Palette.white);
    } else if (kind == 'timer' || kind == 'pause') {
      for (final (index, fraction) in [1.0, .9, .8].indexed) {
        final p = Offset(78 + index * 102, 80);
        canvas.drawCircle(
          p,
          33,
          line
            ..strokeWidth = 2
            ..color = Palette.line,
        );
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 33),
          -math.pi / 2,
          math.pi * 2 * fraction,
          false,
          line
            ..strokeWidth = 3
            ..color = index == 2 ? Palette.light : accent,
        );
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          final d = Offset(math.sin(a), -math.cos(a));
          canvas.drawLine(
            p + d * 24,
            p + d * 27,
            line
              ..strokeWidth = 1
              ..color = Palette.secondary.withValues(alpha: .45),
          );
        }
        if (kind == 'pause') {
          for (final dx in [-5.0, 5.0]) {
            canvas.drawLine(
              p + Offset(dx, -10),
              p + Offset(dx, 10),
              line
                ..strokeWidth = 4
                ..color = accent,
            );
          }
        } else {
          canvas.drawLine(
            p,
            p + Offset(math.sin(index * .5) * 18, -math.cos(index * .5) * 18),
            line
              ..strokeWidth = 2.5
              ..color = Palette.white,
          );
          canvas.drawCircle(p, 3, Paint()..color = Palette.white);
        }
        if (index < 2) {
          _chevron(canvas, p + const Offset(51, 0), Palette.secondary);
        }
      }
    } else if (kind == 'rewards') {
      for (var i = 0; i < 3; i++) {
        final p = Offset(104 + i * 76, i == 1 ? 64 : 85);
        canvas.drawCircle(
          p,
          i == 1 ? 39 : 31,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Palette.light.withValues(alpha: .11),
                Palette.light.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: p, radius: 39)),
        );
        _star(canvas, p, i == 1 ? 24 : 17);
      }
      final tray = Path()
        ..moveTo(93, 118)
        ..lineTo(113, 137)
        ..lineTo(247, 137)
        ..lineTo(267, 118);
      canvas.drawPath(
        tray,
        line
          ..strokeWidth = 2
          ..color = accent.withValues(alpha: .55),
      );
    } else {
      const cells = [
        Offset(48, 170),
        Offset(114, 170),
        Offset(114, 110),
        Offset(114, 50),
        Offset(180, 50),
        Offset(246, 50),
        Offset(246, 110),
        Offset(246, 170),
        Offset(312, 170),
      ];
      if (kind != 'mechanic') {
        for (final p in cells) {
          final rect = Rect.fromCenter(center: p, width: 60, height: 56);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(12)),
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3549), Palette.board],
              ).createShader(rect),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(12)),
            line
              ..strokeWidth = .8
              ..color = Palette.line.withValues(alpha: .65),
          );
        }
      }
      final path = kind == 'mechanic'
          ? (Path()
              ..moveTo(26, 80)
              ..lineTo(133, 80)
              ..moveTo(227, 80)
              ..lineTo(334, 80))
          : (Path()
              ..moveTo(22, 170)
              ..lineTo(102, 170)
              ..quadraticBezierTo(114, 170, 114, 158)
              ..lineTo(114, 62)
              ..quadraticBezierTo(114, 50, 126, 50)
              ..lineTo(234, 50)
              ..quadraticBezierTo(246, 50, 246, 62)
              ..lineTo(246, 158)
              ..quadraticBezierTo(246, 170, 258, 170)
              ..lineTo(336, 170));
      canvas.drawPath(
        path,
        line
          ..strokeWidth = 14
          ..color = accent.withValues(alpha: .055),
      );
      canvas.drawPath(
        path,
        line
          ..strokeWidth = highContrast ? 8 : 6
          ..color = highContrast ? Palette.white : accent,
      );
      canvas.drawPath(
        path,
        line
          ..strokeWidth = 1.2
          ..color = Palette.white.withValues(alpha: .35),
      );
      final y = kind == 'mechanic' ? 80.0 : 170.0;
      canvas.drawCircle(Offset(22, y), 9, Paint()..color = accent);
      final arrow = Path()
        ..moveTo(19, y - 4)
        ..lineTo(26, y)
        ..lineTo(19, y + 4)
        ..close();
      canvas.drawPath(arrow, Paint()..color = Palette.paper);
      canvas.drawCircle(Offset(336, y), 10, Paint()..color = Palette.board);
      canvas.drawCircle(
        Offset(336, y),
        9,
        line
          ..strokeWidth = 2.2
          ..color = Palette.light,
      );
      canvas.drawCircle(Offset(336, y), 3, Paint()..color = Palette.light);
      if (kind == 'stars') {
        for (final p in [
          const Offset(114, 110),
          const Offset(180, 50),
          const Offset(246, 110),
        ]) {
          canvas.drawCircle(p, 13, Paint()..color = Palette.board);
          _star(canvas, p, 9);
        }
      } else if (kind == 'route' || kind == 'feel') {
        final cursor = const Offset(180, 50);
        canvas.drawCircle(
          cursor,
          17,
          Paint()..color = Palette.rust.withValues(alpha: .11),
        );
        canvas.drawCircle(
          cursor,
          13,
          line
            ..strokeWidth = 1
            ..color = Palette.white.withValues(alpha: .6),
        );
        canvas.drawCircle(cursor, 4, Paint()..color = Palette.white);
        if (haptics && kind == 'feel') {
          for (final radius in [22.0, 28.0]) {
            canvas.drawArc(
              Rect.fromCircle(center: cursor, radius: radius),
              -.8,
              1.6,
              false,
              line
                ..strokeWidth = 1
                ..color = accent.withValues(alpha: .4),
            );
            canvas.drawArc(
              Rect.fromCircle(center: cursor, radius: radius),
              math.pi - .8,
              1.6,
              false,
              line,
            );
          }
        }
      } else if (kind == 'adjust') {
        canvas.drawCircle(
          const Offset(180, 50),
          22,
          Paint()..color = Palette.board,
        );
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(180, 50), radius: 16),
          .5,
          4.7,
          false,
          line
            ..strokeWidth = 2.3
            ..color = accent,
        );
        _chevron(canvas, const Offset(189, 35), accent);
      }
    }
    canvas.restore();
  }

  void _chevron(Canvas canvas, Offset p, Color color) => canvas.drawPath(
    Path()
      ..moveTo(p.dx - 3, p.dy - 5)
      ..lineTo(p.dx + 2, p.dy)
      ..lineTo(p.dx - 3, p.dy + 5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color,
  );

  void _star(Canvas canvas, Offset p, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final d =
          Offset(math.cos(angle), math.sin(angle)) * (i.isEven ? r : r * .43) +
          p;
      i == 0 ? path.moveTo(d.dx, d.dy) : path.lineTo(d.dx, d.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.white, Palette.light, Color(0xFFB88D57)],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_LessonPainter old) =>
      kind != old.kind ||
      highContrast != old.highContrast ||
      haptics != old.haptics;
}
