import 'package:material_ui/material_ui.dart';

import '../game/puzzle.dart';
import 'design.dart';
import 'mission_briefing.dart';
import 'space_controls.dart';
import 'flight_page_surface.dart';
import 'puzzle_board.dart';

/// Full instructions are paginated at the player's chosen type size. Neither
/// scrolling nor reduced text scaling is needed on a small mission display.
class FlightManual extends StatefulWidget {
  const FlightManual({
    super.key,
    required this.puzzle,
    required this.onClose,
    this.reduceMotion = false,
  });
  final Puzzle puzzle;
  final VoidCallback onClose;
  final bool reduceMotion;
  @override
  State<FlightManual> createState() => _FlightManualState();
}

class _FlightManualState extends State<FlightManual> {
  int _page = 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final still =
          widget.reduceMotion ||
          MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.reduceMotionOf(context);
      final bodyStyle = DefaultTextStyle.of(context).style.merge(
        TextStyle(
          fontSize: 16,
          height: 1.35,
          color: Palette.white,
          fontWeight: MediaQuery.boldTextOf(context)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      );
      final showTitle = scaler.scale(1) <= 1.5 && constraints.maxHeight > 270;
      const footerHeight = 64.0;
      final cardPadding = constraints.maxHeight < 300
          ? 8.0
          : scaler.scale(1) > 1.5
          ? 14.0
          : 18.0;
      final bodyHeight = constraints.maxHeight - footerHeight - 8;
      final illustrationHeight = showTitle && bodyHeight > 340
          ? (bodyHeight * .38).clamp(110.0, 240.0)
          : 0.0;
      final titleStyle = bookTitle(25);
      double titleHeight(String title) {
        if (!showTitle) return 0;
        final painter = TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textScaler: scaler,
          textDirection: direction,
        )..layout(maxWidth: constraints.maxWidth - cardPadding * 2);
        final height = painter.height + 14;
        painter.dispose();
        return height;
      }

      final entries = <({String title, MissionBriefingBeat beat})>[
        for (final (i, beat) in firstFlightBriefing.indexed)
          (
            title: [
              'Draw your route',
              'Three stars. One finish',
              'Make your next move',
            ][i],
            beat: beat,
          ),
        for (final rule in missionRulesFor(widget.puzzle))
          (
            title: rule.title,
            beat: MissionBriefingBeat(
              text: showTitle ? rule.text : '${rule.title}. ${rule.text}',
              compactText: rule.compactText,
              icon: rule.icon,
              routeKind: rule.routeKind,
            ),
          ),
        (
          title: 'Launch window',
          beat: const MissionBriefingBeat(
            text: 'Each planet has 15 routes. The three legs give you 30, 27, then 24 seconds.',
            compactText: '15 routes. 30 → 27 → 24s.',
            icon: Icons.timer_rounded,
          ),
        ),
        (
          title: 'Time to think',
          beat: const MissionBriefingBeat(
            text: 'Help and leaving the app pause the clock. Voyage retries keep your turns; challenge retries reset that signal.',
            compactText: 'Help pauses the clock.',
            icon: Icons.refresh_rounded,
          ),
        ),
        (
          title: 'Stars & flight support',
          beat: const MissionBriefingBeat(
            text: 'A clear earns three stars toward new rocket trails. A hint highlights a relay; tap the hint action again to turn it.',
            compactText: 'Clears earn 3 stars.',
            icon: Icons.star_rounded,
          ),
        ),
        (
          title: 'Skips & the league',
          beat: const MissionBriefingBeat(
            text: 'Skipping advances the Voyage but earns no stars. Only unassisted challenge clears qualify for the league.',
            compactText: 'Skips earn no stars.',
            icon: Icons.emoji_events_rounded,
          ),
        ),
      ];
      final pages = <({String title, MissionBriefingBeat beat, String text})>[
        for (final entry in entries)
          for (final chunk in _chunks(
            entry.beat.text,
            width: constraints.maxWidth - cardPadding * 2,
            height:
                bodyHeight -
                cardPadding * 2 -
                illustrationHeight -
                titleHeight(entry.title),
            style: bodyStyle,
            scaler: scaler,
            direction: direction,
          ))
            (title: entry.title, beat: entry.beat, text: chunk),
      ];
      final index = _page.clamp(0, pages.length - 1);
      final page = pages[index];
      const accent = Palette.rust;
      void previous() => setState(() => _page = index - 1);
      void next() => setState(() => _page = index + 1);
      final artKind = page.beat.routeKind != null
          ? 'mechanic'
          : switch (page.title) {
              'Three stars. One finish' => 'stars',
              'Make your next move' => 'adjust',
              'Launch window' => 'timer',
              'Time to think' => 'pause',
              'Fixed relays' => 'lock',
              'One-way channels' => 'direction',
              'Linked twins' ||
              'Linked twins & triplets' ||
              'Gravity-linked lanes' => 'linked',
              'Paired wormholes' => 'portal',
              'Black-hole pull' => 'pull',
              'White-hole push' => 'push',
              'Defense circuits' => 'defense',
              'Shield charges' => 'shield',
              'Optional cargo' => 'rewards',
              'Stars & flight support' || 'Skips & the league' => 'rewards',
              _ => 'route',
            };
      return Column(
        children: [
          Expanded(
            child: FlightPageSurface(
              key: const ValueKey('manual-carousel'),
              reduceMotion: still,
              onPrevious: index > 0 ? previous : null,
              onNext: index + 1 < pages.length ? next : null,
              child: AnimatedSwitcher(
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final old in previous)
                      Positioned.fill(child: ExcludeSemantics(child: old)),
                    if (current != null) Positioned.fill(child: current),
                  ],
                ),
                child: Semantics(
                  key: ValueKey('manual-page-$index'),
                  liveRegion: true,
                  label: '${page.title}. ${page.text}',
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 2),
                          if (illustrationHeight > 0)
                            SizedBox(
                              height: illustrationHeight,
                              child: FlightLessonArt(
                                kind: artKind,
                                centerGlyph: page.beat.routeKind == null
                                    ? null
                                    : RouteMechanicGlyph(
                                        kind: page.beat.routeKind!,
                                        color: accent,
                                        size: 64,
                                      ),
                              ),
                            ),
                          if (showTitle) ...[
                            Text(page.title, style: titleStyle),
                            const SizedBox(height: 14),
                          ],
                          Text(
                            page.text,
                            key: const ValueKey('manual-body-copy'),
                            style: bodyStyle,
                          ),
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: footerHeight,
            child: Row(
              children: [
                _ManualControl(
                  controlKey: const ValueKey('manual-previous'),
                  label: 'Previous rule',
                  icon: Icons.chevron_left_rounded,
                  onPressed: index > 0
                      ? () => setState(() => _page = index - 1)
                      : null,
                  reduceMotion: still,
                ),
                Expanded(
                  child: Semantics(
                    label: 'Page ${index + 1} of ${pages.length}',
                    child: ExcludeSemantics(
                      child: Text(
                        '${index + 1}/${pages.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
                _ManualControl(
                  controlKey: const ValueKey('manual-close'),
                  label: 'Back to flight',
                  icon: Icons.rocket_launch_rounded,
                  onPressed: widget.onClose,
                  reduceMotion: still,
                ),
                _ManualControl(
                  controlKey: const ValueKey('manual-next'),
                  label: 'Next rule',
                  icon: Icons.chevron_right_rounded,
                  onPressed: index + 1 < pages.length
                      ? () => setState(() => _page = index + 1)
                      : null,
                  reduceMotion: still,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _ManualControl extends StatelessWidget {
  const _ManualControl({
    required this.controlKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.reduceMotion,
  });
  final Key controlKey;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => Semantics(
    key: controlKey,
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
            opacity: onPressed == null ? .35 : 1,
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

List<String> _chunks(
  String text, {
  required double width,
  required double height,
  required TextStyle style,
  required TextScaler scaler,
  required TextDirection direction,
}) {
  bool fits(String candidate) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textScaler: scaler,
      textDirection: direction,
    )..layout(maxWidth: width);
    final fits = painter.height <= height;
    painter.dispose();
    return fits;
  }

  final chunks = <String>[];
  var current = '';
  for (final word in text.split(' ')) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (current.isEmpty || fits(candidate)) {
      current = candidate;
    } else {
      chunks.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}
