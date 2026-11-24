import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// A navigation beacon registered to the real camera cutout. The hardware is
/// its center; only the surrounding orbital marks are drawn. No interaction,
/// camera access, independent animation clock or additional semantics.
class CutoutBeacon extends StatelessWidget {
  const CutoutBeacon({
    super.key,
    required this.camera,
    required this.systemOcclusions,
    required this.remaining,
    required this.total,
    required this.reducedMotion,
    this.paused = false,
    this.complete = false,
    this.trailColor = Palette.light,
  });

  final Rect camera;
  final List<Rect> systemOcclusions;
  final Duration remaining, total;
  final bool reducedMotion, paused, complete;
  final Color trailColor;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    key: const ValueKey('cutout-beacon'),
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: CutoutBeaconPainter(
            camera: camera,
            systemOcclusions: systemOcclusions,
            remaining: remaining,
            total: total,
            reducedMotion:
                reducedMotion ||
                MediaQuery.disableAnimationsOf(context) ||
                MediaQuery.reduceMotionOf(context),
            paused: paused,
            complete: complete,
            trailColor: trailColor,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class CutoutBeaconPainter extends CustomPainter {
  const CutoutBeaconPainter({
    required this.camera,
    required this.systemOcclusions,
    required this.remaining,
    required this.total,
    required this.reducedMotion,
    required this.paused,
    required this.complete,
    required this.trailColor,
  });

  final Rect camera;
  final List<Rect> systemOcclusions;
  final Duration remaining, total;
  final bool reducedMotion, paused, complete;
  final Color trailColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (!camera.isFinite || camera.isEmpty || size.isEmpty) return;
    var drawable = Path()..addRect(Offset.zero & size);
    // Difference each region independently. An even-odd combined path would
    // accidentally expose the camera where its frame overlaps the status area.
    for (final region in [camera.inflate(2), ...systemOcclusions]) {
      if (!region.isFinite || region.isEmpty) continue;
      drawable = Path.combine(
        PathOperation.difference,
        drawable,
        Path()..addRect(region.inflate(1)),
      );
    }
    canvas.save();
    canvas.clipPath(drawable, doAntiAlias: false);

    final center = camera.center;
    final holeRadius = math.max(camera.width, camera.height) * .5;
    final radius = holeRadius + 35;
    // The visible crescent sits on the content-facing side of the cutout.
    // Mirroring also keeps the artwork coherent if the display rotates.
    final facesLeft = center.dx > size.width * .5;
    final axis = facesLeft ? math.pi : 0.0;
    const sweep = 1.25;
    final start = axis - sweep * .5;
    final elapsed = total.inMicroseconds <= 0
        ? 0.0
        : (1 - remaining.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    final progress = complete ? 1.0 : elapsed;
    final urgent = !paused && !complete && remaining.inSeconds <= 10;
    final tint = Color.lerp(Palette.rust, trailColor, urgent ? .75 : .2)!;
    final intensity = paused ? .52 : 1.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Two interrupted orbits read as a small navigation instrument, avoiding
    // a heavy frame around the system's taller time/Wi-Fi region.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      stroke
        ..strokeWidth = 1.1
        ..color = tint.withValues(alpha: .30 * intensity),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 6),
      start + .12,
      sweep - .24,
      false,
      stroke
        ..strokeWidth = .7
        ..color = tint.withValues(alpha: .12 * intensity),
    );

    for (var i = 0; i <= 6; i++) {
      final angle = start + sweep * i / 6;
      final radial = Offset(math.cos(angle), math.sin(angle));
      final length = i == 3 ? 5.0 : 2.5;
      canvas.drawLine(
        center + radial * (radius + 10),
        center + radial * (radius + 10 + length),
        stroke
          ..strokeWidth = .8
          ..color = tint.withValues(alpha: .25 * intensity),
      );
    }

    // A single relay moves with supplied launch progress. Reduced-motion
    // users get a stationary alignment marker instead of orbital movement.
    final markerAngle = reducedMotion
        ? axis
        : start + sweep * (facesLeft ? progress : 1 - progress);
    final marker =
        center + Offset(math.cos(markerAngle), math.sin(markerAngle)) * radius;
    final fill = Paint()..color = tint.withValues(alpha: .08 * intensity);
    canvas.drawCircle(marker, 6, fill);
    canvas.drawCircle(
      marker,
      2.2,
      fill..color = tint.withValues(alpha: .85 * intensity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CutoutBeaconPainter old) =>
      old.camera != camera ||
      !listEquals(old.systemOcclusions, systemOcclusions) ||
      old.remaining != remaining ||
      old.total != total ||
      old.reducedMotion != reducedMotion ||
      old.paused != paused ||
      old.complete != complete ||
      old.trailColor != trailColor;
}
