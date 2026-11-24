import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';
import 'orbital_craft.dart';
import 'space_controls.dart';

enum FailurePhase { guided, offCourse, receding, lost }

/// One physical story: constant-speed guided flight, a sudden structural snap,
/// then a sideways impulse while the craft retains its forward momentum.
class FlightFailureFrame {
  const FlightFailureFrame._({
    required this.phase,
    required this.rocketPosition,
    required this.rocketVelocity,
    required this.rocketLength,
    required this.rocketAngle,
    required this.rocketOpacity,
    required this.routeOpacity,
    required this.guideProgress,
    required this.cameraPullback,
    required this.routeBroken,
    required this.routeBeforeOffset,
    required this.routeAfterOffset,
    required this.routeBeforeRotation,
    required this.routeAfterRotation,
    required this.routeScale,
    required this.retryOpacity,
  });
  final FailurePhase phase;
  final Offset rocketPosition, rocketVelocity;
  final double rocketLength, rocketAngle, rocketOpacity, routeOpacity;
  final double guideProgress, cameraPullback;
  final bool routeBroken;
  final Offset routeBeforeOffset, routeAfterOffset;
  final double routeBeforeRotation, routeAfterRotation, routeScale;
  final double retryOpacity;

  static double retryProgress(double progress) => Curves.easeInOutCubic
      .transform(((progress * 6000 - 4800) / 700).clamp(0.0, 1.0));

  factory FlightFailureFrame.at(
    double progress,
    Size size, {
    bool reducedMotion = false,
  }) {
    final seconds = progress.clamp(0.0, 1.0) * 6;
    final broken = reducedMotion || seconds >= 2;
    final drift = reducedMotion ? .95 : math.max(0.0, seconds - 2);
    final loss = (drift / 4).clamp(0.0, 1.0);
    final length = (size.shortestSide * .34).clamp(48.0, 118.0);
    final velocity = _guidedVelocity(size);
    final start = _startPoint(size);
    final snap = start + velocity * 2;
    // The lateral impulse ramps in continuously. Neither the position nor the
    // forward velocity resets at the snap, and the ship never waits to turn.
    const response = .8;
    final impulse = Offset(size.width * .025, size.height * .12);
    final responseIntegral =
        drift - response * (1 - math.exp(-drift / response));
    final point = broken
        ? snap + velocity * drift + impulse * responseIntegral
        : start + velocity * seconds;
    final movement = broken
        ? velocity + impulse * (1 - math.exp(-drift / response))
        : velocity;
    final scale = reducedMotion ? .82 : math.pow(1 - loss, 1.45).toDouble();
    final opacity = reducedMotion ? 1.0 : 1 - math.pow(loss, 2.2).toDouble();
    final phase = reducedMotion
        ? FailurePhase.lost
        : seconds < 2
        ? FailurePhase.guided
        : seconds < 3.2
        ? FailurePhase.offCourse
        : seconds < 6
        ? FailurePhase.receding
        : FailurePhase.lost;
    return FlightFailureFrame._(
      phase: phase,
      rocketPosition: point,
      rocketVelocity: reducedMotion ? Offset.zero : movement,
      rocketLength: length * scale,
      rocketAngle: math.atan2(movement.dx, -movement.dy),
      rocketOpacity: opacity,
      routeOpacity: reducedMotion ? .85 : 1 - math.pow(loss, 1.3).toDouble(),
      guideProgress: (seconds / 2).clamp(0.0, 1.0),
      cameraPullback: loss,
      routeBroken: broken,
      routeBeforeOffset: Offset(-size.width * .035, size.height * .035) * drift,
      routeAfterOffset: Offset(size.width * .045, -size.height * .025) * drift,
      routeBeforeRotation: -.11 * drift,
      routeAfterRotation: .09 * drift,
      routeScale: 1 / (1 + .10 * drift * drift),
      retryOpacity: reducedMotion ? 1 : retryProgress(progress),
    );
  }
}

// Compose the opening around the stage, not its lower-left quadrant. The ship
// crosses the optical center halfway through its straight two-second flight.
// Bounded travel also keeps a wide desktop stage from exaggerating that flight.
Offset _guidedVelocity(Size size) => Offset(
  math.min(44.0, size.width * .08),
  -math.min(20.0, size.height * .05),
);

Offset _startPoint(Size size) =>
    size.center(Offset.zero) - _guidedVelocity(size);

Offset _routeDirection(Size size) {
  final direction = _guidedVelocity(size);
  return direction / direction.distance;
}

Offset _breakPoint(Size size) =>
    _startPoint(size) +
    _guidedVelocity(size) * 2 +
    _routeDirection(size) * (size.shortestSide * .34).clamp(48.0, 118.0) * .55;

/// A full-screen loss story. Retry appears after the breakup and drift; reduced
/// motion presents the broken route and recovery action immediately.
class FlightFailureOverlay extends StatefulWidget {
  const FlightFailureOverlay({
    super.key,
    required this.onRetry,
    this.reduceMotion = false,
    this.trailColor = Palette.light,
  });
  static const departureDuration = Duration(milliseconds: 6000);
  static const snapDuration = Duration(milliseconds: 2000);
  static const retryRevealStart = Duration(milliseconds: 4800);
  static const retryRevealEnd = Duration(milliseconds: 5500);
  final VoidCallback onRetry;
  final bool reduceMotion;
  final Color trailColor;
  @override
  State<FlightFailureOverlay> createState() => _FlightFailureOverlayState();
}

class _FlightFailureOverlayState extends State<FlightFailureOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _departure = AnimationController(
    vsync: this,
    duration: FlightFailureOverlay.departureDuration,
  );
  bool _started = false, _still = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(FlightFailureOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    _still =
        widget.reduceMotion ||
        MediaQuery.reduceMotionOf(context) ||
        MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _departure.value = 1;
    } else if (!_started) {
      _departure.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _departure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlockSemantics(
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      child: FocusScope(
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          onPanUpdate: (_) {},
          excludeFromSemantics: true,
          child: CustomPaint(
            key: const ValueKey('flight-failure-cover'),
            painter: _FailureSky(_departure, still: _still),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final scaler = MediaQuery.textScalerOf(context);
                  final large = scaler.scale(16) > 27;
                  final landscape =
                      bounds.maxWidth > 600 &&
                      bounds.maxWidth > bounds.maxHeight * 1.1;
                  final padding = bounds.maxHeight < 400 ? 12.0 : 20.0;
                  final width = math.min(
                    bounds.maxWidth - padding * 2,
                    landscape ? 1080.0 : 480.0,
                  );
                  final height = math.max(0.0, bounds.maxHeight - padding * 2);
                  final recoveryWidth = landscape
                      ? math.min(width, 520.0)
                      : width;
                  final titleStyle = bookTitle(large ? 22 : 32);
                  final causeStyle = TextStyle(
                    color: Palette.white,
                    fontSize: large ? 14 : 16,
                    height: 1.4,
                  );
                  final cause = large
                      ? 'Route broken.'
                      : 'The route broke. Your rocket drifted away.';
                  const savedStyle = TextStyle(
                    color: Palette.secondary,
                    fontSize: 14,
                    height: 1.4,
                  );
                  double textHeight(String text, TextStyle style, double w) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: text,
                        style: DefaultTextStyle.of(context).style.merge(style),
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: scaler,
                    )..layout(maxWidth: w);
                    return painter.height;
                  }

                  final compact = large || landscape;
                  final buttonHeight = math.max(
                    compact ? 48.0 : 54.0,
                    scaler.scale(compact ? 14 : 15) * 1.5 + (compact ? 16 : 30),
                  );
                  final baseHeight =
                      textHeight('Signal lost', titleStyle, recoveryWidth) +
                      8 +
                      textHeight(cause, causeStyle, recoveryWidth) +
                      14 +
                      buttonHeight;
                  final savedHeight =
                      textHeight(
                        'Your route is saved.',
                        savedStyle,
                        recoveryWidth,
                      ) +
                      8;
                  final showSaved =
                      baseHeight + savedHeight + (landscape ? 0 : 110) < height;
                  final recoveryHeight =
                      baseHeight + (showSaved ? savedHeight : 0);
                  final stillGraphicSpace = (height - recoveryHeight) / 2 - 8;
                  final graphicHeight = landscape
                      ? _still
                            ? math.min(180.0, math.max(64.0, stillGraphicSpace))
                            : math.min(height, 440.0)
                      : math.min(
                          400.0,
                          math.max(64.0, height - recoveryHeight - 14),
                        );
                  final illustration = ExcludeSemantics(
                    child: SizedBox(
                      height: graphicHeight,
                      child: CustomPaint(
                        key: const ValueKey('flight-failure-rocket'),
                        painter: LostRocketPainter(
                          _departure,
                          reducedMotion: _still,
                          trailColor: widget.trailColor,
                        ),
                      ),
                    ),
                  );
                  final recovery = Column(
                    key: const ValueKey('flight-failure-recovery'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        label: 'Signal lost. The route broke and your rocket drifted away. Your route is saved. Retry appears after the drift.',
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Signal lost',
                                style: titleStyle,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cause,
                                style: causeStyle,
                                textAlign: TextAlign.center,
                              ),
                              if (showSaved) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Your route is saved.',
                                  style: savedStyle,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedBuilder(
                        animation: _departure,
                        builder: (context, _) {
                          final opacity = _still
                              ? 1.0
                              : FlightFailureFrame.retryProgress(
                                  _departure.value,
                                );
                          final available = opacity >= .5;
                          return IgnorePointer(
                            ignoring: !available,
                            child: ExcludeFocus(
                              excluding: !available,
                              child: ExcludeSemantics(
                                excluding: !available,
                                child: Opacity(
                                  opacity: opacity,
                                  child: SpaceAction(
                                    key: const ValueKey('retry-flight'),
                                    label: 'Retry',
                                    icon: Icons.replay_rounded,
                                    onPressed: available
                                        ? widget.onRetry
                                        : null,
                                    reduceMotion: _still,
                                    compact: compact,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: SizedBox(
                        width: width,
                        child: landscape
                            ? SizedBox(
                                height: height,
                                child: Stack(
                                  children: [
                                    // The flight owns the center of the screen.
                                    // Its recovery controls keep that same axis
                                    // after the ship disappears, rather than
                                    // retaining an empty illustration column.
                                    if (!_still)
                                      Center(
                                        child: SizedBox(
                                          width: width,
                                          child: illustration,
                                        ),
                                      )
                                    else if (stillGraphicSpace >= 80)
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: SizedBox(
                                          width: recoveryWidth,
                                          child: illustration,
                                        ),
                                      ),
                                    Center(
                                      child: SizedBox(
                                        width: recoveryWidth,
                                        child: AnimatedBuilder(
                                          animation: _departure,
                                          child: recovery,
                                          builder: (context, child) => Opacity(
                                            // Keep the result stationary while
                                            // the film dissolves into it.
                                            opacity: _still
                                                ? 1
                                                : Curves.easeInOutCubic
                                                      .transform(
                                                        ((_departure.value *
                                                                        6000 -
                                                                    4200) /
                                                                1000)
                                                            .clamp(0.0, 1.0),
                                                      ),
                                            alwaysIncludeSemantics: true,
                                            child: child,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  illustration,
                                  const SizedBox(height: 14),
                                  recovery,
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FailureSky extends CustomPainter {
  _FailureSky(this.departure, {required this.still})
    : super(repaint: departure);
  final Animation<double> departure;
  final bool still;
  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? 1.0 : departure.value;
    final loss = ((t - 1 / 3) / (2 / 3)).clamp(0.0, 1.0);
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = Palette.paper);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1,
          colors: [
            Color.lerp(const Color(0xFF122231), Palette.paper, loss * .8)!,
            Palette.paper,
          ],
        ).createShader(bounds),
    );
    final focus = size.center(Offset.zero);
    for (var i = 0; i < 82; i++) {
      final theta = i * 2.399963;
      final base = .12 + (i % 17) * .095;
      final depth = .35 + (i % 11) * .09;
      final speed = still ? 0.0 : t * (.32 + depth * .3);
      final distance = (base + speed) % 1.75;
      final vector = Offset(
        math.cos(theta) * size.width,
        math.sin(theta) * size.height,
      );
      final point = focus + vector * distance;
      if (!bounds.contains(point)) continue;
      final alpha = (.12 + (i % 4) * .035) * (1 - loss * .35);
      final color = (i % 13 == 0 ? Palette.light : Palette.white).withValues(
        alpha: alpha,
      );
      canvas.drawCircle(point, .45 + (i % 3) * .28, Paint()..color = color);
      if (!still && t < .94) {
        canvas.drawLine(
          point,
          point - vector * (.003 + math.sin(t * math.pi) * .012) * depth,
          Paint()
            ..color = color.withValues(alpha: alpha * .4)
            ..strokeWidth = .7,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FailureSky old) =>
      old.departure != departure || old.still != still;
}

/// Actual guided, off-course and deep-space flight, not a static failure icon.
class LostRocketPainter extends CustomPainter {
  LostRocketPainter(
    this.departure, {
    this.reducedMotion = false,
    this.trailColor = Palette.light,
  }) : super(repaint: departure);
  final Animation<double> departure;
  final bool reducedMotion;
  final Color trailColor;
  FlightFailureFrame frame(Size size) => FlightFailureFrame.at(
    departure.value,
    size,
    reducedMotion: reducedMotion,
  );
  Offset rocketPosition(Size size) => frame(size).rocketPosition;
  double rocketLength(Size size) => frame(size).rocketLength;
  double rocketOpacity(Size size) => frame(size).rocketOpacity;

  /// Intact channel endpoints share the guided flight's center and direction.
  /// Equal extensions keep the composition balanced before the fracture.
  (Offset, Offset) intactRoute(Size size) {
    final extension = _routeDirection(size) * size.shortestSide * .42;
    return (
      _startPoint(size) - extension,
      _startPoint(size) + _guidedVelocity(size) * 2 + extension,
    );
  }

  Offset fracturePoint(Size size) => _breakPoint(size);
  Rect rocketBounds(Size size) {
    final f = frame(size);
    final unit = f.rocketLength / 2.31;
    final points =
        [
          const Offset(-.77, -1.35),
          const Offset(.77, -1.35),
          const Offset(.77, .96),
          const Offset(-.77, .96),
        ].map(
          (p) =>
              f.rocketPosition +
              Offset(
                (p.dx * math.cos(f.rocketAngle) -
                        p.dy * math.sin(f.rocketAngle)) *
                    unit,
                (p.dx * math.sin(f.rocketAngle) +
                        p.dy * math.cos(f.rocketAngle)) *
                    unit,
              ),
        );
    return Rect.fromLTRB(
      points.map((p) => p.dx).reduce(math.min),
      points.map((p) => p.dy).reduce(math.min),
      points.map((p) => p.dx).reduce(math.max),
      points.map((p) => p.dy).reduce(math.max),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame(size);
    final seconds = reducedMotion ? 2.95 : departure.value * 6;
    final drift = math.max(0.0, seconds - 2);
    final extent = size.shortestSide;
    final direction = _routeDirection(size);
    final (start, end) = intactRoute(size);
    final cut = _breakPoint(size);
    final normal = Offset(-direction.dy, direction.dx);
    final width = (extent * .075).clamp(10.0, 25.0);

    void channel(Offset a, Offset b) {
      final route = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
      canvas.drawPath(
        route,
        Paint()
          ..color = const Color(0xFFB6CDE6).withValues(alpha: .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        route,
        Paint()
          ..color = const Color(0xFF31556D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 2,
      );
      canvas.drawPath(
        route,
        Paint()
          ..color = const Color(0xFFB6CDE6).withValues(alpha: .48)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width - 2,
      );
      canvas.drawPath(
        route,
        Paint()
          ..color = trailColor.withValues(alpha: .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    void piece({
      required Offset a,
      required Offset b,
      required Offset drift,
      required double turn,
      required bool before,
    }) {
      canvas.save();
      canvas.translate(cut.dx + drift.dx, cut.dy + drift.dy);
      canvas.rotate(turn);
      canvas.scale(f.routeScale);
      canvas.translate(-cut.dx, -cut.dy);
      // Each broken face has an irregular edge, not a neat pre-existing gap.
      final fracture = Path()
        ..moveTo((cut - normal * width * .6).dx, (cut - normal * width * .6).dy)
        ..lineTo(
          (cut - normal * width * .22 + direction * width * .12).dx,
          (cut - normal * width * .22 + direction * width * .12).dy,
        )
        ..lineTo(
          (cut + normal * width * .14 - direction * width * .12).dx,
          (cut + normal * width * .14 - direction * width * .12).dy,
        )
        ..lineTo(
          (cut + normal * width * .6).dx,
          (cut + normal * width * .6).dy,
        );
      final clip = Path();
      final far = before ? -direction * 2000 : direction * 2000;
      final edgeA = cut - normal * width * 1.3;
      final edgeB = cut + normal * width * 1.3;
      clip.moveTo(edgeA.dx, edgeA.dy);
      clip.lineTo((edgeA + far).dx, (edgeA + far).dy);
      clip.lineTo((edgeB + far).dx, (edgeB + far).dy);
      clip.lineTo(edgeB.dx, edgeB.dy);
      clip.close();
      canvas.save();
      canvas.clipPath(clip);
      channel(a, b);
      canvas.restore();
      canvas.drawPath(
        fracture,
        Paint()
          ..color = const Color(0xFFD5E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.bevel,
      );
      canvas.restore();
    }

    if (f.routeOpacity > 0) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: f.routeOpacity),
      );
      if (!f.routeBroken) {
        // A single line spans the whole route until the exact snap frame.
        channel(start, end);
        if (!reducedMotion) {
          final swept = (seconds * .44) % 1;
          final highlight = Offset.lerp(start, end, swept)!;
          canvas.drawLine(
            highlight - direction * width,
            highlight + direction * width,
            Paint()
              ..color = const Color(0xFFE3F4FA).withValues(alpha: .6)
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round,
          );
        }
      } else {
        piece(
          a: start,
          b: cut,
          drift: f.routeBeforeOffset,
          turn: f.routeBeforeRotation,
          before: true,
        );
        piece(
          a: cut,
          b: end,
          drift: f.routeAfterOffset,
          turn: f.routeAfterRotation,
          before: false,
        );
      }
      canvas.restore();
    }

    if (f.routeBroken && (reducedMotion || drift < 1.2)) {
      final burst = reducedMotion ? .48 : drift;
      final alpha = reducedMotion ? .55 : (1 - drift / 1.2).clamp(0.0, 1.0);
      // Small cool structural fragments: the break itself has no fire.
      for (var i = 0; i < 9; i++) {
        final theta = i * 2.399963;
        final scatter = Offset(math.cos(theta), math.sin(theta));
        final reach = width * (.25 + burst * (1.4 + i % 3 * .4));
        final point = cut + scatter * reach;
        final fragment = width * (.07 + (i % 3) * .025);
        canvas.save();
        canvas.translate(point.dx, point.dy);
        canvas.rotate(theta + burst * (i.isEven ? 1.3 : -1.1));
        canvas.drawPath(
          Path()
            ..moveTo(-fragment, -fragment * .5)
            ..lineTo(fragment, -fragment * .3)
            ..lineTo(fragment * .35, fragment)
            ..close(),
          Paint()..color = const Color(0xFFB6CDE6).withValues(alpha: alpha),
        );
        canvas.restore();
      }
    }
    if (f.rocketOpacity <= 0 || f.rocketLength < .1) return;
    final unit = f.rocketLength / 2.31;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: f.rocketOpacity),
    );
    canvas.translate(f.rocketPosition.dx, f.rocketPosition.dy);
    canvas.rotate(f.rocketAngle);
    canvas.scale(unit);
    // Engine thrust is warm; the structural snap above stays cool and fire-free.
    // After the break, power fades smoothly before the unpowered drift.
    final power = reducedMotion
        ? 0.0
        : 1 - Curves.easeInOutCubic.transform((drift / .7).clamp(0.0, 1.0));
    if (power > 0) {
      final flutter =
          math.sin(seconds * 22) * .055 + math.sin(seconds * 37 + .8) * .025;
      final length = (.84 + flutter) * (.42 + power * .58);
      final plume = Path()
        ..moveTo(-.12, .86)
        ..cubicTo(-.22, 1.10, -.13, .94 + length * .68, 0, .94 + length)
        ..cubicTo(.13, .94 + length * .68, .22, 1.10, .12, .86)
        ..close();
      final plumeBounds = Rect.fromLTWH(-.22, .86, .44, length + .08);
      canvas.drawPath(
        plume,
        Paint()
          ..color = const Color(0xFFEBC990).withValues(alpha: .34 * power)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .075),
      );
      canvas.drawPath(
        plume,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFF7DF).withValues(alpha: power),
              const Color(0xFFF4D18A).withValues(alpha: .95 * power),
              const Color(0xFFDF9D56).withValues(alpha: .2 * power),
            ],
            stops: const [0, .40, 1],
          ).createShader(plumeBounds),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-.055, .88)
          ..quadraticBezierTo(-.085, 1.08, 0, .92 + length * .62)
          ..quadraticBezierTo(.085, 1.08, .055, .88)
          ..close(),
        Paint()..color = const Color(0xFFFFF8E6).withValues(alpha: .96 * power),
      );
    }
    drawOrbitalCraft(canvas, accent: trailColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LostRocketPainter old) =>
      departure != old.departure ||
      reducedMotion != old.reducedMotion ||
      trailColor != old.trailColor;
}
