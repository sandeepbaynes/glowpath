import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/rewards.dart';
import '../game/cargo.dart';
import 'cargo_art.dart';
import 'design.dart';
import 'observatory_art.dart';

/// A quiet collection invitation. Large text keeps the exact progress numbers
/// visible; the complete destination and unlock requirement remain semantic.
class RewardProgress extends StatelessWidget {
  const RewardProgress({
    super.key,
    required this.stars,
    required this.equippedTrail,
    required this.nextTrail,
    this.onOpen,
  });
  final int stars;
  final ShipTrail equippedTrail;
  final ShipTrail? nextTrail;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final next = nextTrail;
    final progress = next == null
        ? 1.0
        : (stars / next.requiredStars).clamp(0.0, 1.0);
    final description = next == null
        ? '$stars stars. All rocket trails unlocked. Open your collection.'
        : '$stars stars. ${next.requiredStars - stars} more to unlock the ${next.label} rocket trail. Open your collection.';
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Semantics(
      container: true,
      button: onOpen != null,
      label: description,
      onTap: onOpen,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          hoverColor: Palette.rust.withValues(alpha: .04),
          child: SizedBox(
            height: onOpen == null ? 40 : 48,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 34,
                  child: CustomPaint(
                    painter: RewardOrbitPainter(
                      progress,
                      Color((next ?? equippedTrail).colorValue),
                    ),
                    child: const Center(
                      child: StarMark(size: 16, color: Palette.light),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (large)
                  Expanded(
                    child: Text(
                      next == null
                          ? _count(stars)
                          : '${_count(stars)} / ${next.requiredStars}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: Palette.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  )
                else ...[
                  Text(
                    _count(stars),
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: Palette.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          next == null
                              ? 'Collection complete'
                              : 'Next · ${next.label}',
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1,
                            color: Palette.secondary,
                          ),
                        ),
                        const SizedBox(height: 7),
                        SizedBox(
                          height: 2,
                          child: CustomPaint(
                            painter: _RewardRail(
                              progress,
                              Color((next ?? equippedTrail).colorValue),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (onOpen != null) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Palette.secondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _count(int value) =>
    value < 10000 ? '$value' : '${(value / 1000).toStringAsFixed(1)}k';

/// A receipt for rewards already banked by the controller. It never gates play.
class CompletionRewardBadge extends StatelessWidget {
  const CompletionRewardBadge({super.key, required this.reward});
  final CompletionReward reward;
  @override
  Widget build(BuildContext context) {
    final unlocked = reward.newTrails.isEmpty ? null : reward.newTrails.last;
    final cargo = CargoKind.values
        .where((kind) => kind.name == reward.cargoId)
        .firstOrNull;
    final badges = [
      for (final item in achievementCatalog)
        if (reward.newAchievements.contains(item.id)) item.label,
    ];
    final headline = cargo != null
        ? '${cargo.label} secured'
        : unlocked != null
        ? '${unlocked.label} trail unlocked'
        : reward.weeklyMedal
        ? 'Expedition medal earned'
        : reward.dailyMedal
        ? 'Daily medal earned'
        : badges.isNotEmpty
        ? badges.first
        : reward.earnedStars > 0
        ? 'Added to your collection'
        : 'Route replay complete';
    final spoken = [
      if (reward.earnedStars > 0) '${reward.earnedStars} stars earned',
      if (reward.coinsEarned > 0) '${reward.coinsEarned} coins earned',
      if (cargo != null) '${cargo.label} added to your cargo collection',
      if (unlocked != null)
        '${unlocked.label} rocket trail unlocked and equipped',
      if (reward.dailyMedal) 'Daily medal earned',
      if (reward.weeklyMedal) 'Weekly expedition medal earned',
      ...badges.map((badge) => 'Achievement: $badge'),
      if (reward.earnedStars == 0) 'This route has already awarded its stars',
    ].join('. ');
    final accent = unlocked == null
        ? Palette.light
        : Color(unlocked.colorValue);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final compactTitle = cargo != null
        ? 'Cargo +1'
        : reward.coinsEarned > 0
        ? '+${reward.coinsEarned} coins'
        : unlocked != null
        ? '${unlocked.label} +${reward.earnedStars}'
        : reward.weeklyMedal
        ? 'Weekly +${reward.earnedStars}'
        : reward.dailyMedal
        ? 'Daily +${reward.earnedStars}'
        : reward.earnedStars > 0
        ? '+${reward.earnedStars} stars'
        : 'Replay';
    return Semantics(
      container: true,
      liveRegion: true,
      label: spoken,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              if (cargo != null)
                CargoMark(kind: cargo, size: large ? 32 : 44)
              else
                OrbitalEmblem(
                  size: large ? 32 : 44,
                  color: accent,
                  variant: unlocked?.index ?? (reward.weeklyMedal ? 3 : 1),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: large
                    ? Text(
                        compactTitle,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1,
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reward.coinsEarned > 0
                                ? '+${reward.coinsEarned} coins${reward.earnedStars > 0 ? ' · +${reward.earnedStars} stars' : ''}'
                                : reward.earnedStars > 0
                                ? '+${reward.earnedStars} stars'
                                : 'Stars already collected',
                            style: TextStyle(
                              fontSize: 16,
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            headline,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Palette.secondary,
                              height: 1.25,
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

class RewardOrbitPainter extends CustomPainter {
  const RewardOrbitPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final bounds = Rect.fromCircle(
      center: center,
      radius: size.shortestSide / 2 - 2,
    );
    canvas.drawCircle(
      center,
      bounds.width / 2,
      Paint()..color = color.withValues(alpha: .055),
    );
    canvas.drawArc(
      bounds,
      -.5 * math.pi,
      math.pi * 2,
      false,
      Paint()
        ..color = Palette.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawArc(
      bounds,
      -.5 * math.pi,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    final angle = -.5 * math.pi + math.pi * 2 * progress;
    canvas.drawCircle(
      center + Offset(math.cos(angle), math.sin(angle)) * (bounds.width / 2),
      2.2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(RewardOrbitPainter old) =>
      progress != old.progress || color != old.color;
}

class _RewardRail extends CustomPainter {
  const _RewardRail(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()
        ..color = Palette.line
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width * progress, size.height / 2),
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RewardRail old) =>
      progress != old.progress || color != old.color;
}
