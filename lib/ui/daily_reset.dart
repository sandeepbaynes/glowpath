import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// A UTC day instrument. It describes availability without replacing the
/// player's parked route or changing any game state.
class DailyReset extends StatefulWidget {
  const DailyReset({
    super.key,
    required this.dailyDate,
    this.now,
    this.compact = false,
    this.weekly = false,
  });

  final String dailyDate;
  final bool weekly;
  final DateTime Function()? now;

  /// Fits a game HUD in 40 logical pixels at normal text size. Larger text
  /// wraps naturally instead of truncating the countdown.
  final bool compact;

  @override
  State<DailyReset> createState() => _DailyResetState();
}

class _DailyResetState extends State<DailyReset> with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime _now;
  bool _foreground = true;

  DateTime _readTime() => (widget.now ?? DateTime.now)().toUtc();
  DateTime get _periodStart => widget.weekly
      ? DateTime.utc(
          _now.year,
          _now.month,
          _now.day,
        ).subtract(Duration(days: _now.weekday - 1))
      : DateTime.utc(_now.year, _now.month, _now.day);
  DateTime get _tomorrow =>
      _periodStart.add(Duration(days: widget.weekly ? 7 : 1));
  String get _today => _periodStart.toIso8601String().substring(0, 10);
  bool get _newTrioReady => widget.dailyDate.compareTo(_today) < 0;

  @override
  void initState() {
    super.initState();
    _now = _readTime();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didUpdateWidget(DailyReset oldWidget) {
    super.didUpdateWidget(oldWidget);
    _now = _readTime();
    _syncTimer();
  }

  void _syncTimer() {
    final active = _foreground && TickerMode.valuesOf(context).enabled;
    if (!active || _newTrioReady) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _now = _readTime());
        if (_newTrioReady) _syncTimer();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) setState(() => _now = _readTime());
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Round upward so the instrument never displays zero before midnight.
    final seconds = (_tomorrow.difference(_now).inMilliseconds / 1000).ceil();
    String two(int value) => value.toString().padLeft(2, '0');
    final days = widget.weekly ? seconds ~/ 86400 : 0;
    final clock =
        '${days > 0 ? '${days}d ' : ''}${two(widget.weekly ? seconds ~/ 3600 % 24 : seconds ~/ 3600)}:'
        '${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
    final progress = _newTrioReady
        ? 1.0
        : 1 - seconds / (widget.weekly ? 604800 : 86400);
    final value = _newTrioReady
        ? (widget.weekly ? 'New week ready' : 'New trio ready')
        : clock;
    return Semantics(
      container: true,
      label: widget.weekly ? 'Weekly expedition window' : 'Daily signal window',
      value: _newTrioReady
          ? 'A new ${widget.weekly ? 'expedition' : 'trio'} is ready. Your current route is preserved.'
          : 'Next ${widget.weekly ? 'expedition' : 'trio'} in ${seconds ~/ 3600} hours, '
                '${seconds ~/ 60 % 60} minutes, ${seconds % 60} seconds. '
                'Refreshes at ${widget.weekly ? 'Monday midnight' : 'midnight'} UTC. Your current route is preserved.',
      child: ExcludeSemantics(
        child: widget.compact
            ? _compactInstrument(progress, value)
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 34,
                          child: CustomPaint(painter: _DayOrbit(progress)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _newTrioReady
                                    ? (widget.weekly
                                          ? 'WEEKLY EXPEDITION'
                                          : 'DAILY SIGNAL')
                                    : (widget.weekly
                                          ? 'NEXT EXPEDITION'
                                          : 'NEXT TRIO'),
                                style: const TextStyle(
                                  color: Palette.secondary,
                                  fontSize: 11,
                                  letterSpacing: 1.25,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                value,
                                key: const ValueKey('daily-reset-countdown'),
                                style: TextStyle(
                                  color: _newTrioReady
                                      ? Palette.rust
                                      : Palette.white,
                                  fontSize: _newTrioReady ? 18 : 22,
                                  fontWeight: FontWeight.w400,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 5,
                      child: CustomPaint(painter: _DayTrack(progress)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _newTrioReady
                          ? 'Your current route stays saved.'
                          : '${widget.weekly ? 'Monday midnight' : 'Midnight'} UTC · your route stays saved',
                      style: const TextStyle(
                        color: Palette.secondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _compactInstrument(double progress, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: CustomPaint(painter: _DayOrbit(progress)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(
                    _newTrioReady
                        ? (widget.weekly ? 'Weekly route' : 'Daily signal')
                        : (widget.weekly ? 'Next week' : 'Next trio'),
                    style: const TextStyle(
                      color: Palette.secondary,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    value,
                    key: const ValueKey('daily-reset-countdown'),
                    style: TextStyle(
                      color: _newTrioReady ? Palette.rust : Palette.white,
                      fontSize: _newTrioReady ? 14 : 16,
                      fontWeight: FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(height: 3, child: CustomPaint(painter: _DayTrack(progress))),
      ],
    ),
  );
}

class _DayOrbit extends CustomPainter {
  const _DayOrbit(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Palette.line.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12 - math.pi / 2;
      final vector = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + vector * (radius - 1.5),
        center + vector * (radius - (i % 6 == 0 ? 4 : 2.5)),
        Paint()
          ..color = Palette.secondary.withValues(alpha: .3)
          ..strokeWidth = .65,
      );
    }
    canvas.drawArc(
      bounds,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = Palette.rust
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    final angle = progress * math.pi * 2 - math.pi / 2;
    canvas.drawCircle(
      center + Offset(math.cos(angle), math.sin(angle)) * radius,
      1.8,
      Paint()..color = Palette.white,
    );
    canvas.drawCircle(center, 2.3, Paint()..color = Palette.light);
    canvas.drawLine(
      center,
      center + Offset(math.cos(angle), math.sin(angle)) * (radius * .45),
      Paint()
        ..color = Palette.light.withValues(alpha: .7)
        ..strokeWidth = .7,
    );
  }

  @override
  bool shouldRepaint(_DayOrbit oldDelegate) => progress != oldDelegate.progress;
}

class _DayTrack extends CustomPainter {
  const _DayTrack(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final end = size.width;
    canvas.drawLine(
      Offset(0, y),
      Offset(end, y),
      Paint()..color = Palette.line,
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(end * progress, y),
      Paint()..color = Palette.rust.withValues(alpha: .65),
    );
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(
        Offset(end * i / 4, 0),
        Offset(end * i / 4, size.height),
        Paint()..color = i / 4 <= progress ? Palette.rust : Palette.line,
      );
    }
  }

  @override
  bool shouldRepaint(_DayTrack oldDelegate) => progress != oldDelegate.progress;
}
