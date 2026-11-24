import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Event-driven decorative parallax. The child never moves with the sky.
/// Motion readings are transient: they are not logged, persisted or transmitted.
class ReactiveSky extends StatefulWidget {
  const ReactiveSky({
    super.key,
    required this.child,
    this.enabled = true,
    this.reduceMotion = false,
    this.sector = 1,
    this.excitement = 0,
    this.sensorStream,
  });

  final Widget child;
  final bool enabled;
  final bool reduceMotion;
  final int sector;
  final double excitement;

  /// A broadcast stream may be injected for tests. Web never subscribes to it.
  final Stream<AccelerometerEvent>? sensorStream;

  @override
  State<ReactiveSky> createState() => _ReactiveSkyState();
}

class _ReactiveSkyState extends State<ReactiveSky> with WidgetsBindingObserver {
  final _parallax = ValueNotifier<Offset>(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _subscription;
  Future<void> _cancellation = Future<void>.value();
  int _generation = 0;
  bool? _motionEnabled;
  bool _foreground = true;
  bool _systemStill = false;
  bool _tickerEnabled = true;
  Orientation? _orientation;
  Offset _neutral = Offset.zero;
  int _calibrationSamples = 0;

  bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _pointerEnabled =>
      _motionEnabled == true &&
      (kIsWeb || (!_mobile && widget.sensorStream == null));

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.maybeOf(context);
    _systemStill =
        (media?.reduceMotion ?? false) || (media?.disableAnimations ?? false);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    final orientation = media?.orientation;
    final rotated = _orientation != null && orientation != _orientation;
    _orientation = orientation;
    _updateMotion(force: rotated);
  }

  @override
  void didUpdateWidget(ReactiveSky oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion(force: oldWidget.sensorStream != widget.sensorStream);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  void _updateMotion({bool force = false}) {
    final enabled =
        widget.enabled &&
        !widget.reduceMotion &&
        !_systemStill &&
        _foreground &&
        _tickerEnabled;
    if (_motionEnabled == enabled && !force) return;
    _motionEnabled = enabled;
    _cancelSensor();
    _resetParallax();
    if (enabled && !kIsWeb && (_mobile || widget.sensorStream != null)) {
      unawaited(_startSensor(_generation));
    }
  }

  Future<void> _startSensor(int generation) async {
    await _cancellation;
    if (!mounted || generation != _generation || _motionEnabled != true) return;

    // Some plugin setup failures arrive asynchronously from its sampling-period
    // method channel, before the event stream reports an error. Keep those
    // failures local to this optional decoration, too.
    final stream =
        widget.sensorStream ??
        runZonedGuarded<Stream<AccelerometerEvent>>(
          () => accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 80),
          ),
          (Object error, StackTrace stack) => _sensorUnavailable(generation),
        );
    if (stream == null || generation != _generation) return;
    try {
      _subscription = stream.listen(
        (event) => _onAcceleration(event, generation),
        onError: (Object error, StackTrace stack) =>
            _sensorUnavailable(generation),
        onDone: () => _sensorUnavailable(generation),
        cancelOnError: true,
      );
    } catch (_) {
      _sensorUnavailable(generation);
    }
  }

  void _sensorUnavailable(int generation) {
    if (!mounted || generation != _generation) return;
    _cancelSensor();
    _resetParallax();
  }

  void _cancelSensor() {
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    if (subscription == null) return;
    try {
      final pending = subscription.cancel().catchError((Object error) {});
      _cancellation = Future.wait<void>([_cancellation, pending]).then((_) {});
    } catch (_) {
      // An unavailable optional sensor must not prevent playing the puzzle.
    }
  }

  void _resetParallax() {
    _neutral = Offset.zero;
    _calibrationSamples = 0;
    _parallax.value = Offset.zero;
  }

  void _onAcceleration(AccelerometerEvent event, int generation) {
    if (!mounted || generation != _generation || _motionEnabled != true) return;
    if (!event.x.isFinite || !event.y.isFinite || !event.z.isFinite) return;
    final reading = Offset(
      event.x.clamp(-20.0, 20.0).toDouble(),
      event.y.clamp(-20.0, 20.0).toDouble(),
    );
    // Average the first four readings after enabling/resuming/rotating so the
    // starting posture is neutral rather than a sudden full-screen displacement.
    if (_calibrationSamples < 4) {
      _calibrationSamples++;
      _neutral += (reading - _neutral) / _calibrationSamples.toDouble();
      return;
    }
    final delta = (reading - _neutral) / 5.5;
    _setTarget(Offset(-delta.dx, delta.dy));
  }

  void _setTarget(Offset target) {
    final bounded = Offset(
      target.dx.clamp(-1.0, 1.0).toDouble(),
      target.dy.clamp(-1.0, 1.0).toDouble(),
    );
    final filtered = Offset.lerp(_parallax.value, bounded, .18)!;
    if ((filtered - _parallax.value).distanceSquared > .000004) {
      _parallax.value = filtered;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelSensor();
    _parallax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MouseRegion(
      opaque: false,
      onHover: (event) {
        if (!_pointerEnabled ||
            !constraints.hasBoundedWidth ||
            !constraints.hasBoundedHeight ||
            constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0) {
          return;
        }
        _setTarget(
          Offset(
            event.localPosition.dx / constraints.maxWidth * 2 - 1,
            event.localPosition.dy / constraints.maxHeight * 2 - 1,
          ),
        );
      },
      onExit: (_) {
        if (_pointerEnabled) _parallax.value = Offset.zero;
      },
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const ValueKey('reactive-sky-paint'),
                      painter: ReactiveSkyPainter(
                        parallax: _parallax,
                        sector: widget.sector,
                        excitement: widget.excitement,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    ),
  );
}

/// Three original constellation layers. Only this painter listens to motion;
/// sensor events neither rebuild nor transform the game subtree.
class ReactiveSkyPainter extends CustomPainter {
  ReactiveSkyPainter({
    required ValueListenable<Offset> parallax,
    required this.sector,
    required this.excitement,
  }) : _parallax = parallax,
       super(repaint: parallax);

  final ValueListenable<Offset> _parallax;
  final int sector;
  final double excitement;

  /// Normalized displacement; the nearest stars move at most 30 logical pixels.
  Offset get parallax => _parallax.value;

  static const _colors = [
    Color(0xFF76C9E8),
    Color(0xFFB39DEB),
    Color(0xFF79DCCC),
    Color(0xFFEDA287),
  ];
  static const _shapes = <List<Offset>>[
    [
      Offset(-.7, .1),
      Offset(-.3, -.4),
      Offset(.15, -.25),
      Offset(.45, .3),
      Offset(.9, .05),
    ],
    [
      Offset(-.8, -.2),
      Offset(-.4, .2),
      Offset(.05, -.15),
      Offset(.55, .15),
      Offset(.8, .65),
    ],
    [
      Offset(-.55, -.6),
      Offset(-.15, -.1),
      Offset(.45, -.3),
      Offset(.7, .2),
      Offset(.1, .5),
      Offset(-.15, -.1),
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final energy = excitement.isFinite
        ? excitement.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final accent = _colors[sector % _colors.length];
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080F20),
    );
    final radius = math.max(size.width, size.height) * .62;
    for (var cloud = 0; cloud < 2; cloud++) {
      final center =
          Offset(
            size.width * (cloud == 0 ? .9 : .04),
            size.height * (cloud == 0 ? .15 : .86),
          ) +
          parallax * (cloud == 0 ? 8 : 13);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              (cloud == 0 ? accent : _colors[(sector + 1) % _colors.length])
                  .withValues(alpha: .13 + energy * .04),
              const Color(0x00080F20),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    for (var layer = 0; layer < 3; layer++) {
      final shift = parallax * (10.0 + layer * 10);
      for (var i = 0; i < 34; i++) {
        final x = ((i * 173 + layer * 73 + sector * 11) % 997) / 997;
        final y =
            ((i * i * 29 + i * 67 + layer * 211 + sector * 23) % 991) / 991;
        final quiet = x > .13 && x < .87 && y > .25 && y < .78;
        final alpha = quiet ? .08 : .18 + layer * .1 + (i % 3) * .07;
        canvas.drawCircle(
          Offset(x * size.width, y * size.height) + shift,
          .7 + layer * .25 + (i % 4 == 0 ? .5 : 0),
          Paint()..color = const Color(0xFFE6F1FF).withValues(alpha: alpha),
        );
      }
      final anchor =
          Offset(
            size.width * (layer == 1 ? .8 : .2),
            size.height *
                (layer == 0
                    ? .13
                    : layer == 1
                    ? .83
                    : .92),
          ) +
          shift;
      final span = math.min(size.width * .19, 98.0);
      final points = _shapes[(layer + sector) % _shapes.length]
          .map((point) => anchor + point * span)
          .toList();
      final line = Paint()
        ..color = accent.withValues(alpha: .17 + energy * .05)
        ..strokeWidth = .8;
      for (var i = 1; i < points.length; i++) {
        canvas.drawLine(points[i - 1], points[i], line);
      }
      for (var i = 0; i < points.length; i++) {
        canvas.drawCircle(
          points[i],
          2.0 + (i == 2 ? .5 : 0),
          Paint()..color = accent.withValues(alpha: .58),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ReactiveSkyPainter oldDelegate) =>
      oldDelegate.sector != sector ||
      oldDelegate.excitement != excitement ||
      oldDelegate._parallax != _parallax;
}
