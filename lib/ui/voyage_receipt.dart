import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// A quiet flight receipt leaves the universe as the main visual reward.
class VoyageReceipt extends StatelessWidget {
  const VoyageReceipt({
    super.key,
    required this.points,
    required this.turns,
    required this.assisted,
    this.elapsed,
    this.personalBest = false,
  });
  final int points, turns;
  final bool assisted;
  final Duration? elapsed;
  final bool personalBest;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ExcludeSemantics(
          child: SizedBox.square(
            dimension: 44,
            child: CustomPaint(painter: _SignalSeal()),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Signal delivered',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$points points${elapsed == null ? '' : '  ·  ${(elapsed!.inMilliseconds / 1000).toStringAsFixed(1)}s'}  ·  $turns ${turns == 1 ? 'turn' : 'turns'}${assisted ? '  ·  Assisted' : ''}${personalBest ? '  ·  Personal best' : ''}',
                key: const ValueKey('move-count'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Palette.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SignalSeal extends CustomPainter {
  const _SignalSeal();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final face = Rect.fromCircle(center: center, radius: 20);
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.5, -.5),
          colors: [Palette.rust.withValues(alpha: .14), Palette.paper],
        ).createShader(face),
    );
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = Palette.rust.withValues(alpha: .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65,
    );
    canvas.drawArc(
      face.deflate(3),
      -.8,
      math.pi * 1.28,
      false,
      Paint()
        ..color = Palette.rust.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    canvas.drawPath(
      Path()
        ..moveTo(14, 23)
        ..lineTo(20, 29)
        ..lineTo(31, 16),
      Paint()
        ..color = Palette.rust
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < 3; i++) {
      final angle = -1.12 + i * .26;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * 20,
        1.2,
        Paint()..color = Palette.light,
      );
    }
  }

  @override
  bool shouldRepaint(_SignalSeal oldDelegate) => false;
}
