import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../game/voyage_records.dart';
import 'design.dart';
import 'space_controls.dart';
import 'space_scenery.dart';
import 'voyage_archive.dart';

/// The chart is a place in the universe, not a panel over the game.
/// Only its controls respect the safe area; the flight scene fills the device.
class VoyageAtlas extends StatefulWidget {
  const VoyageAtlas({
    super.key,
    required this.completedRoutes,
    required this.onClose,
    required this.onContinue,
    required this.onReplay,
    this.frontierLevel,
    this.currentLevel,
    this.records = const {},
    this.isReplaying = false,
    this.reduceMotion = false,
    this.ambientMotion = false,
  });

  final int completedRoutes;
  final int? frontierLevel, currentLevel;
  final Map<int, RouteRecord> records;
  final bool isReplaying, reduceMotion, ambientMotion;
  final VoidCallback onClose, onContinue;
  final ValueChanged<int> onReplay;

  @override
  State<VoyageAtlas> createState() => _VoyageAtlasState();
}

class _VoyageAtlasState extends State<VoyageAtlas> {
  int? _selectedPlanet;
  bool _routes = false;
  int get _frontier =>
      math.max(1, widget.frontierLevel ?? widget.completedRoutes + 1);
  int get _frontierPlanet => (_frontier - 1) ~/ VoyageWorld.routesPerPlanet;
  int get _planet =>
      (_selectedPlanet ?? ((widget.currentLevel ?? _frontier) - 1) ~/ 15).clamp(
        0,
        _frontierPlanet + 3,
      );

  void _browse(int planet) => setState(() {
    _selectedPlanet = planet.clamp(0, _frontierPlanet + 3);
  });

  @override
  Widget build(BuildContext context) {
    final world = VoyageWorld.forLevel(_planet * 15 + 1);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.6;
    final still =
        widget.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final reached = _planet <= _frontierPlanet;
    final route = _planet == _frontierPlanet ? (_frontier - 1) % 15 + 1 : 15;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Palette.paper,
          body: LayoutBuilder(
            builder: (context, viewport) {
              final landscape = viewport.maxWidth > viewport.maxHeight;
              final compact = viewport.maxHeight < 500;
              final inset = viewport.maxWidth >= 900 ? 36.0 : 16.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Keep one full-size scene in the tree across the Routes toggle;
                  // its position and gentle ambient motion never jump into a box.
                  Positioned.fill(
                    child: ExcludeSemantics(
                      excluding: _routes,
                      child: IgnorePointer(
                        ignoring: _routes,
                        child: VoyageExplorer(
                          key: ValueKey('atlas-planet-$_planet'),
                          sceneKey: const ValueKey('voyage-atlas-scene'),
                          current: world,
                          routesAtDestination: !reached
                              ? 0
                              : _planet == _frontierPlanet
                              ? route - 1
                              : 15,
                          showCourier: _planet == _frontierPlanet,
                          reduceMotion: still,
                          ambientMotion: widget.ambientMotion,
                          verticalFocus: landscape ? .22 : .36,
                          animateArrival: false,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 280),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: _routes
                                ? const [
                                    Color(0xFA060B14),
                                    Color(0xEF060B14),
                                    Color(0xFA060B14),
                                  ]
                                : const [
                                    Color(0xC9060B14),
                                    Color(0x00060B14),
                                    Color(0x00060B14),
                                    Color(0xB3060B14),
                                  ],
                            stops: _routes
                                ? const [0, .5, 1]
                                : const [0, .24, .76, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    minimum: EdgeInsets.fromLTRB(inset, 8, inset, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(
                          world,
                          compact: compact,
                          large: large,
                          still: still,
                        ),
                        _navigation(
                          world,
                          compact: compact,
                          large: large,
                          still: still,
                        ),
                        if (!compact)
                          Text(
                            !reached
                                ? 'Upcoming destination'
                                : _planet == _frontierPlanet
                                ? 'Route $route of 15'
                                : '15 routes available to replay',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: large ? 9 : 13,
                              color: Palette.secondary,
                            ),
                          ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: still
                                ? Duration.zero
                                : const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _routes
                                ? Padding(
                                    key: const ValueKey('atlas-route-log'),
                                    padding: EdgeInsets.only(
                                      top: compact ? 4 : 16,
                                      bottom: 4,
                                    ),
                                    child: Align(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 840,
                                        ),
                                        child: VoyageArchive(
                                          key: ValueKey(
                                            'archive-planet-$_planet',
                                          ),
                                          planetIndex: _planet,
                                          frontierLevel: _frontier,
                                          records: widget.records,
                                          onReplay: widget.onReplay,
                                          reduceMotion: still,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.expand(
                                    key: ValueKey('atlas-open-space'),
                                  ),
                          ),
                        ),
                        _footer(compact: compact, large: large, still: still),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(
    VoyageWorld world, {
    required bool compact,
    required bool large,
    required bool still,
  }) => SizedBox(
    height: large && !compact ? 62 : 48,
    child: Row(
      children: [
        OrbitUtility(
          key: const ValueKey('voyage-atlas-back'),
          label: 'Close voyage map',
          icon: Icons.arrow_back_rounded,
          width: 48,
          reduceMotion: still,
          onPressed: widget.onClose,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            compact ? 'VOYAGE' : world.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? (large ? 10 : 13) : (large ? 15 : 28),
              height: 1.1,
              letterSpacing: compact ? 2 : -.4,
              fontWeight: FontWeight.w600,
              color: compact ? Palette.secondary : world.accent,
            ),
          ),
        ),
        if (!compact)
          Text(
            'VOYAGE',
            style: TextStyle(
              fontSize: large ? 6 : 10,
              letterSpacing: 1.5,
              color: Palette.secondary,
            ),
          ),
      ],
    ),
  );

  Widget _navigation(
    VoyageWorld world, {
    required bool compact,
    required bool large,
    required bool still,
  }) => SizedBox(
    height: compact && large ? 64 : 52,
    child: Row(
      children: [
        OrbitUtility(
          key: const ValueKey('voyage-first-planet'),
          label: 'First planet',
          icon: Icons.first_page_rounded,
          width: 48,
          reduceMotion: still,
          onPressed: () => _browse(0),
        ),
        OrbitUtility(
          key: const ValueKey('voyage-previous-planet'),
          label: 'Previous planet',
          icon: Icons.chevron_left_rounded,
          width: 48,
          reduceMotion: still,
          onPressed: () => _browse(_planet - 1),
        ),
        Expanded(
          child: Semantics(
            label:
                '${world.name}. Viewing planet ${_planet + 1}. ${_planet > _frontierPlanet ? 'Upcoming destination.' : 'Routes available to replay.'}',
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (compact)
                    Text(
                      world.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: large ? 9 : 20,
                        height: 1.1,
                        color: world.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    large ? 'P${_planet + 1}' : 'Planet ${_planet + 1}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: large ? 8 : 13,
                      height: 1.2,
                      color: Palette.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        OrbitUtility(
          key: const ValueKey('voyage-next-planet'),
          label: 'Next planet',
          icon: Icons.chevron_right_rounded,
          width: 48,
          reduceMotion: still,
          onPressed: () => _browse(_planet + 1),
        ),
        OrbitUtility(
          key: const ValueKey('voyage-current-planet'),
          label: 'Current destination',
          icon: Icons.my_location_rounded,
          width: 48,
          reduceMotion: still,
          onPressed: () => _browse(_frontierPlanet),
        ),
      ],
    ),
  );

  Widget _footer({
    required bool compact,
    required bool large,
    required bool still,
  }) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: SizedBox(
        height: compact || large ? 56 : 60,
        child: Row(
          children: [
            SizedBox(
              width: large ? 100 : 90,
              child: OrbitMode(
                key: const ValueKey('voyage-route-log'),
                label: _routes ? 'Map' : 'Routes',
                selected: _routes,
                onPressed: () => setState(() => _routes = !_routes),
                reduceMotion: still,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                key: const ValueKey('voyage-atlas-continue'),
                container: true,
                label: widget.isReplaying
                    ? 'Resume current route'
                    : 'Continue voyage',
                button: true,
                enabled: true,
                onTap: widget.onContinue,
                excludeSemantics: true,
                child: OrbitMode(
                  label: widget.isReplaying
                      ? (compact || large ? 'Resume' : 'Resume current route')
                      : 'Continue',
                  selected: false,
                  onPressed: widget.onContinue,
                  reduceMotion: still,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
