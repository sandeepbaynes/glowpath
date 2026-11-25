import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';
import 'orbital_craft.dart';
import 'launch_flight_origin.dart';
export 'launch_flight_origin.dart'
    show CountdownFlightTracker, LaunchFlightOrigin;

/// An instrument within the puzzle, not a launch action or a separate screen.
/// The owner supplies time. This widget creates no timer or repeating ticker.
class LaunchCountdown extends StatelessWidget {
  const LaunchCountdown({
    super.key,
    required this.remaining,
    required this.total,
    required this.reducedMotion,
    required this.expired,
    required this.complete,
    this.paused = false,
    this.compact = false,
    this.prominent = false,
    this.dense = false,
    this.vertical = false,
    this.tracker,
    this.hideRocket = false,
    this.trailColor = Palette.light,
  });

  final CountdownFlightTracker? tracker;
  final bool hideRocket;
  final Duration remaining, total;
  final Color trailColor;
  final bool reducedMotion,
      expired,
      complete,
      paused,
      compact,
      prominent,
      dense,
      vertical;

  @override
  Widget build(BuildContext context) {
    final motionReduced =
        reducedMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final seconds = math.max(0, (remaining.inMilliseconds / 1000).ceil());
    final fraction = total.inMilliseconds <= 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final warm = complete || expired ? 1.0 : 1 - fraction;
    final urgent = !paused && !complete && !expired && seconds <= 10;
    final color = complete
        ? Palette.rust
        : urgent || expired
        ? const Color(0xFFEBC990)
        : Palette.light;
    final caption = complete
        ? (compact ? 'Done' : 'Launched')
        : expired
        ? 'Time up'
        : paused
        ? (compact ? 'Paused' : 'Clock paused')
        : (compact ? 'Launch' : 'Launch in');
    final spoken = complete
        ? 'Rocket launched. Route complete.'
        : expired
        ? 'Launch time reached. Route incomplete.'
        : paused
        ? '$seconds seconds remaining. Countdown paused.'
        : '$seconds seconds remaining. Rocket ${urgent ? 'at full thrust' : 'warming up'}. Launches automatically.';
    if (vertical) {
      return _VerticalCountdown(
        tracker: tracker,
        hideRocket: hideRocket,
        seconds: seconds,
        fraction: fraction,
        warm: warm,
        spoken: spoken,
        trailColor: trailColor,
        reducedMotion: motionReduced,
        urgent: urgent,
        expired: expired,
        complete: complete,
        paused: paused,
      );
    }
    if (prominent) {
      return _ProminentCountdown(
        tracker: tracker,
        hideRocket: hideRocket,
        remaining: remaining,
        seconds: seconds,
        fraction: fraction,
        warm: warm,
        spoken: spoken,
        caption: complete
            ? 'Launched'
            : expired
            ? 'Time up'
            : paused
            ? 'Paused'
            : 'Auto launch',
        trailColor: trailColor,
        reducedMotion: motionReduced,
        urgent: urgent,
        expired: expired,
        complete: complete,
        paused: paused,
        dense: dense,
      );
    }
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.6;
    final flight = _HorizontalFlightRail(
      tracker: tracker,
      hideRocket: hideRocket,
      fraction: fraction,
      warm: warm,
      color: color,
      trailColor: trailColor,
      reducedMotion: motionReduced,
      urgent: urgent,
      expired: expired,
      complete: complete,
      paused: paused,
      craftWidth: compact ? 34 : 58,
    );
    final readout = Text(
      complete ? '✓' : '${seconds}s',
      key: const ValueKey('launch-seconds'),
      style: TextStyle(
        color: color,
        fontSize: compact ? 20 : 25,
        height: compact ? 1 : 1.1,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final label = Text(
      caption,
      style: TextStyle(
        fontSize: compact ? 11 : 13,
        height: compact ? 1 : 1.3,
        color: Palette.secondary,
      ),
    );
    return Semantics(
      key: const ValueKey('launch-countdown'),
      container: true,
      label: 'Launch countdown',
      value: spoken,
      liveRegion: expired || complete,
      child: ExcludeSemantics(
        child: compact
            ? MediaQuery(
                // This compact instrument stays readable in a fixed 48px
                // slot. Its full, changing status remains spoken above.
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.25),
                ),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(child: flight),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 54,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(fit: BoxFit.scaleDown, child: label),
                            const SizedBox(height: 3),
                            FittedBox(fit: BoxFit.scaleDown, child: readout),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: largeText
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          label,
                          const SizedBox(height: 4),
                          readout,
                          const SizedBox(height: 8),
                          SizedBox(height: 54, child: flight),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: SizedBox(height: 54, child: flight)),
                          const SizedBox(width: 14),
                          SizedBox(
                            width:
                                92 * MediaQuery.textScalerOf(context).scale(1),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                label,
                                const SizedBox(height: 3),
                                readout,
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }
}

/// A vertical ascent instrument for a narrow strip beside the board. The
/// parent places it below native system indicators and supplies clock values.
/// Incoming clock updates are interpolated briefly; there is no idle ticker.
class _VerticalCountdown extends StatelessWidget {
  const _VerticalCountdown({
    required this.tracker,
    required this.hideRocket,
    required this.seconds,
    required this.fraction,
    required this.warm,
    required this.spoken,
    required this.trailColor,
    required this.reducedMotion,
    required this.urgent,
    required this.expired,
    required this.complete,
    required this.paused,
  });

  final CountdownFlightTracker? tracker;
  final bool hideRocket;
  final int seconds;
  final double fraction, warm;
  final String spoken;
  final Color trailColor;
  final bool reducedMotion, urgent, expired, complete, paused;

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? Palette.rust
        : paused
        ? Palette.secondary
        : expired
        ? const Color(0xFFE5A18D)
        : urgent
        ? const Color(0xFFF2C27B)
        : Palette.light;
    final caption = complete
        ? 'LAUNCHED'
        : expired
        ? 'TIME UP'
        : paused
        ? 'PAUSED'
        : 'LAUNCH';
    return Semantics(
      key: const ValueKey('launch-countdown'),
      container: true,
      label: 'Launch countdown',
      value: spoken,
      liveRegion: expired || complete,
      child: ExcludeSemantics(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: 1.25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      complete ? '✓' : '${seconds}s',
                      key: const ValueKey('launch-seconds'),
                      style: TextStyle(
                        color: color,
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      caption,
                      style: TextStyle(
                        color: paused || urgent || expired
                            ? color
                            : Palette.secondary,
                        fontSize: 9,
                        height: 1,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final craftWidth = math.min(54.0, bounds.maxWidth);
                    final craftHeight = craftWidth * 58 / 54;
                    final top = craftHeight / 2 + 2;
                    final bottom = math.max(
                      top,
                      bounds.maxHeight - craftHeight / 2 - 6,
                    );
                    return TweenAnimationBuilder<double>(
                      tween: Tween(end: complete || expired ? 0 : fraction),
                      duration: reducedMotion || paused || expired || complete
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      curve: Curves.linear,
                      builder: (context, value, child) {
                        final centerY = top + (bottom - top) * value;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              key: const ValueKey('launch-time-rail'),
                              painter: _AscentRailPainter(
                                fraction: value,
                                color: color,
                                top: top,
                                bottom: bottom,
                                showGlow: !reducedMotion && !paused,
                              ),
                            ),
                            Positioned(
                              left: (bounds.maxWidth - craftWidth) / 2,
                              top: centerY - craftHeight / 2,
                              width: craftWidth,
                              height: craftHeight,
                              child: child!,
                            ),
                          ],
                        );
                      },
                      child: RepaintBoundary(
                        key: const ValueKey('countdown-rocket'),
                        child: RotatedBox(
                          key: const ValueKey(
                            'vertical-launch-craft-orientation',
                          ),
                          quarterTurns: 3,
                          child: Opacity(
                            opacity: hideRocket ? 0 : 1,
                            child: CountdownFlightAnchor(
                              tracker: tracker,
                              heat: paused ? warm * .3 : warm,
                              urgent: urgent || complete || expired,
                              trailColor: trailColor,
                              child: CustomPaint(
                                painter: CountdownRocketPainter(
                                  heat: paused ? warm * .3 : warm,
                                  trailColor: trailColor,
                                  urgent: urgent || complete || expired,
                                  reducedMotion: reducedMotion,
                                  complete: complete,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AscentRailPainter extends CustomPainter {
  const _AscentRailPainter({
    required this.fraction,
    required this.color,
    required this.top,
    required this.bottom,
    required this.showGlow,
  });

  final double fraction, top, bottom;
  final Color color;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final y = top + (bottom - top) * fraction;
    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      Paint()
        ..color = Palette.line.withValues(alpha: .7)
        ..strokeWidth = 1,
    );
    // Thirty small launch divisions keep the quiet side rail legible at a
    // glance. Filled travel grows upward behind the climbing craft.
    for (var tick = 0; tick <= 30; tick++) {
      final tickY = top + (bottom - top) * tick / 30;
      final major = tick % 5 == 0;
      canvas.drawLine(
        Offset(x - (major ? 7 : 3), tickY),
        Offset(x + (major ? 7 : 3), tickY),
        Paint()
          ..color = (tickY >= y ? color : Palette.secondary).withValues(
            alpha: major ? .35 : .16,
          )
          ..strokeWidth = .8,
      );
    }
    if (y < bottom) {
      final travel = Rect.fromLTRB(x - 2, y, x + 2, bottom);
      canvas.drawLine(
        Offset(x, bottom),
        Offset(x, y),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: .85),
              color.withValues(alpha: .12),
            ],
          ).createShader(travel)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    if (showGlow) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y + 9), width: 12, height: 24),
        Paint()
          ..color = color.withValues(alpha: .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    canvas.drawCircle(
      Offset(x, top),
      4,
      Paint()
        ..color = color.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (final pad in [(10.0, 7.0), (5.0, 11.0)]) {
      canvas.drawLine(
        Offset(x - pad.$1, bottom + pad.$2),
        Offset(x + pad.$1, bottom + pad.$2),
        Paint()
          ..color = Palette.secondary.withValues(alpha: .45)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_AscentRailPainter old) =>
      fraction != old.fraction ||
      color != old.color ||
      top != old.top ||
      bottom != old.bottom ||
      showGlow != old.showGlow;
}

/// The mobile launch instrument occupies a fixed 76px (64px in dense mode).
/// Only the rocket artwork pulses; the numeral and the surrounding board stay
/// anchored. Pressure is derived from the owner's clock, never an idle ticker.
class _ProminentCountdown extends StatelessWidget {
  const _ProminentCountdown({
    required this.tracker,
    required this.hideRocket,
    required this.remaining,
    required this.seconds,
    required this.fraction,
    required this.warm,
    required this.spoken,
    required this.caption,
    required this.trailColor,
    required this.reducedMotion,
    required this.urgent,
    required this.expired,
    required this.complete,
    required this.paused,
    required this.dense,
  });

  final CountdownFlightTracker? tracker;
  final bool hideRocket;
  final Duration remaining;
  final int seconds;
  final double fraction, warm;
  final String spoken, caption;
  final Color trailColor;
  final bool reducedMotion, urgent, expired, complete, paused, dense;

  @override
  Widget build(BuildContext context) {
    final pressure = (!paused && !complete && !expired)
        ? ((15 - remaining.inMilliseconds / 1000) / 15).clamp(0.0, 1.0)
        : 0.0;
    final color = complete || paused
        ? Palette.rust
        : expired
        ? const Color(0xFFE5A18D)
        : Color.lerp(Palette.light, const Color(0xFFE5A18D), pressure)!;
    final pulse = reducedMotion || pressure == 0
        ? 1.0
        : 1 +
              pressure *
                  .025 *
                  (1 +
                      math.sin(remaining.inMilliseconds / 1000 * math.pi * 2)) /
                  2;
    final height = dense ? 64.0 : 76.0;
    return Semantics(
      key: const ValueKey('launch-countdown'),
      container: true,
      label: 'Launch countdown',
      value: spoken,
      liveRegion: expired || complete,
      child: ExcludeSemantics(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: 1.25),
          ),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: dense ? 46 : 56,
                  child: _HorizontalFlightRail(
                    tracker: tracker,
                    hideRocket: hideRocket,
                    fraction: fraction,
                    warm: warm,
                    color: color,
                    trailColor: trailColor,
                    reducedMotion: reducedMotion,
                    urgent: urgent,
                    expired: expired,
                    complete: complete,
                    paused: paused,
                    craftWidth: dense ? 52 : 64,
                    pulse: pulse,
                  ),
                ),
                Positioned(
                  top: 1,
                  left: 0,
                  right: 0,
                  height: dense ? 30 : 35,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          caption.toUpperCase(),
                          style: TextStyle(
                            color: pressure > .3 ? color : Palette.secondary,
                            fontSize: 10,
                            height: 1,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: dense ? 92 : 106,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              if (!complete) ...[
                                Text(
                                  'T−',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: dense ? 17 : 20,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 7),
                              ],
                              Text(
                                complete ? '✓' : '${seconds}s',
                                key: const ValueKey('launch-seconds'),
                                style: TextStyle(
                                  color: color,
                                  fontSize: dense ? 32 : 40,
                                  height: 1,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The fold's ascent rail turned sideways: the rocket is the moving marker,
/// with completed travel behind it. Interpolation follows owner clock updates
/// and settles between 200ms clock updates; paused and reduced-motion updates
/// settle immediately.
class _HorizontalFlightRail extends StatelessWidget {
  const _HorizontalFlightRail({
    required this.tracker,
    required this.hideRocket,
    required this.fraction,
    required this.warm,
    required this.color,
    required this.trailColor,
    required this.reducedMotion,
    required this.urgent,
    required this.expired,
    required this.complete,
    required this.paused,
    required this.craftWidth,
    this.pulse = 1,
  });

  final CountdownFlightTracker? tracker;
  final bool hideRocket;
  final double fraction, warm, craftWidth, pulse;
  final Color color, trailColor;
  final bool reducedMotion, urgent, expired, complete, paused;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: const ValueKey('horizontal-launch-flight'),
    builder: (context, bounds) {
      // Leave space for the pressure pulse at both ends without changing the
      // rail's bounds or the readout's position as the launch approaches.
      final width = math.max(
        0.0,
        math.min(
          craftWidth,
          math.min(bounds.maxWidth - 6, (bounds.maxHeight - 6) * 58 / 54),
        ),
      );
      final height = width * 54 / 58;
      final left = width / 2 + 3;
      final right = math.max(left, bounds.maxWidth - width / 2 - 3);
      final still = reducedMotion || paused || expired || complete;
      return TweenAnimationBuilder<double>(
        tween: Tween(end: complete || expired ? 0 : fraction),
        duration: still ? Duration.zero : const Duration(milliseconds: 90),
        curve: Curves.linear,
        builder: (context, value, child) {
          final centerX = right - (right - left) * value;
          return Stack(
            fit: StackFit.expand,
            children: [
              RotatedBox(
                key: const ValueKey('launch-time-rail'),
                quarterTurns: 1,
                child: CustomPaint(
                  painter: _AscentRailPainter(
                    fraction: value,
                    color: color,
                    top: bounds.maxWidth - right,
                    bottom: bounds.maxWidth - left,
                    showGlow: !reducedMotion && !paused,
                  ),
                ),
              ),
              Positioned(
                left: centerX - width / 2,
                top: (bounds.maxHeight - height) / 2,
                width: width,
                height: height,
                child: child!,
              ),
            ],
          );
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: pulse),
          duration: still ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Transform.scale(
            key: const ValueKey('launch-pressure-pulse'),
            scale: value,
            child: child,
          ),
          child: RepaintBoundary(
            key: const ValueKey('countdown-rocket'),
            child: Opacity(
              opacity: hideRocket ? 0 : 1,
              child: CountdownFlightAnchor(
                tracker: tracker,
                heat: paused ? warm * .3 : warm,
                urgent: urgent || complete || expired,
                trailColor: trailColor,
                child: CustomPaint(
                  painter: CountdownRocketPainter(
                    heat: paused ? warm * .3 : warm,
                    trailColor: trailColor,
                    urgent: urgent || complete || expired,
                    reducedMotion: reducedMotion,
                    complete: complete,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Fixed silhouette with directional lighting. Heat changes exhaust length and
/// color gradually with the countdown, without camera movement or flickering.
class CountdownRocketPainter extends CustomPainter {
  const CountdownRocketPainter({
    required this.heat,
    required this.urgent,
    required this.reducedMotion,
    required this.complete,
    this.trailColor = Palette.light,
    this.enginePower = 1,
  });

  final double heat, enginePower;
  final Color trailColor;
  final bool urgent, reducedMotion, complete;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 58, size.height / 54);
    canvas.translate(0, 27);
    final warmth = heat.clamp(0.0, 1.0);
    final flame = 3 + warmth * 11 + (urgent ? 4 : 0);
    final exhaust = Path()
      ..moveTo(24, -3.5)
      ..quadraticBezierTo(14, -4.5 - warmth * 2, 24 - flame, 0)
      ..quadraticBezierTo(14, 4.5 + warmth * 2, 24, 3.5)
      ..close();
    final flameBounds = Rect.fromLTRB(24 - flame, -7, 25, 7);
    if ((warmth > .02 || urgent) && enginePower > 0) {
      canvas.saveLayer(
        const Rect.fromLTWH(-15, -27, 90, 54),
        Paint()
          ..color = Colors.white.withValues(alpha: enginePower.clamp(0.0, 1.0)),
      );
      if (!reducedMotion) {
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(17, 0),
            width: 12 + warmth * 24,
            height: 7 + warmth * 12,
          ),
          Paint()
            ..color = trailColor.withValues(alpha: .04 + warmth * .10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawPath(
        exhaust,
        Paint()
          ..shader = LinearGradient(
            colors: [
              trailColor.withValues(alpha: .25 + warmth * .55),
              trailColor,
              const Color(0xFFFFF5D9),
            ],
            stops: const [0, .6, 1],
          ).createShader(flameBounds),
      );
      canvas.drawLine(
        Offset(24 - flame * .55, 0),
        const Offset(25, 0),
        Paint()
          ..strokeWidth = 1.2 + warmth
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFF7DF),
      );
      canvas.restore();
    }

    canvas.translate(36, 0);
    canvas.rotate(math.pi / 2);
    canvas.scale(13.2);
    drawOrbitalCraft(canvas, accent: trailColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CountdownRocketPainter old) =>
      trailColor != old.trailColor ||
      heat != old.heat ||
      enginePower != old.enginePower ||
      urgent != old.urgent ||
      reducedMotion != old.reducedMotion ||
      complete != old.complete;
}
