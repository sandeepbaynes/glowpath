import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/game_controller.dart';
import 'cargo_art.dart';
import 'cargo_gallery.dart';
import 'design.dart';
import 'observatory_art.dart';
import 'scene_transition.dart';
import 'space_controls.dart';

/// Earned coins buy explicit resources, never a random roll. Purchasing a
/// charge and using it are separate actions; skipped flights grant no rewards.
class EarnedSupplyPanel extends StatefulWidget {
  const EarnedSupplyPanel({
    super.key,
    required this.game,
    required this.onHint,
    required this.onSkip,
    required this.onUsePower,
    required this.onLegacyStore,
    this.canUse = true,
    this.canSkip = true,
    this.initialPage = 0,
    this.reduceMotion = false,
  });
  final GameController game;
  final VoidCallback onHint, onSkip, onLegacyStore;
  final ValueChanged<PowerUp> onUsePower;
  final bool canUse, canSkip, reduceMotion;
  final int initialPage;
  @override
  State<EarnedSupplyPanel> createState() => _EarnedSupplyPanelState();
}

class _EarnedSupplyPanelState extends State<EarnedSupplyPanel> {
  late int _page = widget.initialPage.clamp(0, 3);
  bool _details = false;
  String? _notice;
  static const _names = ['Hint', 'Skip', 'Time', 'Lens'];
  bool get _still =>
      widget.reduceMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.reduceMotionOf(context);
  PowerUp? get _power => switch (_page) {
    2 => PowerUp.timeCell,
    3 => PowerUp.routeLens,
    _ => null,
  };
  CargoKind? get _kind => switch (_page) {
    0 || 3 => CargoKind.routeLens,
    2 => CargoKind.chronoCell,
    _ => null,
  };
  int get _cost => switch (_page) {
    0 => 10,
    1 => 75,
    _ => 25,
  };
  String get _title => switch (_page) {
    0 => 'Route hint',
    1 => 'Skip route',
    2 => 'Time cell',
    _ => 'Route lens',
  };
  int get _count => _page == 0
      ? widget.game.hintCredits
      : _power != null
      ? widget.game.powerUpCount(_power!)
      : 0;
  bool get _canSkip =>
      widget.canSkip &&
      widget.canUse &&
      widget.game.ready &&
      !widget.game.status.solved &&
      widget.game.mode == GameMode.voyage &&
      !widget.game.isReplaying &&
      widget.game.coinBalance >= 75;
  bool get _canUse =>
      widget.canUse &&
      widget.game.ready &&
      !widget.game.status.solved &&
      switch (_page) {
        0 => _count > 0 && widget.game.suggestedHintIndex != null,
        2 => widget.game.canUseTimeCell,
        3 => _count > 0 && widget.game.suggestedHintIndex != null,
        _ => false,
      };
  String get _description => switch (_page) {
    0 =>
      'A nudge toward the next legal turn. Store it, then use it on the board.',
    1 => 'Move on without a score, stars or cargo. Your earlier records stay saved.',
    2 => 'Eight extra seconds for a future flight. One time cell per attempt.',
    _ => 'Align up to three relays on a legal route. Store a charge for when you need it.',
  };
  String get _detailsText =>
      '$_title. $_description '
      'Costs $_cost earned coins. ${_page == 1 ? '' : '$_count stored. '}'
      'You have ${widget.game.coinBalance} coins. '
      '${_page == 1 ? 'Skips are available on your current Voyage route, not on replays or daily and weekly challenges. ' : 'Buying stores a resource; it is only used when you choose Use. '} '
      'Hints and powers mark the result as assisted. Earn coins by completing new routes, improving score tiers and collecting optional cargo. '
      'This shelf spends game coins, not money.';

  void _buy() {
    final bought = _page == 0
        ? widget.game.buyHint()
        : widget.game.buyPowerUp(_power!);
    setState(
      () => _notice = bought
          ? '$_title stored · $_cost coins spent'
          : 'More coins needed',
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.game,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        if (_details) {
          return SpecimenReadingView(
            key: ValueKey('supply-reading-$_page'),
            text: _detailsText,
            kind: _kind,
            reduceMotion: _still,
            onBack: () => setState(() => _details = false),
          );
        }
        final compact =
            bounds.maxHeight < 360 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5;
        final balance = widget.game.coinBalance;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const CoinMark(size: 25),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      label: '$balance earned coins',
                      liveRegion: true,
                      child: ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('$balance coins', style: bookTitle(22)),
                        ),
                      ),
                    ),
                  ),
                  OrbitUtility(
                    key: const ValueKey('earned-supply-details'),
                    label: 'Resource details and coin rules',
                    icon: Icons.info_outline_rounded,
                    width: 48,
                    reduceMotion: _still,
                    onPressed: () => setState(() => _details = true),
                  ),
                  OrbitUtility(
                    key: const ValueKey('earned-supply-store'),
                    label: 'Ads and purchases',
                    icon: Icons.shopping_bag_outlined,
                    width: 48,
                    reduceMotion: _still,
                    onPressed: widget.onLegacyStore,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SceneTransition(
                reduceMotion: _still,
                duration: const Duration(milliseconds: 220),
                child: Semantics(
                  key: ValueKey('supply-specimen-$_page'),
                  label:
                      '$_title. $_description ${_page == 1 ? '' : '$_count stored.'} Costs $_cost coins.',
                  child: ExcludeSemantics(
                    child: LayoutBuilder(
                      builder: (context, area) {
                        final iconSize = math.max(
                          20.0,
                          math.min(
                            area.maxHeight * .65,
                            compact ? 82.0 : 180.0,
                          ),
                        );
                        final art = _kind == null
                            ? OrbitalEmblem(
                                size: iconSize,
                                variant: 1,
                                color: Palette.light,
                              )
                            : CargoMark(kind: _kind!, size: iconSize);
                        if (compact) {
                          return Row(
                            children: [
                              if (area.maxHeight > 45) art,
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: math.min(28, area.maxHeight * .5),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _title,
                                          style: bookTitle(22),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: math.min(
                                        24,
                                        area.maxHeight * .45,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _page == 1
                                              ? widget.game.isReplaying
                                                    ? 'Replays cannot skip'
                                                    : 'No rewards for skips'
                                              : '$_count stored${_page == 2 ? ' · +8s' : ''}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Palette.secondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            const SizedBox(height: 6),
                            Text(_title, style: bookTitle(28)),
                            Expanded(child: Center(child: art)),
                            Text(
                              _description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                color: Palette.secondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _notice ??
                                  (_page == 1
                                      ? (widget.game.isReplaying
                                            ? 'Return to your current route to skip.'
                                            : 'A direct jump to the next route.')
                                      : '$_count ${_count == 1 ? 'charge' : 'charges'} stored'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Palette.rust,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (_notice != null)
              Semantics(
                liveRegion: true,
                label: _notice,
                child: const SizedBox.shrink(),
              ),
            const SizedBox(height: 6),
            SizedBox(
              height: compact ? 48 : 54,
              child: Row(
                children: [
                  Expanded(
                    child: SpaceAction(
                      key: ValueKey('earned-supply-buy-$_page'),
                      label: _page == 1
                          ? 'Skip · 75 coins'
                          : 'Buy · $_cost coins',
                      compact: compact,
                      reduceMotion: _still,
                      onPressed: _page == 1
                          ? (_canSkip ? widget.onSkip : null)
                          : (widget.game.ready && balance >= _cost
                                ? _buy
                                : null),
                    ),
                  ),
                  if (_page != 1) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: SpaceAction(
                        key: ValueKey('earned-supply-use-$_page'),
                        label: _page == 2 ? 'Use · +8s' : 'Use',
                        compact: compact,
                        quiet: true,
                        accent: Palette.rust,
                        reduceMotion: _still,
                        onPressed: _canUse
                            ? () {
                                if (_page == 0) {
                                  widget.onHint();
                                } else {
                                  widget.onUsePower(_power!);
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: compact ? 48 : 56,
              child: Row(
                children: [
                  for (var page = 0; page < _names.length; page++)
                    Expanded(
                      child: OrbitMode(
                        key: ValueKey('earned-supply-page-$page'),
                        label: _names[page],
                        selected: _page == page,
                        reduceMotion: _still,
                        onPressed: () => setState(() {
                          _page = page;
                          _notice = null;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
