import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// The loading state, not a timed gate. The app removes it as soon as the
/// player's local route is ready. Static artwork also respects reduced motion.
class LaunchSplash extends StatelessWidget {
  const LaunchSplash({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Glowpath. Loading your route.',
    child: ExcludeSemantics(
      child: Material(
        color: Palette.paper,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              radius: .7,
              colors: [Color(0xFF101E29), Palette.paper],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: bounds.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: bounds.maxHeight < 420 ? 88 : 128,
                              child: const CustomPaint(painter: _LaunchMark()),
                            ),
                            const SizedBox(height: 24),
                            // The wordmark is artwork. The loading status below
                            // follows the player's full preferred text size.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Glowpath',
                                style: bookTitle(38).copyWith(
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Loading your route',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                letterSpacing: .4,
                                color: Palette.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LaunchMark extends CustomPainter {
  const _LaunchMark();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 128, size.height / 128);
    const center = Offset(64, 64);
    const sphere = Rect.fromLTWH(34, 34, 60, 60);
    canvas.drawCircle(
      center,
      30,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.7, -.8),
          radius: 1,
          colors: [Color(0xFF90AEB6), Color(0xFF263E4D), Color(0xFF08121E)],
          stops: [0, .45, 1],
        ).createShader(sphere),
    );
    canvas.drawArc(
      sphere,
      -math.pi * .92,
      math.pi * .68,
      false,
      Paint()
        ..color = Palette.rust.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    canvas.save();
    canvas.translate(64, 64);
    canvas.rotate(-.55);
    final orbit = Rect.fromCenter(center: Offset.zero, width: 112, height: 52);
    canvas.drawArc(
      orbit,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Palette.rust.withValues(alpha: .15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .75,
    );
    canvas.drawArc(
      orbit,
      0,
      math.pi,
      false,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF9ADDDC), Color(0xFFEBC990)],
        ).createShader(orbit)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(const Offset(56, 0), 2.6, Paint()..color = Palette.light);
    canvas.restore();
    canvas.drawCircle(
      const Offset(20, 28),
      1.0,
      Paint()..color = Palette.white.withValues(alpha: .55),
    );
    canvas.drawCircle(
      const Offset(109, 101),
      .8,
      Paint()..color = Palette.white.withValues(alpha: .35),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LaunchMark old) => false;
}
