import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// Inert launch artwork. The caller owns timing; both progress values are 0–1.
/// No animation, timer, controller, or image asset is created by this widget.
class RocketLaunchScene extends StatelessWidget {
  const RocketLaunchScene({
    super.key,
    this.launchProgress = 0,
    this.countdownProgress = 0,
    this.countdown,
    this.reducedMotion = false,
    this.height = 220,
  });

  final double launchProgress;
  final double countdownProgress;
  final int? countdown;
  final bool reducedMotion;
  final double height;

  @override
  Widget build(BuildContext context) {
    final still =
        reducedMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final label = launchProgress > 0
        ? 'Rocket launching'
        : countdown != null
        ? 'Launch countdown: $countdown'
        : 'Rocket ready on the launch pad';
    return Semantics(
      label: label,
      liveRegion: countdown != null,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _LaunchPainter(
                        launchProgress.clamp(0.0, 1.0),
                        countdownProgress.clamp(0.0, 1.0),
                        still,
                      ),
                    ),
                  ),
                ),
                if (countdown != null && launchProgress == 0)
                  Positioned(
                    right: 18,
                    top: 18,
                    child: Column(
                      children: [
                        const Text(
                          'T MINUS',
                          style: TextStyle(
                            fontFamily: 'Atkinson',
                            fontSize: 11,
                            letterSpacing: 2,
                            color: Palette.secondary,
                          ),
                        ),
                        Text(
                          '$countdown',
                          style: const TextStyle(
                            fontFamily: 'Atkinson',
                            fontSize: 38,
                            height: 1.1,
                            color: Palette.light,
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

/// Astronomical navigation: one-based levels, selectable through
/// [highestUnlocked]. Owns a vertical scroll area, but never advances a level.
class GalaxyRouteMap extends StatefulWidget {
  const GalaxyRouteMap({
    super.key,
    required this.highestUnlocked,
    required this.currentLevel,
    required this.onSelect,
    this.totalLevels = 15,
    this.reducedMotion = false,
    this.height = 500,
  });

  final int highestUnlocked;
  final int currentLevel;
  final int totalLevels;
  final ValueChanged<int> onSelect;
  final bool reducedMotion;
  final double height;

  @override
  State<GalaxyRouteMap> createState() => _GalaxyRouteMapState();
}

class _GalaxyRouteMapState extends State<GalaxyRouteMap> {
  final _scroll = ScrollController();
  String? _positionedLayout;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, widget.totalLevels);
    final current = widget.currentLevel.clamp(1, total);
    final unlocked = widget.highestUnlocked.clamp(1, total);
    final still =
        widget.reducedMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final height = constraints.hasBoundedHeight
            ? math.min(widget.height, constraints.maxHeight)
            : widget.height;
        final extent = math.max(height, total * 104.0 + 160);
        final points = <Offset>[
          for (var level = 1; level <= total; level++)
            _routePosition(level, total, width),
        ];
        final layout = '$current/$total/$width/$height';
        if (_positionedLayout != layout) {
          _positionedLayout = layout;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                !_scroll.hasClients ||
                _positionedLayout != layout) {
              return;
            }
            final target = (points[current - 1].dy - height * .63).clamp(
              0.0,
              _scroll.position.maxScrollExtent,
            );
            _scroll.jumpTo(target);
          });
        }
        return Semantics(
          label:
              'Galaxy route map. Level $current selected. '
              'Levels 1 through $unlocked available.',
          container: true,
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: AnimatedBuilder(
                          animation: _scroll,
                          builder: (context, _) => CustomPaint(
                            painter: _GalaxyFieldPainter(
                              still || !_scroll.hasClients ? 0 : _scroll.offset,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    controller: _scroll,
                    child: SizedBox(
                      width: width,
                      height: extent,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ExcludeSemantics(
                                child: CustomPaint(
                                  painter: _RoutePainter(points, unlocked),
                                ),
                              ),
                            ),
                          ),
                          for (var i = 0; i < total; i++)
                            Positioned(
                              left: points[i].dx - 40,
                              top: points[i].dy - 34,
                              width: 80,
                              height: 88,
                              child: _OrbitNode(
                                key: ValueKey('galaxy-level-${i + 1}'),
                                level: i + 1,
                                unlocked: i + 1 <= unlocked,
                                completed: i + 1 < unlocked,
                                current: i + 1 == current,
                                onSelect: () => widget.onSelect(i + 1),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Offset _routePosition(int level, int total, double width) => Offset(
  width / 2 +
      math.sin(level * 1.07 - .5) *
          math.min(96.0, math.max(0.0, (width - 96) * .34)),
  (total - level) * 104.0 + 86,
);

class _OrbitNode extends StatefulWidget {
  const _OrbitNode({
    super.key,
    required this.level,
    required this.unlocked,
    required this.completed,
    required this.current,
    required this.onSelect,
  });
  final int level;
  final bool unlocked, completed, current;
  final VoidCallback onSelect;

  @override
  State<_OrbitNode> createState() => _OrbitNodeState();
}

class _OrbitNodeState extends State<_OrbitNode> {
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final status = widget.current
        ? 'current destination'
        : widget.completed
        ? 'completed'
        : widget.unlocked
        ? 'ready to launch'
        : 'locked';
    return Semantics(
      button: true,
      enabled: widget.unlocked,
      selected: widget.current,
      label: 'Level ${widget.level}, $status',
      onTap: widget.unlocked ? widget.onSelect : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: widget.unlocked,
          mouseCursor: widget.unlocked
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (widget.unlocked) widget.onSelect();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.unlocked ? widget.onSelect : null,
            onTapDown: widget.unlocked
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: CustomPaint(
              painter: _OrbitNodePainter(
                widget.current,
                widget.unlocked,
                widget.completed,
                _focused || _hovered,
                _pressed,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 66,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${widget.level}',
                          style: TextStyle(
                            fontFamily: 'Atkinson',
                            color: widget.current
                                ? Palette.paper
                                : Palette.white,
                            fontSize: 21,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.current)
                    const Icon(
                      Icons.navigation_rounded,
                      size: 18,
                      color: Palette.light,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchPainter extends CustomPainter {
  const _LaunchPainter(this.launch, this.countdown, this.still);
  final double launch, countdown;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(size.width / 340, size.height / 220);
    final pad = Offset(size.width * .49, size.height * .83);
    final lift = still
        ? (launch > 0 ? 65.0 * unit : 0.0)
        : math.pow(launch, 1.7).toDouble() * size.height * 1.35;
    final ignition = launch > 0
        ? 1.0
        : ((countdown - .72) / .28).clamp(0.0, 1.0);
    final ground = Rect.fromCenter(
      center: pad + Offset(0, 7 * unit),
      width: 220 * unit,
      height: 39 * unit,
    );

    // Distant moon, stars, and a low elliptical horizon establish depth.
    canvas.drawCircle(
      Offset(size.width * .18, size.height * .18),
      16 * unit,
      Paint()..color = Palette.line.withValues(alpha: .25),
    );
    canvas.drawCircle(
      Offset(size.width * .17, size.height * .16),
      16 * unit,
      Paint()..color = Palette.paper,
    );
    for (var i = 0; i < 19; i++) {
      final x = ((i * 73 + 19) % 337) / 337 * size.width;
      final y = ((i * 41 + 7) % 131) / 190 * size.height;
      canvas.drawCircle(
        Offset(x, y),
        i % 4 == 0 ? 1.1 : .65,
        Paint()..color = Palette.secondary.withValues(alpha: .23),
      );
    }
    canvas.drawOval(
      ground.inflate(16 * unit),
      Paint()..color = Palette.board.withValues(alpha: .48),
    );
    canvas.drawOval(ground, Paint()..color = Palette.tile);
    canvas.drawOval(ground.deflate(7 * unit), Paint()..color = Palette.board);
    canvas.drawOval(
      ground.deflate(9 * unit),
      Paint()
        ..color = Palette.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (final x in [-76.0, -48.0, 48.0, 76.0]) {
      canvas.drawLine(
        pad + Offset(x * unit, 0),
        pad + Offset(x * 1.1 * unit, 18 * unit),
        Paint()
          ..color = Palette.line
          ..strokeWidth = unit,
      );
    }
    final platform = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pad, width: 106 * unit, height: 16 * unit),
      Radius.circular(3 * unit),
    );
    canvas.drawRRect(
      platform.shift(Offset(0, 4 * unit)),
      Paint()..color = const Color(0xFF050A14),
    );
    canvas.drawRRect(platform, Paint()..color = Palette.line);
    canvas.drawLine(
      pad + Offset(-49 * unit, -5 * unit),
      pad + Offset(49 * unit, -5 * unit),
      Paint()
        ..color = Palette.secondary.withValues(alpha: .5)
        ..strokeWidth = unit,
    );

    // Service gantry stays behind the rocket as the mission departs.
    final gantry = Paint()
      ..color = Palette.line
      ..strokeWidth = 3 * unit;
    final left = pad.dx - 48 * unit;
    canvas.drawLine(
      Offset(left, pad.dy - 8 * unit),
      Offset(left, pad.dy - 99 * unit),
      gantry,
    );
    canvas.drawLine(
      Offset(left + 12 * unit, pad.dy - 8 * unit),
      Offset(left + 12 * unit, pad.dy - 99 * unit),
      gantry,
    );
    for (var i = 0; i < 5; i++) {
      final y = pad.dy - (13 + i * 17) * unit;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + 12 * unit, y - 14 * unit),
        Paint()
          ..color = Palette.line
          ..strokeWidth = unit,
      );
    }
    canvas.drawLine(
      Offset(left, pad.dy - 79 * unit),
      Offset(pad.dx - 13 * unit, pad.dy - 79 * unit),
      gantry,
    );

    // Finite deterministic vapor: progressive expansion, never an idle loop.
    final vapor = still
        ? (launch > 0
              ? .7
              : countdown > 0
              ? .3
              : 0.0)
        : math.max(countdown * .45, math.sin(launch * math.pi) * .95);
    for (var i = 0; i < 10; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final spread = (12 + i * 5 + vapor * 42) * unit;
      final position =
          pad + Offset(side * spread, (-4 - (i % 3) * 5 - vapor * 13) * unit);
      canvas.drawCircle(
        position,
        (3 + vapor * 11 + i % 3) * unit,
        Paint()..color = Palette.pipe.withValues(alpha: vapor * .13),
      );
    }

    final rocket = Offset(pad.dx, pad.dy - 15 * unit - lift);
    canvas.save();
    canvas.translate(rocket.dx, rocket.dy);
    canvas.scale(unit);
    if (ignition > 0) {
      final flameLength =
          (20 + 45 * (still ? .6 : launch.clamp(0.0, .6)) + ignition * 12);
      final flame = Path()
        ..moveTo(-8, -2)
        ..quadraticBezierTo(-15, 15, 0, flameLength)
        ..quadraticBezierTo(14, 13, 8, -2)
        ..close();
      canvas.drawPath(
        flame,
        Paint()
          ..color = const Color(0xFFEF9563).withValues(alpha: ignition * .85),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-5, -2)
          ..quadraticBezierTo(-6, 12, 0, flameLength * .7)
          ..quadraticBezierTo(6, 12, 5, -2)
          ..close(),
        Paint()..color = Palette.light.withValues(alpha: ignition),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-3, -2)
          ..lineTo(0, flameLength * .34)
          ..lineTo(3, -2)
          ..close(),
        Paint()..color = Palette.white.withValues(alpha: ignition),
      );
    }
    final fins = Path()
      ..moveTo(-11, -32)
      ..lineTo(-24, -9)
      ..lineTo(-23, 3)
      ..lineTo(-8, -4)
      ..lineTo(8, -4)
      ..lineTo(23, 3)
      ..lineTo(24, -9)
      ..lineTo(11, -32)
      ..close();
    canvas.drawPath(fins, Paint()..color = Palette.rust);
    final body = Path()
      ..moveTo(0, -106)
      ..cubicTo(16, -89, 18, -61, 13, -6)
      ..quadraticBezierTo(0, 2, -13, -6)
      ..cubicTo(-18, -61, -16, -89, 0, -106)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB4C4D8), Palette.white, Color(0xFF7C90AC)],
          stops: [0, .4, 1],
        ).createShader(const Rect.fromLTWH(-18, -106, 36, 106)),
    );
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      const Rect.fromLTWH(-20, -107, 40, 29),
      Paint()..color = Palette.rust,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-20, -23, 40, 7),
      Paint()..color = Palette.rust,
    );
    canvas.drawLine(
      const Offset(10, -76),
      const Offset(9, -29),
      Paint()
        ..color = Palette.paper.withValues(alpha: .14)
        ..strokeWidth = 2,
    );
    canvas.restore();
    canvas.drawCircle(const Offset(0, -61), 9.5, Paint()..color = Palette.line);
    canvas.drawCircle(
      const Offset(0, -61),
      6.8,
      Paint()..color = Palette.paper,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, -61), radius: 5),
      math.pi,
      math.pi * .65,
      false,
      Paint()
        ..color = Palette.rust
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, -7, 18, 7),
        const Radius.circular(2),
      ),
      Paint()..color = Palette.line,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LaunchPainter old) =>
      old.launch != launch || old.countdown != countdown || old.still != still;
}

class _GalaxyFieldPainter extends CustomPainter {
  const _GalaxyFieldPainter(this.scrollOffset);
  final double scrollOffset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Palette.paper);
    final center = Offset(
      size.width * .78,
      size.height * .23 - (scrollOffset * .045) % 80,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.55);
    for (var i = 5; i >= 0; i--) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * (1.1 + i * .2),
          height: 38 + i * 23,
        ),
        Paint()
          ..color = Color.lerp(
            Palette.rust,
            Palette.line,
            .6,
          )!.withValues(alpha: .018 + (5 - i) * .003),
      );
    }
    canvas.restore();
    for (var i = 0; i < 68; i++) {
      final x = ((i * 79 + 37) % 359) / 359 * size.width;
      final y =
          (((i * 113 + 19) / 179 * size.height) -
              scrollOffset * (i.isEven ? .08 : .15)) %
          size.height;
      final color = (i % 9 == 0 ? Palette.light : Palette.pipe).withValues(
        alpha: i % 5 == 0 ? .55 : .22,
      );
      canvas.drawCircle(
        Offset(x, y),
        i % 5 == 0 ? 1.2 : .7,
        Paint()..color = color,
      );
    }
    final planet = Offset(
      size.width * .1,
      size.height * .73 - (scrollOffset * .035) % 50,
    );
    final radius = math.min(32.0, size.width * .09);
    canvas.drawCircle(
      planet,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.7, -.5),
          colors: [Palette.line, Palette.paper],
          radius: 1.2,
        ).createShader(Rect.fromCircle(center: planet, radius: radius)),
    );
    canvas.drawArc(
      Rect.fromCircle(center: planet, radius: radius),
      math.pi,
      math.pi * .55,
      false,
      Paint()
        ..color = Palette.secondary.withValues(alpha: .3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GalaxyFieldPainter old) =>
      old.scrollOffset != scrollOffset;
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.points, this.unlocked);
  final List<Offset> points;
  final int unlocked;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1], to = points[i];
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, from.dy - 59, to.dx, to.dy + 59, to.dx, to.dy);
      final active = i < unlocked;
      canvas.drawPath(
        path.shift(const Offset(0, 9)),
        Paint()
          ..color = const Color(0xFF030710).withValues(alpha: .6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = active
              ? Palette.rust.withValues(alpha: .1)
              : Palette.line.withValues(alpha: .15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = active ? Palette.rust.withValues(alpha: .58) : Palette.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 1.5 : 1,
      );
      // Small route satellites help indicate direction without large arrows.
      for (final metric in path.computeMetrics()) {
        final tangent = metric.getTangentForOffset(metric.length * .5);
        if (tangent != null) {
          canvas.drawCircle(
            tangent.position,
            2,
            Paint()
              ..color = active
                  ? Palette.rust
                  : Palette.secondary.withValues(alpha: .5),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.unlocked != unlocked ||
      old.points.length != points.length ||
      (points.isNotEmpty && old.points.first != points.first);
}

class _OrbitNodePainter extends CustomPainter {
  const _OrbitNodePainter(
    this.current,
    this.unlocked,
    this.completed,
    this.focused,
    this.pressed,
  );
  final bool current, unlocked, completed, focused, pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 33);
    final color = current
        ? Palette.light
        : completed
        ? Palette.rust
        : Palette.pipe;
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0, 17),
        width: 62,
        height: 19,
      ),
      Paint()..color = const Color(0xFF030710).withValues(alpha: .85),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy + 9);
    canvas.rotate(-.23);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 71, height: 31),
      Paint()
        ..color = color.withValues(alpha: unlocked ? .45 : .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: 71, height: 31),
      .1,
      1.0,
      false,
      Paint()
        ..color = color.withValues(alpha: unlocked ? .9 : .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
    canvas.drawCircle(
      center + const Offset(0, 3),
      23,
      Paint()..color = Palette.paper,
    );
    canvas.drawCircle(
      center,
      pressed ? 21 : 23,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.45, -.55),
          radius: 1.1,
          colors: current
              ? [Palette.white, Palette.light, const Color(0xFFAB713C)]
              : [
                  unlocked ? Palette.tile : Palette.board,
                  Palette.paper,
                  const Color(0xFF050B17),
                ],
        ).createShader(Rect.fromCircle(center: center, radius: 24)),
    );
    canvas.drawCircle(
      center,
      23,
      Paint()
        ..color = color.withValues(alpha: unlocked ? .8 : .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = current ? 1.5 : 1,
    );
    if (focused) {
      canvas.drawCircle(
        center,
        29,
        Paint()
          ..color = Palette.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (completed) {
      canvas.drawCircle(
        center + const Offset(22, -16),
        5,
        Paint()..color = Palette.rust,
      );
      canvas.drawPath(
        Path()
          ..moveTo(center.dx + 19.5, center.dy - 16)
          ..lineTo(center.dx + 21.5, center.dy - 14)
          ..lineTo(center.dx + 24.5, center.dy - 18),
        Paint()
          ..color = Palette.paper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    if (!unlocked) {
      final lock = center + const Offset(20, -16);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: lock, width: 9, height: 7),
          const Radius.circular(1.5),
        ),
        Paint()..color = Palette.secondary,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: lock + const Offset(0, -4),
          width: 6,
          height: 7,
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = Palette.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitNodePainter old) =>
      current != old.current ||
      unlocked != old.unlocked ||
      completed != old.completed ||
      focused != old.focused ||
      pressed != old.pressed;
}
