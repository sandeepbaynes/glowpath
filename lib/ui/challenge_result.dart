import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'challenge_instruments.dart';
import 'design.dart';
import 'fold_layout.dart';
import 'space_controls.dart';

/// A finished rapid-fire set stays in its own signal language, with no Voyage
/// destination or promise of a fresh rewarded run before the UTC window opens.
class ChallengeResult extends StatelessWidget {
  const ChallengeResult({
    super.key,
    required this.weekly,
    required this.stageCount,
    required this.points,
    required this.activeElapsed,
    required this.cleanStreak,
    required this.medalEarned,
    required this.periodDate,
    required this.onVoyage,
    required this.onCollection,
    this.starsEarned = 0,
    this.coinsEarned = 0,
    this.hasNewChallenge = false,
    this.onNewChallenge,
    this.now,
    this.reduceMotion = false,
    this.hasCompleteTiming = true,
    this.hasCompleteScore = true,
    this.panes,
  });
  final bool weekly, medalEarned, hasNewChallenge, reduceMotion;
  final bool hasCompleteTiming, hasCompleteScore;
  final int stageCount, cleanStreak, starsEarned, coinsEarned;
  final int? points;
  final Duration? activeElapsed;
  final String periodDate;
  final VoidCallback onVoyage, onCollection;
  final VoidCallback? onNewChallenge;
  final DateTime Function()? now;
  final FoldPaneLayout? panes;

  String get _title =>
      weekly ? 'Weekly Gauntlet complete' : 'Daily Sprint complete';
  String get _elapsed {
    if (activeElapsed == null || !hasCompleteTiming) return '—';
    final millis = activeElapsed!.inMilliseconds;
    if (millis < 60000) return '${(millis / 1000).toStringAsFixed(1)}s';
    return '${millis ~/ 60000}m ${((millis % 60000) / 1000).toStringAsFixed(1)}s';
  }

  String get _reward => [
    if (medalEarned) '${weekly ? 'Gauntlet' : 'Sprint'} medal earned',
    if (starsEarned > 0) '+$starsEarned stars',
    if (coinsEarned > 0) '+$coinsEarned coins',
    if (!medalEarned && starsEarned == 0 && coinsEarned == 0)
      'Results saved · rewards already collected',
  ].join(' · ');

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Center(
      child: ConstrainedBox(
        constraints: panes == null
            ? const BoxConstraints(maxWidth: 900, maxHeight: 900)
            : const BoxConstraints(),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final landscape =
                bounds.maxWidth >= 520 &&
                bounds.maxWidth > bounds.maxHeight * 1.1;
            final short = panes != null
                ? panes!.actionRect.height < 640
                : bounds.maxHeight < 640;
            final title = SizedBox(
              height: short ? 42 : 62,
              child: Semantics(
                header: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _title,
                    key: const ValueKey('challenge-result-title'),
                    style: bookTitle(landscape ? 25 : 28),
                  ),
                ),
              ),
            );
            final score = Column(
              children: [
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, area) {
                        final size = math.max(
                          20.0,
                          math.min(
                            bounds.maxWidth >= 600 ? 340.0 : 240.0,
                            math.min(area.maxWidth * .84, area.maxHeight * .95),
                          ),
                        );
                        return ExcludeSemantics(
                          child: SizedBox.square(
                            dimension: size,
                            child: CustomPaint(
                              painter: _ChallengeSeal(
                                weekly: weekly,
                                signals: stageCount,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: short ? 44 : 70,
                  child: Semantics(
                    label: points == null
                        ? 'Local points unavailable for this earlier run'
                        : '$points ${hasCompleteScore ? 'local' : 'recorded'} points',
                    child: ExcludeSemantics(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          points?.toString() ?? '—',
                          key: const ValueKey('challenge-result-score'),
                          style: bookTitle(62),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 22,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$stageCount signals secured · ${hasCompleteScore ? 'local' : 'recorded'} points',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Palette.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            );
            final metrics = SizedBox(
              height: short ? 48 : 66,
              child: Row(
                children: [
                  Expanded(
                    child: _ResultMetric(
                      value: _elapsed,
                      caption: hasCompleteTiming && activeElapsed != null
                          ? 'Clear time'
                          : 'Time not recorded',
                      semantics: activeElapsed == null || !hasCompleteTiming
                          ? 'Clear time unavailable for this earlier run'
                          : 'Combined solving time of the cleared attempts: $_elapsed',
                    ),
                  ),
                  Container(width: .7, height: 30, color: Palette.line),
                  Expanded(
                    child: _ResultMetric(
                      value: '$cleanStreak/$stageCount',
                      caption: 'Best clean streak',
                      semantics:
                          'Best clean streak $cleanStreak of $stageCount signals',
                    ),
                  ),
                ],
              ),
            );
            final reward = SizedBox(
              height: short ? 32 : 44,
              child: Semantics(
                label: _reward,
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        if (medalEarned) ...[
                          SizedBox.square(
                            dimension: 24,
                            child: CustomPaint(
                              painter: _ChallengeSeal(
                                weekly: weekly,
                                signals: stageCount,
                                compact: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _reward,
                          key: const ValueKey('challenge-result-rewards'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Palette.light,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            final reset = SizedBox(
              height: short ? 52 : 64,
              child: ChallengeResetInstrument(
                weekly: weekly,
                periodDate: periodDate,
                now: now,
              ),
            );
            final actions = SizedBox(
              height: 54,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SpaceAction(
                      key: const ValueKey('challenge-return-voyage'),
                      label: hasNewChallenge && onNewChallenge != null
                          ? 'Start new ${weekly ? 'gauntlet' : 'sprint'}'
                          : 'Return to Voyage',
                      onPressed: hasNewChallenge && onNewChallenge != null
                          ? onNewChallenge
                          : onVoyage,
                      reduceMotion: reduceMotion,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SpaceAction(
                      key: const ValueKey('challenge-open-collection'),
                      label: 'Collection',
                      icon: Icons.auto_awesome_outlined,
                      onPressed: onCollection,
                      reduceMotion: reduceMotion,
                      compact: true,
                      quiet: true,
                    ),
                  ),
                ],
              ),
            );
            if (panes != null) {
              final media = MediaQuery.of(context);
              Widget pane(Rect rect, String key, Widget content) =>
                  Positioned.fromRect(
                    rect: rect,
                    child: ClipRect(
                      key: ValueKey(key),
                      child: MediaQuery(
                        data: FoldPaneLayout.paneMediaQuery(media, rect),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: content,
                        ),
                      ),
                    ),
                  );
              return Stack(
                fit: StackFit.expand,
                children: [
                  pane(
                    panes!.missionRect,
                    'challenge-result-mission-pane',
                    Column(
                      children: [
                        title,
                        Expanded(child: score),
                      ],
                    ),
                  ),
                  pane(
                    panes!.actionRect,
                    'challenge-result-action-pane',
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        metrics,
                        reward,
                        const SizedBox(height: 8),
                        reset,
                        const SizedBox(height: 12),
                        actions,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: bounds.maxWidth > 800 ? 24 : 8,
                vertical: short ? 4 : 10,
              ),
              child: landscape
                  ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              title,
                              Expanded(child: score),
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              metrics,
                              reward,
                              const SizedBox(height: 8),
                              reset,
                              const SizedBox(height: 12),
                              actions,
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        Expanded(child: score),
                        const SizedBox(height: 8),
                        metrics,
                        reward,
                        const SizedBox(height: 8),
                        reset,
                        const SizedBox(height: 12),
                        actions,
                      ],
                    ),
            );
          },
        ),
      ),
    ),
  );
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.value,
    required this.caption,
    required this.semantics,
  });
  final String value, caption, semantics;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semantics,
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: bookTitle(24)),
              ),
            ),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Palette.secondary,
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

/// A challenge retry interrupts the current signal only. Its single action
/// preserves the player's already-cleared signals, without a Voyage flight.
class ChallengeRetryOverlay extends StatelessWidget {
  const ChallengeRetryOverlay({
    super.key,
    required this.stage,
    required this.stageCount,
    required this.onRetry,
    this.reduceMotion = false,
    this.panes,
  });
  final int stage, stageCount;
  final VoidCallback onRetry;
  final bool reduceMotion;
  final FoldPaneLayout? panes;
  @override
  Widget build(BuildContext context) {
    final still =
        reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    return BlockSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        onPanUpdate: (_) {},
        excludeFromSemantics: true,
        child: Material(
          color: Palette.paper,
          child: FocusScope(
            autofocus: true,
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: 'Signal interrupted. Retry signal $stage of $stageCount.',
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: panes == null ? .97 + value * .03 : 1,
                    child: child,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final wide =
                        bounds.maxWidth > bounds.maxHeight * 1.3 &&
                        bounds.maxWidth > 600;
                    final art = ExcludeSemantics(
                      child: Center(
                        child: SizedBox.square(
                          dimension: math.min(
                            wide ? 180 : 145,
                            bounds.maxHeight * .24,
                          ),
                          child: CustomPaint(
                            painter: _ChallengeSeal(
                              weekly: stageCount > 3,
                              signals: stageCount,
                              interrupted: true,
                            ),
                          ),
                        ),
                      ),
                    );
                    final details = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 30,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'SIGNAL $stage / $stageCount',
                              style: const TextStyle(
                                fontSize: 12,
                                letterSpacing: 2,
                                color: Palette.light,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 58,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Signal interrupted',
                              style: bookTitle(29),
                            ),
                          ),
                        ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: const _RetryMessage(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 56,
                          child: SpaceAction(
                            key: const ValueKey('retry-flight'),
                            label: 'Retry signal',
                            onPressed: onRetry,
                            reduceMotion: still,
                          ),
                        ),
                      ],
                    );
                    if (panes != null) {
                      final media = MediaQuery.of(context);
                      Widget pane(Rect rect, String key, Widget content) =>
                          Positioned.fromRect(
                            rect: rect,
                            child: ClipRect(
                              key: ValueKey(key),
                              child: MediaQuery(
                                data: FoldPaneLayout.paneMediaQuery(
                                  media,
                                  rect,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: content,
                                ),
                              ),
                            ),
                          );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          pane(
                            panes!.missionRect,
                            'challenge-retry-mission-pane',
                            art,
                          ),
                          pane(
                            panes!.actionRect,
                            'challenge-retry-action-pane',
                            details,
                          ),
                        ],
                      );
                    }
                    return SizedBox.expand(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 900,
                              maxHeight: 670,
                            ),
                            child: wide
                                ? Row(
                                    children: [
                                      Expanded(flex: 2, child: art),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 3, child: details),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      Expanded(child: art),
                                      Expanded(
                                        flex: 2,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 460,
                                          ),
                                          child: details,
                                        ),
                                      ),
                                    ],
                                  ),
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
}

class _RetryMessage extends StatelessWidget {
  const _RetryMessage();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      const text = 'This signal restarts.\nCleared signals are saved.';
      final style = DefaultTextStyle.of(context).style.merge(
        const TextStyle(fontSize: 17, height: 1.45, color: Palette.secondary),
      );
      final requested = MediaQuery.textScalerOf(context).scale(17) / 17;
      var low = .5, high = requested;
      final painter = TextPainter(textDirection: Directionality.of(context));
      for (var i = 0; i < 12; i++) {
        final scale = (low + high) / 2;
        painter.text = TextSpan(text: text, style: style);
        painter.textScaler = TextScaler.linear(scale);
        painter.layout(maxWidth: bounds.maxWidth);
        if (painter.height > bounds.maxHeight) {
          high = scale;
        } else {
          low = scale;
        }
      }
      painter.dispose();
      return Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: style,
          textScaler: TextScaler.linear(low),
        ),
      );
    },
  );
}

/// An engraved relay seal: three/five stations around one transmitted signal.
/// The interrupted variant breaks its beam into two drifting fragments.
class _ChallengeSeal extends CustomPainter {
  const _ChallengeSeal({
    required this.weekly,
    required this.signals,
    this.compact = false,
    this.interrupted = false,
  });
  final bool weekly, compact, interrupted;
  final int signals;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), r = size.shortestSide * .43;
    final tint = interrupted
        ? Palette.secondary
        : weekly
        ? Palette.light
        : Palette.rust;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? .8 : 1;
    final face = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [tint.withValues(alpha: .12), tint.withValues(alpha: 0)],
        ).createShader(face),
    );
    canvas.drawCircle(
      center,
      r * .83,
      pen..color = tint.withValues(alpha: .24),
    );
    for (var i = 0; i < signals; i++) {
      final angle = i * math.pi * 2 / signals - math.pi / 2;
      final ray = Offset(math.cos(angle), math.sin(angle));
      canvas.drawArc(
        face,
        angle + .14,
        2 * math.pi / signals - .28,
        false,
        pen
          ..color = tint.withValues(alpha: interrupted ? .2 : .55)
          ..strokeWidth = compact ? .8 : 1,
      );
      final p = center + ray * r;
      canvas.drawCircle(p, compact ? 1 : 3, Paint()..color = tint);
      if (!compact) {
        canvas.drawLine(
          center + ray * r * .9,
          center + ray * r * .8,
          pen..color = tint.withValues(alpha: .45),
        );
      }
    }
    final a = center + Offset(-r * .25, -r * .06);
    final b = center + Offset(0, -r * .42);
    final c = center + Offset(r * .25, -r * .06);
    final d = center + Offset(0, r * .24);
    final beam = Path();
    if (interrupted) {
      beam
        ..moveTo(b.dx - r * .07, b.dy + r * .06)
        ..lineTo(a.dx - r * .07, a.dy + r * .06)
        ..lineTo(d.dx - r * .07, d.dy + r * .06)
        ..moveTo(b.dx + r * .07, b.dy - r * .06)
        ..lineTo(c.dx + r * .07, c.dy - r * .06)
        ..lineTo(d.dx + r * .07, d.dy - r * .06);
      canvas.drawLine(
        center + Offset(-r * .13, -r * .25),
        center + Offset(r * .08, -r * .03),
        pen
          ..color = Palette.light.withValues(alpha: .7)
          ..strokeWidth = .8,
      );
    } else {
      beam
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close();
      canvas.drawPath(beam, Paint()..color = tint.withValues(alpha: .07));
      canvas.drawLine(
        b + Offset(0, r * .13),
        d - Offset(0, r * .13),
        pen
          ..color = tint.withValues(alpha: .45)
          ..strokeWidth = .8,
      );
    }
    canvas.drawPath(
      beam,
      pen
        ..color = tint
        ..strokeWidth = compact ? 1 : 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center + Offset(0, r * .35),
      compact ? 1 : 3,
      Paint()..color = Palette.light,
    );
    if (!compact && !interrupted) {
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(
            center: center + Offset(0, r * .35),
            radius: r * (.16 + i * .11),
          ),
          .28,
          math.pi - .56,
          false,
          pen
            ..color = tint.withValues(alpha: .55 - i * .12)
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChallengeSeal old) =>
      weekly != old.weekly ||
      signals != old.signals ||
      compact != old.compact ||
      interrupted != old.interrupted;
}
