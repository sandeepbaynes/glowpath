import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// One compact instrument occupies the same instruction slot as Voyage.
/// Stage numbers are one-based; drawing marks never add navigation targets.
class ChallengeStageRail extends StatelessWidget {
  const ChallengeStageRail({
    super.key,
    required this.stageCount,
    required this.activeStage,
    required this.completedStages,
    this.cleanStreak = 0,
    this.points = 0,
    this.nextIn,
    this.practice = false,
    this.instruction,
    this.reduceMotion = false,
  });
  final int stageCount, activeStage, cleanStreak, points;
  final Set<int> completedStages;
  final Duration? nextIn;
  final bool practice, reduceMotion;
  final String? instruction;

  @override
  Widget build(BuildContext context) {
    final stage = activeStage.clamp(1, stageCount);
    final locked = nextIn != null;
    final remaining = math.max(0, nextIn?.inMilliseconds ?? 0) / 1000;
    final caption = locked
        ? 'Signal $stage/$stageCount locked · Next in ${remaining.toStringAsFixed(1)}s'
        : '${practice ? 'Practice · ' : ''}$points pts · Clean streak $cleanStreak';
    return Semantics(
      container: true,
      label: locked
          ? caption
          : 'Signal $stage of $stageCount. ${completedStages.length} cleared. $caption.${instruction == null ? '' : ' $instruction'}',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, bounds) => Column(
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: completedStages.length.toDouble()),
                  duration:
                      reduceMotion ||
                          MediaQuery.disableAnimationsOf(context) ||
                          MediaQuery.reduceMotionOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => CustomPaint(
                    painter: _SignalRail(
                      count: stageCount,
                      stage: stage,
                      completed: completedStages,
                      progress: progress,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              SizedBox(
                height: instruction == null
                    ? math.min(23, bounds.maxHeight * .42)
                    : math.min(18, bounds.maxHeight * .3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    caption,
                    key: const ValueKey('challenge-stage-caption'),
                    style: TextStyle(
                      fontSize: 12,
                      color: locked ? Palette.light : Palette.secondary,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              if (instruction != null)
                SizedBox(
                  height: math.min(20, bounds.maxHeight * .34),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      instruction!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalRail extends CustomPainter {
  const _SignalRail({
    required this.count,
    required this.stage,
    required this.completed,
    required this.progress,
  });
  final int count, stage;
  final Set<int> completed;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.min(size.width, count * 66.0);
    final left = (size.width - width) / 2;
    final step = width / count;
    final radius = math.min(10.0, size.height * .37);
    final y = size.height / 2;
    final pen = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < count - 1; i++) {
      final from = Offset(left + step * (i + .5) + radius + 5, y);
      final to = Offset(left + step * (i + 1.5) - radius - 5, y);
      canvas.drawLine(
        from,
        to,
        pen
          ..color = Palette.line
          ..strokeWidth = .8,
      );
      if (completed.contains(i + 1)) {
        canvas.drawLine(
          from,
          Offset.lerp(from, to, (progress - i).clamp(0, 1))!,
          pen
            ..color = Palette.rust
            ..strokeWidth = 1.2,
        );
      }
    }
    for (var i = 1; i <= count; i++) {
      final center = Offset(left + step * (i - .5), y);
      final done = completed.contains(i);
      final active = i == stage;
      final color = done
          ? Palette.rust
          : active
          ? Palette.light
          : Palette.secondary;
      if (active) {
        canvas.drawCircle(
          center,
          radius + 3,
          pen
            ..color = color.withValues(alpha: .3)
            ..strokeWidth = .7,
        );
      }
      final diamond = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius * .8, center.dy)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius * .8, center.dy)
        ..close();
      canvas.drawPath(
        diamond,
        Paint()..color = color.withValues(alpha: done ? .16 : .04),
      );
      canvas.drawPath(
        diamond,
        pen
          ..color = color.withValues(alpha: done || active ? .9 : .4)
          ..strokeWidth = 1,
      );
      if (done) {
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - radius * .35, y)
            ..lineTo(center.dx - radius * .06, y + radius * .3)
            ..lineTo(center.dx + radius * .38, y - radius * .33),
          pen
            ..color = color
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      } else {
        final label = TextPainter(
          text: TextSpan(
            text: '$i',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: radius * 1.04,
              height: 1,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, center - Offset(label.width, label.height) / 2);
        label.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(_SignalRail old) =>
      old.count != count ||
      old.stage != stage ||
      old.progress != progress ||
      old.completed != completed;
}

/// A live UTC reset dial. Expiry announces availability; it never mutates or
/// abandons a run. The caller owns the explicit Start new challenge action.
class ChallengeResetInstrument extends StatefulWidget {
  const ChallengeResetInstrument({
    super.key,
    required this.weekly,
    required this.periodDate,
    this.now,
  });
  final bool weekly;
  final String periodDate;
  final DateTime Function()? now;
  @override
  State<ChallengeResetInstrument> createState() =>
      _ChallengeResetInstrumentState();
}

class _ChallengeResetInstrumentState extends State<ChallengeResetInstrument>
    with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime _now;
  bool _foreground = true;
  DateTime _read() => (widget.now ?? DateTime.now)().toUtc();
  DateTime get _start {
    final today = DateTime.utc(_now.year, _now.month, _now.day);
    return widget.weekly
        ? today.subtract(Duration(days: _now.weekday - 1))
        : today;
  }

  bool get _ready =>
      widget.periodDate.compareTo(_start.toIso8601String().substring(0, 10)) <
      0;
  @override
  void initState() {
    super.initState();
    _now = _read();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ChallengeResetInstrument old) {
    super.didUpdateWidget(old);
    _now = _read();
    _sync();
  }

  void _sync() {
    if (!_foreground || !TickerMode.valuesOf(context).enabled || _ready) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _now = _read());
        if (_ready) _sync();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) setState(() => _now = _read());
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = math.max(
      0,
      (_start
                  .add(Duration(days: widget.weekly ? 7 : 1))
                  .difference(_now)
                  .inMilliseconds /
              1000)
          .ceil(),
    );
    final days = seconds ~/ 86400;
    String two(int n) => n.toString().padLeft(2, '0');
    final clock =
        '${widget.weekly && days > 0 ? '${days}d ' : ''}${two(seconds ~/ 3600 % 24)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
    final value = _ready
        ? 'New ${widget.weekly ? 'gauntlet' : 'sprint'} ready'
        : clock;
    final label = _ready
        ? 'UTC window open'
        : 'Next ${widget.weekly ? 'gauntlet · Monday' : 'sprint'} 00:00 UTC';
    return Semantics(
      container: true,
      label: _ready ? value : '$label. $clock remaining.',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, bounds) => Row(
            children: [
              SizedBox.square(
                dimension: math.min(40, bounds.maxHeight),
                child: CustomPaint(
                  painter: _ResetDial(
                    _ready ? 1 : 1 - seconds / (widget.weekly ? 604800 : 86400),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: Palette.secondary,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          key: const ValueKey('challenge-reset-countdown'),
                          style: const TextStyle(
                            fontSize: 23,
                            height: 1.2,
                            color: Palette.rust,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
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
  }
}

class _ResetDial extends CustomPainter {
  const _ResetDial(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.shortestSide * .43;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final face = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, pen..color = Palette.line);
    canvas.drawArc(
      face,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      pen
        ..color = Palette.rust
        ..strokeWidth = 1.5,
    );
    for (var i = 0; i < 12; i++) {
      final ray = Offset(math.sin(i * math.pi / 6), -math.cos(i * math.pi / 6));
      canvas.drawLine(
        center + ray * radius * .76,
        center + ray * radius * .84,
        pen
          ..color = Palette.secondary.withValues(alpha: .5)
          ..strokeWidth = .7,
      );
    }
    final hand = Offset(
      math.sin(progress * 2 * math.pi),
      -math.cos(progress * 2 * math.pi),
    );
    canvas.drawLine(
      center,
      center + hand * radius * .58,
      pen
        ..color = Palette.light
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(center, 2, Paint()..color = Palette.light);
    canvas.drawCircle(
      center + hand * radius,
      2,
      Paint()..color = Palette.white,
    );
  }

  @override
  bool shouldRepaint(_ResetDial old) => progress != old.progress;
}
