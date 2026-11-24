import 'package:material_ui/material_ui.dart';

import '../services/flight_support.dart';
import 'space_controls.dart';
import 'design.dart';
import 'observatory_art.dart';

/// One resource at a time keeps every action visible without a scrolling shop.
class FlightSupportPanel extends StatefulWidget {
  const FlightSupportPanel({
    super.key,
    required this.support,
    required this.onSkip,
    this.reduceMotion = false,
    this.canSkip = false,
    this.initialPage = 1,
  });
  final FlightSupport support;
  final VoidCallback onSkip;
  final bool reduceMotion, canSkip;
  final int initialPage;
  @override
  State<FlightSupportPanel> createState() => _FlightSupportPanelState();
}

class _FlightSupportPanelState extends State<FlightSupportPanel> {
  late int _page = widget.initialPage;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.support,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final support = widget.support;
        final dense =
            bounds.maxHeight < 450 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5;
        final preview = support.isMock;
        final rewards =
            (preview || FlightSupport.adsEnabled) && !support.adFree;
        final skipReady =
            widget.canSkip &&
            !support.busy &&
            (support.reviewMode || support.adFree || support.skipCredits > 0);
        final heading = switch (_page) {
          0 =>
            support.adFree || support.reviewMode
                ? (dense ? '∞ hints' : 'Hints included')
                : '${support.hintCredits} hints',
          1 =>
            support.adFree || support.reviewMode
                ? (dense ? '∞ skips' : 'Skips included')
                : '${support.skipCredits} ${support.skipCredits == 1 ? 'skip' : 'skips'}',
          _ =>
            support.adFree
                ? (dense ? 'Unlocked' : 'Ad-free flight')
                : (dense ? 'Ad-free' : 'Remove ads'),
        };
        final explanation = switch (_page) {
          0 => dense ? 'One legal turn.' : 'Get one legal turn when you need a nudge. Return to the board to use it.',
          1 => dense ? 'No stars.' : 'Move to the next Voyage route. A skip earns no stars or league score.',
          _ =>
            dense
                ? 'Hints & skips.'
                : 'One purchase includes ad-free play, hints and Voyage skips.',
        };
        final shortWide = bounds.maxWidth > 460 && bounds.maxHeight < 420;
        final summary = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preview && shortWide)
              const Text(
                'DEMO',
                style: TextStyle(color: Palette.rust, fontSize: 10),
              ),
            if (!dense) ...[
              OrbitalEmblem(
                size: 86,
                variant: _page + 1,
                color: _page == 2 ? Palette.light : Palette.rust,
              ),
              const SizedBox(height: 14),
            ],
            Text(
              heading,
              textAlign: TextAlign.center,
              style: bookTitle(dense ? 16 : 32),
            ),
            SizedBox(height: dense ? 4 : 12),
            Text(
              explanation,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Palette.secondary,
                fontSize: dense ? 11 : 14,
                height: 1.4,
              ),
            ),
          ],
        );
        final actions = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_page == 1) ...[
              SpaceAction(
                key: const ValueKey('skip-level'),
                label: dense ? 'Skip' : 'Skip this route',
                compact: true,
                onPressed: skipReady
                    ? () {
                        if (support.consumeSkip()) widget.onSkip();
                      }
                    : null,
                reduceMotion: widget.reduceMotion,
              ),
              if (rewards) const SizedBox(height: 8),
            ],
            if (_page < 2 && rewards)
              SpaceAction(
                key: ValueKey(_page == 0 ? 'reward-hints' : 'reward-skip'),
                label: preview && dense
                    ? (_page == 0 ? '+3 hints' : '+1 skip')
                    : preview
                    ? (_page == 0 ? 'Preview +3 hints' : 'Preview +1 skip')
                    : (_page == 0 ? 'Watch ad · 3 hints' : 'Watch ad · 1 skip'),
                compact: true,
                onPressed: support.busy
                    ? null
                    : () => support.earnReward(skip: _page == 1),
                reduceMotion: widget.reduceMotion,
              ),
            if (_page == 2) ...[
              SpaceAction(
                key: const ValueKey('remove-ads'),
                label: support.adFree
                    ? 'Unlocked'
                    : preview
                    ? (dense ? 'Unlock' : 'Preview unlock')
                    : support.canBuy
                    ? 'Remove ads · ${support.price}'
                    : 'Store opens at launch',
                compact: true,
                onPressed: support.canBuy && !support.adFree
                    ? support.buy
                    : null,
                reduceMotion: widget.reduceMotion,
              ),
              if (preview || FlightSupport.purchasesEnabled) ...[
                const SizedBox(height: 8),
                SpaceAction(
                  label: preview
                      ? (dense ? 'Restore' : 'Preview restore')
                      : 'Restore purchases',
                  quiet: true,
                  compact: true,
                  onPressed: support.busy ? null : support.restore,
                  reduceMotion: widget.reduceMotion,
                ),
              ],
            ],
            if (support.message != null && dense)
              Semantics(
                liveRegion: true,
                label: support.message,
                child: const SizedBox.shrink(),
              ),
            if (support.message != null && !dense)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    support.message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Palette.rust, fontSize: 13),
                  ),
                ),
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview && !shortWide)
              Semantics(
                label: 'Local preview. Rewards are simulated. No advertisement or payment.',
                child: ExcludeSemantics(
                  child: Text(
                    dense ? 'DEMO' : 'DEMO / NO ADS OR PAYMENTS',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Palette.rust,
                      fontSize: 10,
                      letterSpacing: .6,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: widget.reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_page),
                  child: shortWide
                      ? Row(
                          children: [
                            Expanded(child: summary),
                            const SizedBox(width: 20),
                            Expanded(child: actions),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            SizedBox(height: dense ? 6 : 26),
                            actions,
                          ],
                        ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (index, title) in [
                  'Hints',
                  'Skips',
                  'Ad-free',
                ].indexed)
                  Expanded(
                    child: OrbitMode(
                      label: title,
                      selected: _page == index,
                      onPressed: () => setState(() => _page = index),
                      reduceMotion: widget.reduceMotion,
                    ),
                  ),
              ],
            ),
            if (!preview && FlightSupport.adsEnabled)
              TextButton(
                onPressed: support.privacyOptions,
                child: const Text('Ad privacy choices'),
              ),
          ],
        );
      },
    ),
  );
}
