import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/rewards.dart';
import '../game/cargo.dart';
import '../game/voyage_records.dart';
import 'cargo_gallery.dart';
import 'achievement_art.dart';
import 'design.dart';
import 'observatory_art.dart';
import 'orbital_craft.dart';
import 'scene_transition.dart';
import 'space_controls.dart';

/// A gallery, not a settings list. Every specimen can be previewed; only an
/// earned trail can be equipped. Compact displays page the full descriptions.
class RewardsPanel extends StatefulWidget {
  const RewardsPanel({
    super.key,
    required this.stars,
    required this.equippedTrail,
    required this.earnedAchievementIds,
    required this.dailyMedals,
    required this.weeklyMedals,
    required this.onEquip,
    this.reduceMotion = false,
    this.cargoCollection,
    this.coinBalance = 0,
    this.powerUps = const {},
    this.initialCargo = false,
    this.initialAchievements = false,
    this.initialCargoKind,
  });
  final int stars, dailyMedals, weeklyMedals;
  final ShipTrail equippedTrail;
  final Set<String> earnedAchievementIds;
  final ValueChanged<ShipTrail> onEquip;
  final bool reduceMotion;
  final Map<CargoKind, int>? cargoCollection;
  final int coinBalance;
  final Map<PowerUp, int> powerUps;
  final bool initialCargo;
  final bool initialAchievements;
  final CargoKind? initialCargoKind;
  @override
  State<RewardsPanel> createState() => _RewardsPanelState();
}

class _RewardsPanelState extends State<RewardsPanel>
    with WidgetsBindingObserver {
  late ShipTrail _preview = widget.equippedTrail;
  final ValueNotifier<double> _phase = ValueNotifier(0);
  Timer? _motion;
  late bool _medals =
      widget.initialAchievements &&
      !(widget.initialCargo && widget.cargoCollection != null);
  bool _details = false;
  late bool _cargo = widget.initialCargo && widget.cargoCollection != null;
  int _medalPage = 0, _detailPage = 0;
  bool get _still =>
      widget.reduceMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.reduceMotionOf(context);
  ShipTrail? get _next {
    for (final trail in ShipTrail.values) {
      if (widget.stars < trail.requiredStars) return trail;
    }
    return null;
  }

  bool get _unlocked => widget.stars >= _preview.requiredStars;
  bool get _equipped => widget.equippedTrail == _preview;
  String get _state => _equipped
      ? 'Equipped'
      : _unlocked
      ? 'Unlocked'
      : 'Locked';
  String get _trailAnnouncement =>
      '${_preview.label} rocket trail. ${_equipped
          ? 'Equipped.'
          : _unlocked
          ? 'Unlocked.'
          : 'Unlocks at ${_preview.requiredStars} stars.'}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(RewardsPanel old) {
    super.didUpdateWidget(old);
    if (old.equippedTrail != widget.equippedTrail &&
        _preview == old.equippedTrail) {
      _preview = widget.equippedTrail;
    }
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncMotion();
  void _syncMotion() {
    _motion?.cancel();
    _motion = null;
    final state = WidgetsBinding.instance.lifecycleState;
    if (_still || state != null && state != AppLifecycleState.resumed) return;
    // Only the preview repaint boundary ticks. Buttons, text and the rest of
    // the application do not rebuild with this gentle gallery animation.
    _motion = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _phase.value = (_phase.value + 1 / 240) % 1;
    });
  }

  @override
  void dispose() {
    _motion?.cancel();
    _phase.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: LayoutBuilder(
      builder: (context, bounds) {
        final height = bounds.hasBoundedHeight ? bounds.maxHeight : 520.0;
        final compact =
            height < 430 || MediaQuery.textScalerOf(context).scale(1) > 1.5;
        final focusedReading = compact && (_details || _medals);
        return SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!focusedReading)
                SizedBox(
                  height: compact ? 48 : 56,
                  child: Row(
                    children: [
                      Expanded(
                        child: OrbitMode(
                          key: const ValueKey('collection-trails'),
                          label: 'Trails',
                          selected: !_medals && !_cargo,
                          reduceMotion: _still,
                          onPressed: () => setState(() {
                            _medals = false;
                            _cargo = false;
                            _details = false;
                          }),
                        ),
                      ),
                      Expanded(
                        child: OrbitMode(
                          key: const ValueKey('collection-medals'),
                          label: 'Achievements',
                          selected: _medals,
                          reduceMotion: _still,
                          onPressed: () => setState(() {
                            _medals = true;
                            _cargo = false;
                            _details = false;
                          }),
                        ),
                      ),
                      if (widget.cargoCollection != null)
                        Expanded(
                          child: OrbitMode(
                            key: const ValueKey('collection-cargo'),
                            label: 'Cargo',
                            selected: _cargo,
                            reduceMotion: _still,
                            onPressed: () => setState(() {
                              _cargo = true;
                              _medals = false;
                              _details = false;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              if (!focusedReading) const SizedBox(height: 8),
              Expanded(
                child: SceneTransition(
                  reduceMotion: _still,
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey('$_medals/$_details/$_cargo'),
                    child: _cargo
                        ? CargoGallery(
                            initialKind: widget.initialCargoKind,
                            collection: widget.cargoCollection ?? const {},
                            coinBalance: widget.coinBalance,
                            powerUps: widget.powerUps,
                            reduceMotion: _still,
                          )
                        : _medals
                        ? _achievementGallery(compact)
                        : _details
                        ? _trailDetails()
                        : _trailGallery(compact),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _trailGallery(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: _GallerySwipe(
          key: const ValueKey('trail-carousel'),
          reduceMotion: _still,
          onPrevious: _preview.index > 0
              ? () => setState(
                  () => _preview = ShipTrail.values[_preview.index - 1],
                )
              : null,
          onNext: _preview.index + 1 < ShipTrail.values.length
              ? () => setState(
                  () => _preview = ShipTrail.values[_preview.index + 1],
                )
              : null,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: _trailAnnouncement,
            hint: 'Swipe left or right to preview trails. Tap an unlocked trail below to equip it.',
            child: LayoutBuilder(
              builder: (context, bounds) {
                final preview = RepaintBoundary(
                  child: ClipRect(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: Color(_preview.colorValue)),
                      duration: _still
                          ? Duration.zero
                          : const Duration(milliseconds: 360),
                      curve: Curves.easeInOutCubic,
                      builder: (context, color, _) => CustomPaint(
                        painter: _TrailGalleryPainter(
                          color ?? Color(_preview.colorValue),
                          _phase,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                );
                final info = OrbitUtility(
                  key: const ValueKey('collection-details'),
                  label: 'Trail details and unlock progress',
                  icon: Icons.info_outline_rounded,
                  onPressed: () => setState(() {
                    _details = true;
                    _detailPage = 0;
                  }),
                  reduceMotion: _still,
                  width: 48,
                );
                if (compact) {
                  return Stack(
                    children: [
                      Positioned.fill(child: ExcludeSemantics(child: preview)),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 50,
                        child: Text(
                          _preview.label,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            color: Palette.white,
                          ),
                        ),
                      ),
                      Positioned(top: 0, right: 0, child: info),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _statusLine(compact: true),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _preview.label,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.8,
                              color: Palette.white,
                            ),
                          ),
                        ),
                        info,
                      ],
                    ),
                    _statusLine(),
                    Expanded(child: ExcludeSemantics(child: preview)),
                    _unlockProgress(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: compact ? 48 : 64,
        child: Row(
          children: [
            for (final trail in ShipTrail.values) ...[
              if (trail != ShipTrail.values.first) const SizedBox(width: 4),
              Expanded(
                child: _TrailSpecimen(
                  key: ValueKey('trail-${trail.name}'),
                  trail: trail,
                  unlocked: widget.stars >= trail.requiredStars,
                  equipped: widget.equippedTrail == trail,
                  previewing: _preview == trail,
                  reduceMotion: _still,
                  onTap: () {
                    setState(() => _preview = trail);
                    if (widget.stars >= trail.requiredStars) {
                      widget.onEquip(trail);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _statusLine({bool compact = false}) => DecoratedBox(
    decoration: const BoxDecoration(),
    child: Row(
      children: [
        Icon(
          _equipped
              ? Icons.check_circle_outline_rounded
              : _unlocked
              ? Icons.radio_button_unchecked_rounded
              : Icons.lock_outline_rounded,
          size: compact ? 16 : 15,
          color: _unlocked ? Color(_preview.colorValue) : Palette.secondary,
        ),
        const SizedBox(width: 6),
        Text(
          _unlocked ? _state : '${_preview.requiredStars} stars',
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            height: 1.1,
            color: Palette.secondary,
          ),
        ),
        const Spacer(),
        const StarMark(size: 14, color: Palette.light),
        const SizedBox(width: 5),
        Text(
          '${widget.stars}',
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            height: 1.1,
            color: Palette.white,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  Widget _unlockProgress() {
    final next = _next;
    final fraction = next == null
        ? 1.0
        : (widget.stars / next.requiredStars).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  next == null
                      ? 'Every trail is yours'
                      : 'Next · ${next.label}',
                  style: const TextStyle(fontSize: 14, color: Palette.white),
                ),
              ),
              Text(
                next == null
                    ? '5 / 5'
                    : '${widget.stars} / ${next.requiredStars}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Palette.secondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 3,
            child: CustomPaint(
              painter: _CollectionProgressPainter(
                fraction,
                next == null ? Palette.rust : Color(next.colorValue),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Equip any trail below.'
                : '${next.requiredStars - widget.stars} stars to unlock. New routes earn three.',
            style: const TextStyle(fontSize: 12, color: Palette.secondary),
          ),
        ],
      ),
    );
  }

  Widget _trailDetails() {
    final next = _next;
    return _ReadingGallery(
      entries: [
        (
          _preview.label,
          _trailAnnouncement,
          Color(_preview.colorValue),
          _preview.index,
          _unlocked,
          null,
        ),
        (
          'Your progress',
          _unlocked
              ? '${widget.stars} stars collected. ${_preview.label} is yours. Tap any unlocked trail to equip it immediately.'
              : '${widget.stars} of ${_preview.requiredStars} stars collected. ${_preview.requiredStars - widget.stars} more stars unlock ${_preview.label}. Previewing a locked trail does not equip it.',
          Palette.rust,
          0,
          true,
          null,
        ),
        (
          'Next unlock',
          next == null
              ? 'All five trails are unlocked. Your collection is complete.'
              : '${next.label} is your next unlock at ${next.requiredStars} stars. You need ${next.requiredStars - widget.stars} more. Each new route clear earns three stars. Replays and skips earn none.',
          Palette.light,
          2,
          true,
          null,
        ),
      ],
      page: _detailPage,
      onPage: (page) => setState(() => _detailPage = page),
      onReturn: () => setState(() => _details = false),
      prefix: 'collection-details',
      reduceMotion: _still,
    );
  }

  Widget _achievementGallery(bool compact) {
    final earned = achievementCatalog
        .where((a) => widget.earnedAchievementIds.contains(a.id))
        .length;
    if (compact || MediaQuery.textScalerOf(context).scale(1) > 1.2) {
      return _ReadingGallery(
        entries: [
          (
            'Your flight record',
            '$earned of ${achievementCatalog.length} achievements earned. ${widget.dailyMedals} daily medals and ${widget.weeklyMedals} weekly expedition medals.',
            Palette.light,
            1,
            true,
            'navigator_25',
          ),
          for (final item in achievementCatalog)
            (
              item.label,
              '${item.label}. ${widget.earnedAchievementIds.contains(item.id) ? 'Earned.' : 'Not earned yet.'} ${item.description}',
              Palette.light,
              achievementCatalog.indexOf(item),
              widget.earnedAchievementIds.contains(item.id),
              item.id,
            ),
        ],
        page: _medalPage,
        onPage: (page) => setState(() => _medalPage = page),
        onReturn: compact ? () => setState(() => _medals = false) : null,
        prefix: 'medals',
        reduceMotion: _still,
      );
    }
    final index = _medalPage.clamp(0, achievementCatalog.length - 1);
    final achievement = achievementCatalog[index];
    final unlocked = widget.earnedAchievementIds.contains(achievement.id);
    return Column(
      children: [
        Text(
          '$earned / ${achievementCatalog.length} earned · ${widget.dailyMedals} daily · ${widget.weeklyMedals} weekly',
          style: const TextStyle(fontSize: 13, color: Palette.secondary),
        ),
        Expanded(
          child: _GallerySwipe(
            key: const ValueKey('achievement-carousel'),
            reduceMotion: _still,
            onPrevious: index > 0
                ? () => setState(() => _medalPage = index - 1)
                : null,
            onNext: index + 1 < achievementCatalog.length
                ? () => setState(() => _medalPage = index + 1)
                : null,
            child: Semantics(
              label:
                  '${achievement.label}. ${unlocked ? 'Earned.' : 'Not earned yet.'} ${achievement.description}',
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, bounds) => Center(
                    child: SceneTransition(
                      reduceMotion: _still,
                      child: Column(
                        key: ValueKey(achievement.id),
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AchievementArtwork(
                            id: achievement.id,
                            size: math.min(
                              bounds.maxWidth * .78,
                              math.min(
                                (bounds.maxHeight * .50).clamp(96.0, 280.0),
                                _artHeight(context, bounds, achievement),
                              ),
                            ),
                            earned: unlocked,
                            phase: _phase,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            achievement.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                              color: Palette.white,
                              letterSpacing: -.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            achievement.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Palette.secondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            unlocked ? 'EARNED' : 'TO DISCOVER',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: unlocked
                                  ? Palette.light
                                  : Palette.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _CollectionPager(
          prefix: 'medals',
          page: index,
          count: achievementCatalog.length,
          onPage: (page) => setState(() => _medalPage = page),
          reduceMotion: _still,
        ),
      ],
    );
  }
}

// Reserve the actual scaled copy before sizing the artwork. Long award names
// and larger type keep their full lines; the illustration gives space first.
double _artHeight(
  BuildContext context,
  BoxConstraints bounds,
  Achievement achievement,
) {
  double height(String copy, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: copy,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: bounds.maxWidth);
    final result = painter.height;
    painter.dispose();
    return result;
  }

  return math.max(
    32,
    bounds.maxHeight -
        40 -
        height(
          achievement.label,
          const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            letterSpacing: -.4,
          ),
        ) -
        height(
          achievement.description,
          const TextStyle(fontSize: 15, height: 1.4),
        ) -
        height('TO DISCOVER', const TextStyle(fontSize: 11, letterSpacing: 2)),
  );
}

typedef _GalleryEntry = (
  String title,
  String text,
  Color color,
  int emblem,
  bool earned,
  String? achievementId,
);

class _ReadingGallery extends StatelessWidget {
  const _ReadingGallery({
    required this.entries,
    required this.page,
    required this.onPage,
    required this.prefix,
    required this.reduceMotion,
    this.onReturn,
  });
  final List<_GalleryEntry> entries;
  final int page;
  final ValueChanged<int> onPage;
  final String prefix;
  final bool reduceMotion;
  final VoidCallback? onReturn;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final style = DefaultTextStyle.of(context).style.merge(
        const TextStyle(fontSize: 16, height: 1.3, color: Palette.white),
      );
      final pages = <(_GalleryEntry entry, String text)>[];
      for (final entry in entries) {
        for (final text in _readingPages(
          entry.$2,
          style,
          MediaQuery.textScalerOf(context),
          Directionality.of(context),
          bounds.maxWidth - 16,
          bounds.maxHeight - 72,
        )) {
          pages.add((entry, text));
        }
      }
      final selected = page.clamp(0, pages.length - 1);
      final item = pages[selected];
      return Column(
        children: [
          Expanded(
            child: _GallerySwipe(
              key: ValueKey('$prefix-carousel'),
              reduceMotion: reduceMotion,
              onPrevious: selected > 0 ? () => onPage(selected - 1) : null,
              onNext: selected + 1 < pages.length
                  ? () => onPage(selected + 1)
                  : null,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: Opacity(
                        opacity: .07,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: item.$1.$6 != null
                              ? AchievementArtwork(
                                  id: item.$1.$6!,
                                  size: math.min(
                                    bounds.maxWidth * .7,
                                    bounds.maxHeight - 64,
                                  ),
                                  earned: item.$1.$5,
                                )
                              : OrbitalEmblem(
                                  size: math.min(
                                    bounds.maxWidth * .7,
                                    bounds.maxHeight - 64,
                                  ),
                                  color: item.$1.$3,
                                  variant: item.$1.$4,
                                  active: item.$1.$5,
                                ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Semantics(
                      key: ValueKey('$prefix-copy-$selected'),
                      label: item.$1.$2,
                      liveRegion: true,
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item.$2,
                              key: ValueKey('$prefix-body'),
                              style: style,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _CollectionPager(
            prefix: prefix,
            page: selected,
            count: pages.length,
            onPage: onPage,
            onReturn: onReturn,
            reduceMotion: reduceMotion,
          ),
        ],
      );
    },
  );
}

/// A horizontal, direct-manipulation carousel that never takes vertical space
/// from the page. Paging buttons stay fixed while the specimen settles.
class _GallerySwipe extends StatefulWidget {
  const _GallerySwipe({
    super.key,
    required this.child,
    required this.reduceMotion,
    this.onPrevious,
    this.onNext,
  });
  final Widget child;
  final bool reduceMotion;
  final VoidCallback? onPrevious, onNext;
  @override
  State<_GallerySwipe> createState() => _GallerySwipeState();
}

class _GallerySwipeState extends State<_GallerySwipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 330),
    value: 1,
  );
  double _drag = 0, _offset = 0;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _release(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final intent = _drag.abs() > 36 || velocity.abs() > 400 && _drag.abs() > 8;
    final forward = _drag.abs() > 36 ? _drag < 0 : velocity < 0;
    final turn = forward ? widget.onNext : widget.onPrevious;
    if (intent && turn != null) {
      turn();
      _offset = forward ? 42 : -42;
    }
    if (widget.reduceMotion) {
      setState(() => _offset = 0);
    } else {
      _settle.forward(from: 0);
    }
    _drag = 0;
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _settle.stop();
        _drag = 0;
      },
      onHorizontalDragUpdate: (details) {
        _drag += details.delta.dx;
        final allowed = _drag < 0
            ? widget.onNext != null
            : widget.onPrevious != null;
        setState(() {
          _offset = widget.reduceMotion
              ? 0
              : (_drag * (allowed ? .28 : .10)).clamp(-55.0, 55.0);
          _settle.value = 0;
        });
      },
      onHorizontalDragEnd: _release,
      onHorizontalDragCancel: () {
        _drag = 0;
        _settle.forward(from: 0);
      },
      child: AnimatedBuilder(
        animation: _settle,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            widget.reduceMotion
                ? 0
                : _offset * (1 - Curves.easeOutCubic.transform(_settle.value)),
            0,
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _CollectionPager extends StatelessWidget {
  const _CollectionPager({
    required this.prefix,
    required this.page,
    required this.count,
    required this.onPage,
    required this.reduceMotion,
    this.onReturn,
  });
  final String prefix;
  final int page, count;
  final ValueChanged<int> onPage;
  final VoidCallback? onReturn;
  final bool reduceMotion;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        _GalleryAction(
          key: ValueKey('$prefix-previous'),
          label: 'Previous',
          icon: Icons.chevron_left_rounded,
          onPressed: page > 0 ? () => onPage(page - 1) : null,
          reduceMotion: reduceMotion,
        ),
        Expanded(
          child: Semantics(
            label: 'Page ${page + 1} of $count',
            child: ExcludeSemantics(
              child: Text(
                '${page + 1}/$count',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Palette.secondary),
              ),
            ),
          ),
        ),
        if (onReturn != null)
          _GalleryAction(
            key: ValueKey('$prefix-return'),
            label: 'Back to trail preview',
            icon: Icons.rocket_launch_outlined,
            onPressed: onReturn,
            reduceMotion: reduceMotion,
          ),
        _GalleryAction(
          key: ValueKey('$prefix-next'),
          label: 'Next',
          icon: Icons.chevron_right_rounded,
          onPressed: page + 1 < count ? () => onPage(page + 1) : null,
          reduceMotion: reduceMotion,
        ),
      ],
    ),
  );
}

class _GalleryAction extends StatelessWidget {
  const _GalleryAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.reduceMotion,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool reduceMotion;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    onTap: onPressed,
    child: ExcludeSemantics(
      child: ExcludeFocus(
        excluding: onPressed == null,
        child: IgnorePointer(
          ignoring: onPressed == null,
          child: Opacity(
            opacity: onPressed == null ? .3 : 1,
            child: OrbitUtility(
              label: label,
              icon: icon,
              onPressed: onPressed ?? () {},
              reduceMotion: reduceMotion,
              width: 56,
            ),
          ),
        ),
      ),
    ),
  );
}

class _TrailSpecimen extends StatelessWidget {
  const _TrailSpecimen({
    super.key,
    required this.trail,
    required this.unlocked,
    required this.equipped,
    required this.previewing,
    required this.reduceMotion,
    required this.onTap,
  });
  final ShipTrail trail;
  final bool unlocked, equipped, previewing, reduceMotion;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: equipped,
    label: '${trail.label} rocket trail',
    hint: equipped
        ? 'Equipped'
        : unlocked
        ? 'Tap to equip'
        : 'Locked. ${trail.requiredStars} stars required. Tap to preview.',
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: Color(trail.colorValue)
                  .withValues(alpha: previewing ? .08 : .015),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Color(trail.colorValue)
                    .withValues(alpha: previewing ? .65 : .15),
                width: .8,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrailSpecimenPainter(Color(trail.colorValue)),
                  ),
                ),
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Icon(
                    equipped
                        ? Icons.check_rounded
                        : unlocked
                        ? Icons.circle
                        : Icons.lock_outline_rounded,
                    size: unlocked && !equipped ? 3 : 11,
                    color: unlocked ? Palette.white : Palette.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _TrailSpecimenPainter extends CustomPainter {
  const _TrailSpecimenPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final route = Path()
      ..moveTo(size.width * .15, size.height * .6)
      ..cubicTo(
        size.width * .35,
        size.height * .6,
        size.width * .45,
        size.height * .28,
        size.width * .78,
        size.height * .35,
      );
    for (final (width, opacity) in [(7.0, .08), (3.0, .28), (1.2, .95)]) {
      canvas.drawPath(
        route,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: opacity),
      );
    }
    canvas.drawCircle(
      Offset(size.width * .78, size.height * .35),
      2,
      Paint()..color = Palette.white,
    );
  }

  @override
  bool shouldRepaint(_TrailSpecimenPainter old) => color != old.color;
}

class _TrailGalleryPainter extends CustomPainter {
  _TrailGalleryPainter(this.color, this.phase) : super(repaint: phase);
  final Color color;
  final ValueNotifier<double> phase;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    final angle = math.pi * .32 + math.sin(phase.value * math.pi * 2) * .025;
    final scale = math.min(size.width * .135, size.height * .29);
    final center = Offset(
      size.width * .67,
      size.height * (.42 + math.sin(phase.value * math.pi * 2) * .025),
    );
    final engine =
        center + Offset(-math.sin(angle), math.cos(angle)) * scale * .88;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.3, -.1),
          radius: .75,
          colors: [color.withValues(alpha: .075), color.withValues(alpha: 0)],
        ).createShader(bounds),
    );
    final orbit = Rect.fromCenter(
      center: Offset(size.width * .54, size.height * .6),
      width: size.width * .94,
      height: size.height * .7,
    );
    canvas.drawOval(
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = Palette.secondary.withValues(alpha: .1),
    );
    final path = Path()
      ..moveTo(size.width * .04, size.height * .86)
      ..cubicTo(
        size.width * .28,
        size.height * 1.03,
        engine.dx - size.width * .26,
        engine.dy + size.height * .16,
        engine.dx,
        engine.dy,
      );
    for (final (width, alpha) in [
      (30.0, .018),
      (14.0, .055),
      (5.0, .15),
      (1.5, .85),
    ]) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              color.withValues(alpha: 0),
              color.withValues(alpha: alpha),
            ],
          ).createShader(bounds),
      );
    }
    final metric = path.computeMetrics().first;
    for (var i = 0; i < 11; i++) {
      final progress = (i / 11 + phase.value) % 1;
      final tangent = metric.getTangentForOffset(metric.length * progress)!;
      canvas.drawCircle(
        tangent.position,
        .7 + progress * 1.15,
        Paint()
          ..color = Color.lerp(
            color,
            Palette.white,
            progress * .3,
          )!.withValues(alpha: progress * .65),
      );
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    drawOrbitalCraft(canvas, accent: color);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrailGalleryPainter old) =>
      color != old.color || phase != old.phase;
}

class _CollectionProgressPainter extends CustomPainter {
  const _CollectionProgressPainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(0, size.height / 2),
        end = Offset(size.width, size.height / 2);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = Palette.line
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      Offset.lerp(start, end, progress)!,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CollectionProgressPainter old) =>
      progress != old.progress || color != old.color;
}

List<String> _readingPages(
  String text,
  TextStyle style,
  TextScaler scaler,
  TextDirection direction,
  double width,
  double height,
) {
  bool fits(String value) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textScaler: scaler,
      textDirection: direction,
    )..layout(maxWidth: width);
    final result = painter.height <= height;
    painter.dispose();
    return result;
  }

  final result = <String>[];
  var line = '';
  for (final word in text.split(' ')) {
    final next = line.isEmpty ? word : '$line $word';
    if (line.isEmpty || fits(next)) {
      line = next;
    } else {
      result.add(line);
      line = word;
    }
  }
  if (line.isNotEmpty) result.add(line);
  return result;
}
