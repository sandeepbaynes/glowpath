import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';
import 'fold_layout.dart';
import 'mission_briefing.dart';
import 'space_controls.dart';
import 'space_scenery.dart';

/// Flight and briefing share one screen. The destination uses exactly the map's
/// planet renderer. Arrival never dismisses the instructions; the final action does.
class PlanetFlight extends StatefulWidget {
  const PlanetFlight({
    super.key,
    required this.world,
    required this.beats,
    required this.onComplete,
    this.reduceMotion = false,
    this.panes,
  });
  final VoyageWorld world;
  final List<MissionBriefingBeat> beats;
  final VoidCallback onComplete;
  final bool reduceMotion;
  final FoldPaneLayout? panes;
  @override
  State<PlanetFlight> createState() => _PlanetFlightState();
}

class _PlanetFlightState extends State<PlanetFlight>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  bool _configured = false,
      _still = false,
      _foreground = true,
      _completed = false;
  int _textCursor = 0;
  List<MissionBriefingBeat> get _beats => widget.beats.isNotEmpty
      ? widget.beats
      : const [
          MissionBriefingBeat(
            text: 'Chart a route through the next world.',
            compactText: 'Approaching your next world.',
          ),
          MissionBriefingBeat(
            text: 'Connect START through all three stars to FINISH.',
            compactText: 'Stars, then FINISH.',
          ),
        ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        widget.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    if (_configured && still == _still) return;
    _configured = true;
    _still = still;
    if (still) {
      _travel.value = 1;
    } else if (_foreground && !_travel.isCompleted) {
      _travel.forward();
    }
  }

  @override
  void didUpdateWidget(PlanetFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _travel.stop();
    } else if (!_still && !_travel.isCompleted) {
      _travel.forward();
    }
  }

  void _arrive() {
    if (_still) {
      _travel.value = 1;
    } else {
      _travel.animateTo(
        1,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _finish() {
    if (_completed || !_foreground) return;
    _completed = true;
    _travel.stop();
    widget.onComplete();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _travel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlockSemantics(
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Flight to ${widget.world.name}. Mission briefing.',
      child: FocusScope(
        child: ColoredBox(
          key: const ValueKey('planet-flight'),
          color: Palette.paper,
          child: LayoutBuilder(
            builder: (context, bounds) {
              if (widget.panes != null) {
                return _foldPresentation(context, widget.panes!);
              }
              final wide = bounds.maxWidth > bounds.maxHeight * 1.2;
              return Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(
                    child: CustomPaint(
                      painter: _TransitPainter(
                        world: widget.world,
                        travel: _travel,
                        wide: wide,
                      ),
                    ),
                  ),
                  const ExcludeSemantics(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _IllustratedCockpitPainter()),
                    ),
                  ),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x99060B14),
                            Color(0x00060B14),
                            Color(0xAA060B14),
                          ],
                          stops: [0, .4, 1],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SECTOR ${(widget.world.planetIndex + 1).toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1.8,
                                        color: widget.world.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      widget.world.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: bookTitle(
                                        MediaQuery.textScalerOf(context)
                                                    .scale(1) >
                                                1.5
                                            ? 16
                                            : 26,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _travel,
                                builder: (context, _) => _travel.isCompleted
                                    ? const SizedBox(width: 48, height: 48)
                                    : OrbitUtility(
                                        key: const ValueKey(
                                          'skip-planet-flight',
                                        ),
                                        label: 'Arrive now. Keep reading the briefing.',
                                        icon: Icons.fast_forward_rounded,
                                        width: 48,
                                        reduceMotion: _still,
                                        onPressed: _arrive,
                                      ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Align(
                            alignment: wide
                                ? Alignment.bottomRight
                                : Alignment.bottomCenter,
                            child: SizedBox(
                              width: wide
                                  ? math.min(520, bounds.maxWidth * .48)
                                  : math.min(560, bounds.maxWidth - 40),
                              height: wide
                                  ? bounds.maxHeight - 140
                                  : MediaQuery.textScalerOf(context).scale(1) >
                                        1.5
                                  ? math.min(520, bounds.maxHeight * .70)
                                  : math.min(360, bounds.maxHeight * .46),
                              child: _briefingContent(),
                            ),
                          ),
                          if (!wide &&
                              bounds.maxHeight >= 700 &&
                              MediaQuery.textScalerOf(context).scale(1) <= 1.5)
                            const SizedBox(height: 56),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _foldPresentation(BuildContext context, FoldPaneLayout panes) {
    final media = MediaQuery.of(context);
    Widget pane(Rect rect, String key, Widget child) => Positioned.fromRect(
      rect: rect,
      child: ClipRect(
        key: ValueKey(key),
        child: MediaQuery(
          data: FoldPaneLayout.paneMediaQuery(media, rect),
          child: child,
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        pane(
          panes.missionRect,
          'transit-mission-pane',
          ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _TransitPainter(
                    world: widget.world,
                    travel: _travel,
                    wide: false,
                    centered: true,
                  ),
                ),
                const CustomPaint(painter: _IllustratedCockpitPainter()),
              ],
            ),
          ),
        ),
        pane(
          panes.actionRect,
          'transit-action-pane',
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.world.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bookTitle(
                          MediaQuery.textScalerOf(context).scale(1) > 1.5
                              ? 16
                              : 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedBuilder(
                      animation: _travel,
                      builder: (context, _) => _travel.isCompleted
                          ? const SizedBox(width: 48, height: 48)
                          : OrbitUtility(
                              key: const ValueKey('skip-planet-flight'),
                              label: 'Arrive now. Keep reading the briefing.',
                              icon: Icons.fast_forward_rounded,
                              width: 48,
                              reduceMotion: _still,
                              onPressed: _arrive,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(child: _briefingContent()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _briefingContent() => LayoutBuilder(
    builder: (context, bounds) {
      final scaler = MediaQuery.textScalerOf(context);
      final dense = scaler.scale(1) > 1.5;
      final style = DefaultTextStyle.of(context).style.merge(
        const TextStyle(
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: Palette.white,
        ),
      );
      final actionHeight = math.max(54.0, scaler.scale(14) * 1.6 + 20);
      final fixedHeight = 30 + actionHeight + 8;
      final textHeight = bounds.maxHeight - fixedHeight;
      final pages =
          <({MissionBriefingBeat beat, String text, int start, int end})>[];
      var offset = 0;
      for (final beat in _beats) {
        for (final text in _fitDialogue(
          beat.text,
          width: bounds.maxWidth - 36,
          height: textHeight - 1,
          style: style,
          scaler: scaler,
          direction: Directionality.of(context),
        )) {
          final end = offset + text.replaceAll(RegExp(r'\s'), '').length;
          pages.add((beat: beat, text: text, start: offset, end: end));
          offset = end;
        }
      }
      // Keep the current reading position when orientation or text size changes.
      // A larger page may repeat context; it never jumps over unread rules.
      final matchingPage = pages.indexWhere((page) => _textCursor < page.end);
      final page = matchingPage < 0 ? pages.length - 1 : matchingPage;
      final current = pages[page];
      final last = page == pages.length - 1;
      final measure = TextPainter(
        text: TextSpan(text: current.text, style: style),
        textScaler: scaler,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: bounds.maxWidth - 36);
      final bubbleHeight = math.min(
        bounds.maxHeight,
        fixedHeight + measure.height.ceilToDouble() + 1,
      );
      measure.dispose();
      final bubble = SizedBox(
        width: bounds.maxWidth,
        height: bubbleHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.paper.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Palette.secondary.withValues(alpha: .18),
              width: .7,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _still
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    child: Align(
                      key: ValueKey('flight-dialogue-$page'),
                      alignment: Alignment.topLeft,
                      child: Semantics(
                        liveRegion: true,
                        label: current.text,
                        child: ExcludeSemantics(
                          child: Text(
                            current.text,
                            key: const ValueKey('flight-dialogue-copy'),
                            style: style,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: actionHeight,
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Previous instruction',
                        enabled: page > 0,
                        onTap: page > 0
                            ? () => setState(
                                () => _textCursor = pages[page - 1].start,
                              )
                            : null,
                        child: ExcludeSemantics(
                          child: IgnorePointer(
                            ignoring: page == 0,
                            child: Opacity(
                              opacity: page > 0 ? 1 : .25,
                              child: OrbitUtility(
                                key: const ValueKey('flight-previous'),
                                label: 'Previous instruction',
                                icon: Icons.arrow_back_rounded,
                                width: 48,
                                reduceMotion: _still,
                                onPressed: () => setState(
                                  () => _textCursor = pages[page - 1].start,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${page + 1}/${pages.length}',
                            semanticsLabel:
                                'Instruction ${page + 1} of ${pages.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Palette.secondary,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SpaceAction(
                          key: const ValueKey('flight-next'),
                          label: last ? (dense ? 'Fly' : "Let's fly") : 'Next',
                          compact: true,
                          reduceMotion: _still,
                          onPressed: last
                              ? _finish
                              : () => setState(
                                  () => _textCursor = pages[page + 1].start,
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
      );
      return Align(
        alignment: Alignment.bottomCenter,
        child: _still
            ? bubble
            : AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: bubble,
              ),
      );
    },
  );
}

List<String> _fitDialogue(
  String text, {
  required double width,
  required double height,
  required TextStyle style,
  required TextScaler scaler,
  required TextDirection direction,
}) {
  bool fits(String value) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textScaler: scaler,
      textDirection: direction,
    )..layout(maxWidth: width);
    final fits = painter.height <= height;
    painter.dispose();
    return fits;
  }

  final result = <String>[];
  var remaining = text.trim();
  while (remaining.isNotEmpty) {
    var low = 1, high = remaining.length;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (fits(remaining.substring(0, middle))) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    var end = low;
    if (end < remaining.length) {
      final space = remaining.lastIndexOf(' ', end);
      if (space > 0) end = space;
    }
    result.add(remaining.substring(0, end).trim());
    remaining = remaining.substring(end).trimLeft();
  }
  return result.isEmpty ? ['Ready for the next flight.'] : result;
}

class _TransitPainter extends CustomPainter {
  _TransitPainter({
    required this.world,
    required this.travel,
    required this.wide,
    this.centered = false,
  }) : super(repaint: travel);
  final VoyageWorld world;
  final Animation<double> travel;
  final bool wide;
  final bool centered;
  @override
  void paint(Canvas canvas, Size size) {
    final t = travel.value, approach = Curves.easeInOutCubic.transform(t);
    final horizon = Offset(
      size.width * (wide ? .28 : .5),
      size.height *
          (centered
              ? .5
              : wide
              ? .48
              : .31),
    );
    final bank = math.sin(t * math.pi * 2) * .035 * (1 - t);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(horizon.dx, horizon.dy);
    canvas.rotate(bank);
    canvas.translate(-horizon.dx, -horizon.dy);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(wide ? -.4 : 0, -.3),
          radius: .8,
          colors: [
            Color.lerp(Palette.paper, world.accent, .055)!,
            Palette.paper,
          ],
        ).createShader(Offset.zero & size),
    );
    for (var i = 0; i < 135; i++) {
      final z = ((i * .6180339887 - approach * 1.8) % 1) * 2.6 + .2;
      final x = math.sin(i * 17.17) * size.width * .9,
          y = math.cos(i * 13.31) * size.height * .85;
      final p = horizon + Offset(x / z, y / z);
      final tail =
          horizon +
          Offset(
            x / (z + .06 * math.sin(t * math.pi)),
            y / (z + .06 * math.sin(t * math.pi)),
          );
      final paint = Paint()
        ..color = Palette.white.withValues(
          alpha: (.12 + .55 / (z + 1)).clamp(0, .7),
        )
        ..strokeWidth = z < .65 ? 1.2 : .6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, p, paint);
    }
    final radius = size.shortestSide * (.045 + approach * (wide ? .25 : .31));
    final center =
        horizon +
        Offset(
          math.sin((1 - approach) * 2.4) * size.width * .15,
          -math.sin(approach * math.pi) * size.height * .025,
        );
    drawOrbitalWorld(
      canvas,
      center: center,
      radius: radius,
      world: world,
      rotation: approach * .12,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TransitPainter old) =>
      old.world.planetIndex != world.planetIndex ||
      old.wide != wide ||
      old.centered != centered ||
      old.travel != travel;
}

/// The pilot frame uses the same painted curves and muted orbital lines as the
/// Voyage map. It never swaps to photographic textures or a different world.
class _IllustratedCockpitPainter extends CustomPainter {
  const _IllustratedCockpitPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Palette.pipe.withValues(alpha: .32);
    final canopy = Path()
      ..moveTo(-w * .03, h * .35)
      ..quadraticBezierTo(-w * .04, h * .03, w * .20, -h * .03)
      ..moveTo(w * 1.03, h * .35)
      ..quadraticBezierTo(w * 1.04, h * .03, w * .80, -h * .03);
    canvas.drawPath(canopy, line);
    final rim = Path()
      ..moveTo(0, h * .945)
      ..quadraticBezierTo(w * .50, h * .895, w, h * .945);
    final deck = Path.from(rim)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      deck,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF132B3C), Palette.paper],
        ).createShader(Rect.fromLTWH(0, h * .91, w, h * .09)),
    );
    canvas.drawPath(rim, line..color = Palette.rust.withValues(alpha: .36));
    final center = Offset(w / 2, h * .962);
    canvas.drawCircle(
      center,
      13,
      line..color = Palette.rust.withValues(alpha: .4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 6, center.dy + 4)
        ..lineTo(center.dx, center.dy - 5)
        ..lineTo(center.dx + 6, center.dy + 4),
      line..color = Palette.light.withValues(alpha: .65),
    );
    for (final side in [-1, 1]) {
      for (var i = 0; i < 9; i++) {
        final x = center.dx + side * (30 + i * 9);
        canvas.drawLine(
          Offset(x, center.dy + 2),
          Offset(x, center.dy - (i % 3 == 0 ? 4 : 1)),
          line..color = Palette.pipe.withValues(alpha: .30),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_IllustratedCockpitPainter old) => false;
}
