import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/voyage_records.dart';
import 'design.dart';
import 'space_controls.dart';
import 'space_scenery.dart';
import 'voyage_archive.dart';

/// The flight log contains records only. The Voyage landing owns the universe.
class VoyageRouteLog extends StatefulWidget {
  const VoyageRouteLog({
    super.key,
    required this.frontierLevel,
    required this.currentLevel,
    required this.records,
    required this.onReplay,
    this.reduceMotion = false,
  });

  final int frontierLevel, currentLevel;
  final Map<int, RouteRecord> records;
  final ValueChanged<int> onReplay;
  final bool reduceMotion;

  @override
  State<VoyageRouteLog> createState() => _VoyageRouteLogState();
}

class _VoyageRouteLogState extends State<VoyageRouteLog> {
  int? _selected;
  int get _frontier => math.max(0, (widget.frontierLevel - 1) ~/ 15);
  int get _planet =>
      (_selected ?? (widget.currentLevel - 1) ~/ 15).clamp(0, _frontier);

  void _browse(int planet) => setState(() {
    _selected = planet.clamp(0, _frontier);
  });

  @override
  Widget build(BuildContext context) {
    final world = VoyageWorld.forLevel(_planet * 15 + 1);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: large ? 72 : 58,
          child: Row(
            children: [
              OrbitUtility(
                key: const ValueKey('voyage-first-planet'),
                label: 'First planet',
                icon: Icons.first_page_rounded,
                width: 48,
                reduceMotion: widget.reduceMotion,
                onPressed: () => _browse(0),
              ),
              OrbitUtility(
                key: const ValueKey('voyage-previous-planet'),
                label: 'Previous planet',
                icon: Icons.chevron_left_rounded,
                width: 48,
                reduceMotion: widget.reduceMotion,
                onPressed: () => _browse(_planet - 1),
              ),
              Expanded(
                child: Semantics(
                  key: const ValueKey('route-log-destination'),
                  header: true,
                  excludeSemantics: true,
                  label:
                      '${world.name}. Planet ${_planet + 1}. Flight records.',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        world.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: large ? 11 : 18,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: world.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        large ? 'P${_planet + 1}' : 'Planet ${_planet + 1}',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: large ? 8 : 11,
                          height: 1.1,
                          color: Palette.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              OrbitUtility(
                key: const ValueKey('voyage-next-planet'),
                label: 'Next planet',
                icon: Icons.chevron_right_rounded,
                width: 48,
                reduceMotion: widget.reduceMotion,
                onPressed: () => _browse(_planet + 1),
              ),
              OrbitUtility(
                key: const ValueKey('voyage-current-planet'),
                label: 'Current destination',
                icon: Icons.my_location_rounded,
                width: 48,
                reduceMotion: widget.reduceMotion,
                onPressed: () => _browse(_frontier),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: VoyageArchive(
            key: ValueKey('route-log-planet-$_planet'),
            planetIndex: _planet,
            frontierLevel: widget.frontierLevel,
            records: widget.records,
            onReplay: widget.onReplay,
            reduceMotion: widget.reduceMotion,
          ),
        ),
      ],
    );
  }
}
