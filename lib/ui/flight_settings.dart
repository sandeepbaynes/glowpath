import 'package:material_ui/material_ui.dart';

import '../game/game_controller.dart';
import '../game/puzzle.dart';
import '../game/launch_clock.dart';
import 'console_toggle.dart';
import 'flight_page_surface.dart';
import 'flight_pace_choice.dart';
import 'design.dart';
import 'reward_progress.dart';
import 'space_controls.dart';
import 'scene_transition.dart';

/// A flight desk with live visual previews. Larger type uses focused pages;
/// both gestures and explicit controls keep every setting reachable.
class FlightSettings extends StatefulWidget {
  const FlightSettings({
    super.key,
    required this.game,
    required this.onRestart,
    required this.onSupport,
    required this.onLeague,
    required this.onRewards,
    required this.onLicenses,
    this.demo = false,
  });
  final GameController game;
  final VoidCallback onRestart, onSupport, onLeague, onRewards, onLicenses;
  final bool demo;
  @override
  State<FlightSettings> createState() => _FlightSettingsState();
}

class _FlightSettingsState extends State<FlightSettings> {
  int _section = 0, _page = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.game,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final game = widget.game;
        final reduced =
            game.reduceMotion ||
            MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.reduceMotionOf(context);
        final systemReduced =
            MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.reduceMotionOf(context);
        final largeType = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
        final dense = largeType || bounds.maxHeight < 500;
        final roomy = !dense;

        final restart = SpaceAction(
          key: const ValueKey('restart'),
          label: 'Restart route',
          icon: Icons.refresh_rounded,
          quiet: true,
          compact: true,
          reduceMotion: reduced,
          onPressed: game.canRestart ? widget.onRestart : null,
        );
        final paceChoices = <Widget>[
          for (final difficulty in Difficulty.values)
            FlightPaceChoice(
              key: ValueKey('pace-${difficulty.name}'),
              label: switch (difficulty) {
                Difficulty.gentle => 'Gentle',
                Difficulty.balanced => 'Steady',
                Difficulty.bright => 'Bright',
              },
              description:
                  '${switch (difficulty) {
                    Difficulty.gentle => 'Alternate route',
                    Difficulty.balanced => 'Default route',
                    Difficulty.bright => 'Faster clock',
                  }} · ${launchBudget(difficulty: difficulty, level: game.journeyLevel, progressive: true).inSeconds}s',
              selected: game.difficulty == difficulty,
              onPressed: () => game.setDifficulty(difficulty),
              reduceMotion: reduced,
            ),
        ];
        final pace = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!dense || bounds.maxHeight > 350) ...[
              Text('Voyage pace', style: bookTitle(dense ? 18 : 24)),
              const SizedBox(height: 6),
              Text(
                game.isReplaying
                    ? 'Replays keep their recorded pace.'
                    : game.mode == GameMode.voyage
                    ? 'Changes restart Voyage. Challenges stay fixed.'
                    : 'Used in Voyage. This challenge stays unchanged.',
                style: const TextStyle(
                  color: Palette.secondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (dense && bounds.maxWidth > 450)
              Row(
                children: [
                  for (final (index, choice) in paceChoices.indexed) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(child: choice),
                  ],
                ],
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, choice) in paceChoices.indexed) ...[
                    if (index > 0) const SizedBox(height: 6),
                    choice,
                  ],
                ],
              ),
          ],
        );
        final pacePages = largeType ? paceChoices : <Widget>[pace];
        final resourceActions = <Widget>[
          SpaceAction(
            key: const ValueKey('open-flight-support'),
            label: dense ? 'Flight support' : 'Support',
            icon: Icons.auto_awesome_outlined,
            quiet: true,
            compact: true,
            onPressed: widget.onSupport,
            reduceMotion: reduced,
          ),

          SpaceAction(
            key: const ValueKey('open-league'),
            label: dense ? 'Flight league' : 'League',
            icon: Icons.emoji_events_outlined,
            quiet: true,
            compact: true,
            onPressed: widget.onLeague,
            reduceMotion: reduced,
          ),
        ];
        final resources = Row(
          children: [
            Expanded(
              child: Semantics(
                hint: 'Hints and skips',
                child: resourceActions[0],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: resourceActions[1]),
          ],
        );
        final toggles = <Widget>[
          ConsoleToggle(
            key: const ValueKey('reduce-motion'),
            compact: dense,
            title: 'Reduce motion',
            subtitle: systemReduced
                ? 'Enabled by your device.'
                : dense
                ? 'Calm skies. Instant turns.'
                : 'Still skies and instant turns. The same journey.',
            value: game.reduceMotion || systemReduced,
            onChanged: systemReduced ? null : game.setReduceMotion,
          ),
          ConsoleToggle(
            key: const ValueKey('high-contrast'),
            compact: dense,
            title: 'Stronger contrast',
            subtitle: dense
                ? 'Brighter paths. Clearer signals.'
                : 'Brighter channels and a dot on every lit relay.',
            value: game.highContrast,
            onChanged: game.setHighContrast,
          ),
          ConsoleToggle(
            key: const ValueKey('haptics'),
            compact: dense,
            title: 'Touch feedback',
            subtitle: dense
                ? 'Feel turns and launch pressure.'
                : 'A precise tap response and final-countdown pulses.',
            value: game.haptics,
            onChanged: game.setHaptics,
          ),
        ];
        final collectionProgress = RewardProgress(
          key: const ValueKey('settings-rewards'),
          stars: game.stars,
          equippedTrail: game.equippedTrail,
          nextTrail: game.nextTrail,
          onOpen: widget.onRewards,
        );
        final collectionHeading = Text(
          dense ? 'Collection' : 'Your collection',
          style: bookTitle(dense ? 18 : 24),
        );
        final collectionStats = Text(
          dense && bounds.maxWidth > 450
              ? 'Best ${game.bestTimedScore}'
              : '${game.stars} stars · ${game.bestTimedScore} best',
          style: const TextStyle(
            color: Palette.secondary,
            fontSize: 14,
            height: 1.2,
          ),
        );
        final collection = dense && bounds.maxWidth > 450
            ? Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        collectionHeading,
                        const SizedBox(height: 8),
                        collectionStats,
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: collectionProgress),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!dense)
                    const SizedBox(
                      height: 100,
                      child: FlightLessonArt(kind: 'rewards'),
                    ),
                  collectionHeading,
                  const SizedBox(height: 8),
                  collectionProgress,
                  const SizedBox(height: 8),
                  collectionStats,
                ],
              );
        final licenses = SpaceAction(
          key: const ValueKey('open-licenses'),
          label: 'Credits & licenses',
          quiet: true,
          compact: true,
          onPressed: widget.onLicenses,
          reduceMotion: reduced,
          icon: Icons.info_outline_rounded,
        );
        final privacyColumn = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              dense
                  ? (widget.demo ? 'Preview' : 'Local data')
                  : (widget.demo ? 'Local preview' : 'Your flight data'),
              style: bookTitle(dense ? 18 : 24),
            ),
            const SizedBox(height: 10),
            Text(
              widget.demo
                  ? (dense
                        ? 'No ads. No payments.'
                        : 'Your voyage stays on this device. League rivals and ad rewards are simulated.')
                  : (dense
                        ? 'Saved on this device.'
                        : 'Your voyage saves locally. Joining the league shares challenge scores under an anonymous callsign.'),
              style: TextStyle(
                fontSize: dense ? 13 : 15,
                color: Palette.secondary,
                height: 1.5,
              ),
            ),
            if (!dense) ...[const SizedBox(height: 18), licenses],
            if (!dense)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'GLOWPATH  /  0.10.7',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Palette.secondary,
                  ),
                ),
              ),
          ],
        );
        final privacy = dense && bounds.maxWidth > 450
            ? Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      widget.demo ? 'Preview' : 'Local data',
                      style: bookTitle(18),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: Text(
                      widget.demo
                          ? 'No ads. No payments.'
                          : 'Saved on this device.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Palette.secondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              )
            : privacyColumn;
        final pages = switch (_section) {
          0 =>
            dense
                ? <Widget>[restart, ...pacePages, ...resourceActions]
                : <Widget>[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        pace,
                        const Divider(height: 24),
                        restart,
                        const SizedBox(height: 12),
                        resources,
                      ],
                    ),
                  ],
          1 =>
            dense
                ? toggles
                : <Widget>[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ControlSectionIntro(
                          title: 'Make it feel right',
                          text: 'Your flight, tuned for comfort. Changes apply right away.',
                          art: FlightLessonArt(
                            kind: 'feel',
                            highContrast: game.highContrast,
                            haptics: game.haptics,
                          ),
                          wide: bounds.maxWidth > 420,
                          artHeight: (bounds.maxHeight - 486).clamp(
                            40.0,
                            120.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final item in toggles) ...[
                          item,
                          if (item != toggles.last) const Divider(height: 12),
                        ],
                      ],
                    ),
                  ],
          _ =>
            dense
                ? <Widget>[collection, privacy, licenses]
                : <Widget>[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        collection,
                        const Divider(height: 24),
                        privacy,
                      ],
                    ),
                  ],
        };
        final page = _page.clamp(0, pages.length - 1);
        void move(int delta) {
          final target = page + delta;
          setState(() {
            if (target >= 0 && target < pages.length) {
              _page = target;
            } else if (delta > 0 && _section < 2) {
              _section++;
              _page = 0;
            } else if (delta < 0 && _section > 0) {
              _section--;
              _page = dense ? (_section == 0 ? pacePages.length + 2 : 2) : 0;
            }
          });
        }

        return Column(
          children: [
            Row(
              children: [
                for (final (index, label) in [
                  'Flight',
                  'Feel',
                  'About',
                ].indexed)
                  Expanded(
                    child: OrbitMode(
                      key: ValueKey('settings-section-$index'),
                      label: label,
                      selected: _section == index,
                      onPressed: () => setState(() {
                        _section = index;
                        _page = 0;
                      }),
                      reduceMotion: reduced,
                    ),
                  ),
              ],
            ),
            Expanded(
              child: FlightPageSurface(
                key: const ValueKey('settings-carousel'),
                reduceMotion: reduced,
                onPrevious: page > 0 || _section > 0 ? () => move(-1) : null,
                onNext: page + 1 < pages.length || _section < 2
                    ? () => move(1)
                    : null,
                child: SceneTransition(
                  reduceMotion: reduced,
                  duration: const Duration(milliseconds: 240),
                  child: Align(
                    key: ValueKey('$_section-$page'),
                    alignment: roomy ? Alignment.topCenter : Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(top: roomy ? 16 : 0),
                      child: pages[page],
                    ),
                  ),
                ),
              ),
            ),
            if (pages.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _pager(
                    'settings-previous',
                    'Previous',
                    Icons.chevron_left_rounded,
                    page > 0 ? () => setState(() => _page = page - 1) : null,
                    reduced,
                  ),
                  Semantics(
                    label: 'Page ${page + 1} of ${pages.length}',
                    child: Text(
                      '${page + 1} / ${pages.length}',
                      key: const ValueKey('settings-page'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Palette.secondary,
                      ),
                    ),
                  ),
                  _pager(
                    'settings-next',
                    'Next',
                    Icons.chevron_right_rounded,
                    page + 1 < pages.length
                        ? () => setState(() => _page = page + 1)
                        : null,
                    reduced,
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
  Widget _pager(
    String keyName,
    String label,
    IconData icon,
    VoidCallback? action,
    bool reduced,
  ) => Semantics(
    button: true,
    enabled: action != null,
    label: label,
    onTap: action,
    child: ExcludeSemantics(
      child: ExcludeFocus(
        excluding: action == null,
        child: IgnorePointer(
          ignoring: action == null,
          child: Opacity(
            opacity: action == null ? .3 : 1,
            child: OrbitUtility(
              key: ValueKey(keyName),
              label: label,
              icon: icon,
              onPressed: action ?? () {},
              reduceMotion: reduced,
              width: 56,
            ),
          ),
        ),
      ),
    ),
  );
}

/// An actual flight-path preview, with copy alongside it on larger displays.
/// Narrow screens use a short illustration above the text, never a tiny label.
class _ControlSectionIntro extends StatelessWidget {
  const _ControlSectionIntro({
    required this.title,
    required this.text,
    required this.art,
    required this.wide,
    required this.artHeight,
  });
  final String title, text;
  final Widget art;
  final bool wide;
  final double artHeight;
  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: bookTitle(24)),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            color: Palette.secondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
    if (wide) {
      return Row(
        children: [
          Expanded(flex: 3, child: copy),
          const SizedBox(width: 20),
          Expanded(flex: 2, child: SizedBox(height: 110, child: art)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: artHeight, child: art),
        const SizedBox(height: 12),
        copy,
      ],
    );
  }
}
