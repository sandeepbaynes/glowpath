import 'package:material_ui/material_ui.dart';

import '../game/puzzle.dart';
import 'design.dart';
import 'space_controls.dart';
import 'observatory_art.dart';
import 'puzzle_board.dart';

/// Short instructions shown over a paused board, once per new rule.
/// Reading never spends mission time; the host owns pausing and persistence.
class MissionBriefingBeat {
  const MissionBriefingBeat({
    required this.text,
    required this.compactText,
    this.icon = Icons.route_rounded,
    this.routeKind,
  });
  final String text, compactText;
  final IconData icon;
  final TileKind? routeKind;
}

const firstFlightBriefing = <MissionBriefingBeat>[
  MissionBriefingBeat(
    text: 'Drag from cyan START across adjacent tiles. Their paths turn to follow your route.',
    compactText: 'Drag from START.',
    icon: Icons.route_rounded,
  ),
  MissionBriefingBeat(
    text: 'Collect all three stars, then reach gold FINISH. You can also tap a tile to turn it.',
    compactText: '3 stars, then FINISH.',
    icon: Icons.star_rounded,
  ),
  MissionBriefingBeat(
    text: 'Blocked turns pulse. Retrace to change direction, then lift your finger to set the route.',
    compactText: 'Lift to set. Or tap.',
    icon: Icons.flag_rounded,
  ),
];

class MissionBriefing extends StatelessWidget {
  const MissionBriefing({
    super.key,
    required this.onStart,
    this.destination = 'First flight',
    this.planet = 1,
    this.beats = firstFlightBriefing,
    this.actionLabel = "Let's fly",
    this.reduceMotion = false,
  });
  final VoidCallback onStart;
  final String destination, actionLabel;
  final int planet;
  final List<MissionBriefingBeat> beats;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final dense = scale > 1.5 || constraints.maxHeight < 500;
      final sideBySide =
          scale > 1.5 &&
          constraints.maxWidth >= 460 &&
          constraints.maxHeight < 420;
      final illustrated = scale <= 1.2 && constraints.maxHeight >= 500;
      final header = Semantics(
        header: true,
        label: 'Mission briefing. $destination. Planet $planet.',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!dense) ...[
                Row(
                  children: [
                    Container(width: 18, height: 1, color: Palette.rust),
                    const SizedBox(width: 8),
                    Text(
                      'FLIGHT NOTES / ${planet.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.7,
                        color: Palette.rust,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Text(
                dense ? 'Flight notes' : destination,
                maxLines: 2,
                style: bookTitle(dense ? 16 : 30),
              ),
            ],
          ),
        ),
      );
      final start = SpaceAction(
        key: const ValueKey('briefing-start'),
        label: actionLabel,
        onPressed: onStart,
        reduceMotion: reduceMotion,
        compact: dense,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sideBySide)
            Row(
              children: [
                Expanded(child: header),
                const SizedBox(width: 16),
                Expanded(child: start),
              ],
            )
          else
            header,
          if (illustrated) ...[
            SizedBox(
              height: 100,
              child: beats.first.routeKind != null
                  ? Center(
                      child: RouteMechanicGlyph(
                        kind: beats.first.routeKind!,
                        color: Palette.rust,
                        size: 64,
                      ),
                    )
                  : MissionIllustration(
                      kind: illustrationFor(beats.first.icon),
                    ),
            ),
            const SizedBox(height: 6),
          ] else
            SizedBox(height: dense ? 12 : 22),
          for (var index = 0; index < beats.length; index++) ...[
            _FlightNote(beat: beats[index], dense: dense, number: index + 1),
            if (index + 1 < beats.length) SizedBox(height: dense ? 8 : 14),
          ],
          if (!sideBySide) ...[SizedBox(height: dense ? 14 : 24), start],
        ],
      );
    },
  );
}

class _FlightNote extends StatelessWidget {
  const _FlightNote({
    required this.beat,
    required this.dense,
    required this.number,
  });
  final MissionBriefingBeat beat;
  final bool dense;
  final int number;
  @override
  Widget build(BuildContext context) => Semantics(
    label: beat.text,
    child: ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: dense ? 4 : 2),
            child: Text(
              number.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: dense ? 10 : 11,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: Palette.rust.withValues(alpha: .75),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dense ? beat.compactText : beat.text,
                  style: TextStyle(
                    fontSize: dense ? 13 : 14,
                    height: dense ? 1.3 : 1.45,
                    color: Palette.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A concise rule card for every system present on a board. Titles and symbols
/// match the marks on the tiles; these are also used by the replayable guide.
class MissionRule {
  const MissionRule(
    this.title,
    this.text,
    this.compactText,
    this.icon, {
    this.routeKind,
  });
  final String title, text, compactText;
  final IconData icon;
  final TileKind? routeKind;
}

List<MissionRule> missionRulesFor(Puzzle puzzle) {
  final tiles = puzzle.tiles;
  bool has(TileKind kind) => tiles.any((tile) => tile.kind == kind);
  return [
    if (puzzle.isBountyRoute)
      const MissionRule(
        'Optional cargo',
        'Three stars still open the dock. Take a detour to collect cargo, or fly direct. Finds go into your collection; power items can help on a later route.',
        'Cargo is optional. Detour to collect.',
        Icons.route_rounded,
      ),
    if (tiles.any((tile) => tile.isLocked))
      const MissionRule(
        'Fixed relays',
        'Its channel stays fixed. Rotate neighboring tiles to connect through it.',
        'Locks cannot turn.',
        Icons.lock_rounded,
      ),
    if (tiles.any((tile) => tile.isOneWay))
      const MissionRule(
        'One-way channels',
        'Enter at the tail of the arrow. The arrow points in the only allowed direction.',
        'Follow the arrows.',
        Icons.arrow_forward_rounded,
      ),
    if (tiles.any((tile) => tile.couplingGroup > 0))
      MissionRule(
        tiles.any(
              (tile) =>
                  tile.couplingGroup > 0 &&
                  tiles
                          .where(
                            (other) =>
                                other.couplingGroup == tile.couplingGroup,
                          )
                          .length ==
                      3,
            )
            ? 'Linked twins & triplets'
            : 'Linked twins',
        'Tiles with the same purple group mark turn together. Plan both ends before turning.',
        'Linked tiles turn.',
        Icons.link_rounded,
      ),
    if (has(TileKind.bridge))
      const MissionRule(
        'Overpass bridges',
        'The straight channels cross at different heights. The rocket stays in its own lane.',
        'Crossings stay separate.',
        Icons.route_rounded,
        routeKind: TileKind.bridge,
      ),
    if (has(TileKind.crossway))
      const MissionRule(
        'Crossways',
        'Each tile has two separate bends. Each bend joins adjacent sides; the paths never merge.',
        'Two separate bends.',
        Icons.route_rounded,
        routeKind: TileKind.crossway,
      ),
    if (has(TileKind.wormhole))
      const MissionRule(
        'Paired wormholes',
        'Matching W marks link distant tiles. Draw into one, lift, then continue drawing from its partner along the arrow.',
        'W marks teleport.',
        Icons.all_inclusive_rounded,
      ),
    if (has(TileKind.blackHole))
      const MissionRule(
        'Black-hole pull',
        'At the pull fork, the rocket tries right, then straight, then left.',
        'Pull forks prefer right.',
        Icons.blur_circular_rounded,
      ),
    if (has(TileKind.whiteHole))
      const MissionRule(
        'White-hole push',
        'At the push fork, the rocket tries left, then straight, then right.',
        'Push forks prefer left.',
        Icons.flare_rounded,
      ),
    if (has(TileKind.fork))
      const MissionRule(
        'Gravity forks',
        'The matching G source steers the branch: toward a black hole, away from a white hole.',
        'Follow the G source.',
        Icons.route_rounded,
        routeKind: TileKind.fork,
      ),
    if (has(TileKind.weapon) || has(TileKind.disarm))
      const MissionRule(
        'Defense circuits',
        'Cross the numbered switch before its matching weapon. Crossing that switch twice re-arms the weapon.',
        'Switch first. Weapon second.',
        Icons.shield_rounded,
      ),
    if (has(TileKind.shield))
      const MissionRule(
        'Shield charges',
        'Cross a shield charger before an armed weapon. The shield absorbs one hit, then it is spent. Charge again before the next armed weapon.',
        'One shield. One hit.',
        Icons.shield_outlined,
      ),
    if (tiles.any(
      (tile) =>
          tile.gravityPeer != null &&
          (tile.kind == TileKind.bridge || tile.kind == TileKind.crossway),
    ))
      const MissionRule(
        'Gravity-linked lanes',
        'Matching G marks link a well and a crossing. Turning a black hole turns its linked lane and arrow clockwise; a white hole turns them counterclockwise.',
        'Turning G turns linked lanes.',
        Icons.sync_rounded,
      ),
  ];
}

List<MissionBriefingBeat> mechanicBriefingFor(Puzzle puzzle) {
  final rules = missionRulesFor(puzzle);
  if (rules.isEmpty) return firstFlightBriefing;
  final rule = rules.last;
  return [
    MissionBriefingBeat(
      text: '${rule.title}. ${rule.text}',
      compactText: rule.compactText,
      icon: rule.icon,
      routeKind: rule.routeKind,
    ),
    const MissionBriefingBeat(
      text: 'Plan the whole route before turning linked tiles.',
      compactText: 'Plan the route.',
      icon: Icons.route_rounded,
    ),
    const MissionBriefingBeat(
      text: 'Collect all three stars, then reach FINISH. Hints highlight the next tile to turn.',
      compactText: 'Stars, then FINISH.',
      icon: Icons.flag_rounded,
    ),
  ];
}

class MissionMechanicGuide extends StatelessWidget {
  const MissionMechanicGuide({super.key, required this.puzzle});
  final Puzzle puzzle;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final rule in missionRulesFor(puzzle))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: rule.routeKind != null
                    ? RouteMechanicGlyph(
                        kind: rule.routeKind!,
                        color: Palette.rust,
                      )
                    : Icon(rule.icon, size: 22, color: Palette.rust),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Palette.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rule.text,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Palette.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
