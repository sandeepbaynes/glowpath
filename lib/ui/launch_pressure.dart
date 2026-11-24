import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// Decorative launch turbulence behind the game HUD. Only the outer edges
/// carry motion; the board, its targets and the central field stay untouched.
class LaunchPressure extends StatefulWidget {
  const LaunchPressure({
    super.key,
    required this.remaining,
    required this.total,
    required this.active,
    required this.reduceMotion,
  });

  final ValueListenable<Duration> remaining;
  final Duration total;
  final bool active, reduceMotion;

  @override
  State<LaunchPressure> createState() => _LaunchPressureState();
}

class _LaunchPressureState extends State<LaunchPressure>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final ValueNotifier<double> _phase = ValueNotifier(0);
  Duration? _lastFrame;
  bool _foreground = true;
  bool _tickersEnabled = true;
  bool _systemReduced = false;

  bool get _still => widget.reduceMotion || _systemReduced;
  bool get _visible => widget.active && _foreground && _tickersEnabled;
  double get _pressure =>
      LaunchPressurePainter.pressureFor(widget.remaining.value, widget.total);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _ticker = createTicker(_onFrame);
    widget.remaining.addListener(_syncTicker);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    _systemReduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(LaunchPressure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remaining != widget.remaining) {
      oldWidget.remaining.removeListener(_syncTicker);
      widget.remaining.addListener(_syncTicker);
    }
    _syncTicker();
  }

  void _syncTicker() {
    final animate = _visible && !_still && _pressure > 0;
    if (animate && !_ticker.isActive) {
      _lastFrame = null;
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
      _lastFrame = null;
    }
  }

  void _onFrame(Duration elapsed) {
    final last = _lastFrame;
    _lastFrame = elapsed;
    if (last == null) return;
    final dt = (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    // Integrating speed keeps positions continuous as the clock tightens.
    // Clamp a delayed frame so returning from suspension cannot jump debris.
    _phase.value += dt.clamp(0, .1) * (.45 + _pressure * 2.1);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTicker();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.remaining.removeListener(_syncTicker);
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('launch-pressure-field'),
          painter: LaunchPressurePainter(
            remaining: widget.remaining,
            total: widget.total,
            phase: _phase,
            active: _visible,
            still: _still,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

/// Repaints from the clock and visual phase without rebuilding the game tree.
class LaunchPressurePainter extends CustomPainter {
  LaunchPressurePainter({
    required this.remaining,
    required this.total,
    required this.phase,
    required this.active,
    required this.still,
  }) : super(repaint: Listenable.merge([remaining, phase]));

  final ValueListenable<Duration> remaining;
  final Duration total;
  final ValueListenable<double> phase;
  final bool active, still;

  static double pressureFor(Duration remaining, Duration total) {
    final seconds = remaining.inMicroseconds / Duration.microsecondsPerSecond;
    final window = math.min(
      15.0,
      total.inMicroseconds / Duration.microsecondsPerSecond,
    );
    if (window <= 0 || seconds <= 0 || seconds >= window) return 0;
    final linear = (1 - seconds / window).clamp(0.0, 1.0);
    return Curves.easeInQuad.transform(linear);
  }

  double get pressure => active ? pressureFor(remaining.value, total) : 0;

  @override
  void paint(Canvas canvas, Size size) {
    final urgency = pressure;
    if (urgency == 0 || size.isEmpty) return;
    final color = Color.lerp(Palette.light, const Color(0xFFE1A18C), urgency)!;
    final band = math.min(
      (size.shortestSide * .12).clamp(28.0, 100.0),
      size.shortestSide * .3,
    );
    final glow = color.withValues(alpha: .18 * urgency);
    final clear = color.withValues(alpha: 0);
    void wash(Rect rect, Alignment start, Alignment end) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: start,
            end: end,
            colors: [glow, clear],
          ).createShader(rect),
      );
    }

    wash(
      Rect.fromLTWH(0, 0, band, size.height),
      Alignment.centerLeft,
      Alignment.centerRight,
    );
    wash(
      Rect.fromLTWH(size.width - band, 0, band, size.height),
      Alignment.centerRight,
      Alignment.centerLeft,
    );
    // Full-width end bands blend over the side gradients. Cutting them off
    // at the side-band width left visible seams in both top corners.
    wash(
      Rect.fromLTWH(0, 0, size.width, band * .6),
      Alignment.topCenter,
      Alignment.bottomCenter,
    );
    wash(
      Rect.fromLTWH(0, size.height - band * .6, size.width, band * .6),
      Alignment.bottomCenter,
      Alignment.topCenter,
    );
    if (still) return;

    final edge = band * .53;
    for (var side = 0; side < 2; side++) {
      final inward = side == 0 ? 1.0 : -1.0;
      final origin = side == 0 ? 0.0 : size.width;
      for (var i = 0; i < 8; i++) {
        final progress =
            (phase.value * (.12 + (i % 3) * .018) + i * .191 + side * .37) % 1;
        final visibility = math.pow(math.sin(progress * math.pi), 2).toDouble();
        final x = origin + inward * (4 + edge * ((i * .317) % 1));
        final y = progress * (size.height + 80) - 40;
        final length = 8 + urgency * (16 + (i % 4) * 9);
        canvas.drawLine(
          Offset(x, y),
          Offset(x + inward * 2.5, y - length),
          Paint()
            ..color = color.withValues(alpha: visibility * urgency * .14)
            ..strokeWidth = i.isEven ? 1 : 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
      // A few small fragments drift past the launch field as pressure rises.
      // Their fade at both ends makes wrapping invisible.
      final fragmentStrength = ((urgency - .12) / .88).clamp(0.0, 1.0);
      for (var i = 0; i < 3; i++) {
        final progress =
            (phase.value * (.08 + i * .012) + i * .283 + side * .23) % 1;
        final visibility = math.pow(math.sin(progress * math.pi), 2).toDouble();
        final x = origin + inward * (7 + edge * ((i * .31 + .2) % 1));
        final y = progress * (size.height + 50) - 25;
        final radius = 2.5 + urgency * 3 + i * .45;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(phase.value * (.24 + i * .1) * inward + i);
        final shard = Path()
          ..moveTo(-radius, -radius * .35)
          ..lineTo(radius * .38, -radius)
          ..lineTo(radius, radius * .62)
          ..lineTo(-radius * .35, radius)
          ..close();
        canvas.drawPath(
          shard,
          Paint()
            ..color = color.withValues(
              alpha: visibility * fragmentStrength * .10,
            ),
        );
        canvas.drawLine(
          Offset(-radius, -radius * .35),
          Offset(radius * .38, -radius),
          Paint()
            ..color = color.withValues(
              alpha: visibility * fragmentStrength * .20,
            )
            ..strokeWidth = 1,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(LaunchPressurePainter old) =>
      old.remaining != remaining ||
      old.phase != phase ||
      old.total != total ||
      old.active != active ||
      old.still != still;
}
