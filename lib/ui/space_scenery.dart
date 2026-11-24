import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'space_controls.dart';
import 'orbital_craft.dart';
import '../game/voyage_records.dart';
import 'voyage_archive.dart';

const _spaceInk = Color(0xFF060B14);
const _spaceText = Color(0xFFF4F2EC);
const _spaceMuted = Color(0xFFA9B8C6);
const _spaceGold = Color(0xFFEBC990);
const _spaceTeal = Color(0xFF9ADDDC);

/// The map, medallions and pilot approach share this exact illustrated renderer.
void drawOrbitalWorld(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required VoyageWorld world,
  double opacity = 1,
  double rotation = 0,
}) => _drawPlanet(
  canvas,
  center,
  radius,
  world,
  world.isBlackHole,
  opacity,
  rotation: rotation,
);

class OrbitalPlanetPainter extends CustomPainter {
  OrbitalPlanetPainter({
    required this.world,
    this.rotation = 0,
    this.opacity = 1,
    this.bodyScale = .32,
  });
  final VoyageWorld world;
  final double rotation, opacity, bodyScale;
  @override
  void paint(Canvas canvas, Size size) => drawOrbitalWorld(
    canvas,
    center: size.center(Offset.zero),
    radius: size.shortestSide * bodyScale,
    world: world,
    rotation: rotation,
    opacity: opacity,
  );
  @override
  bool shouldRepaint(OrbitalPlanetPainter old) =>
      world.planetIndex != old.world.planetIndex ||
      rotation != old.rotation ||
      opacity != old.opacity ||
      bodyScale != old.bodyScale;
}

/// Illustrated celestial families share the same light and material language.
enum CelestialKind {
  moon,
  volcanic,
  ocean,
  ringed,
  blackHole,
  star,
  comet,
  asteroids,
  galaxy,
  ice;

  String get label => switch (this) {
    moon => 'Crater moon',
    volcanic => 'Volcanic world',
    ocean => 'Ocean world',
    ringed => 'Ringed planet',
    blackHole => 'Black hole',
    star => 'Star',
    comet => 'Comet',
    asteroids => 'Asteroid field',
    galaxy => 'Spiral galaxy',
    ice => 'Ice world',
  };
}

class _CelestialDesign {
  const _CelestialDesign(
    this.name,
    this.kind,
    this.highlight,
    this.body,
    this.shadow,
    this.accent, {
    required this.variant,
    required this.moons,
    required this.tilt,
  });
  final String name;
  final CelestialKind kind;
  final int highlight, body, shadow, accent, variant, moons;
  final double tilt;
}

/// Levels are one-based; destination and galaxy indices are zero-based.
/// The first fifty destinations are individually art-directed. Later sectors
/// extend those material/silhouette families deterministically without an end.
/// Catalog changes never alter puzzle seeds, completed routes or saved levels.
class VoyageWorld {
  const VoyageWorld._(
    this._design, {
    required this.name,
    required this.galaxyName,
    required this.index,
    required this.galaxyIndex,
    required this.planetIndex,
  });

  static const _galaxies = [
    'Aster Reach',
    'Meridian Drift',
    'Serein Expanse',
    'Orison Passage',
  ];
  static const _catalog = [
    _CelestialDesign(
      'Luma',
      CelestialKind.moon,
      0xFFD0F1E6,
      0xFF68ADAA,
      0xFF153546,
      0xFF9ADDDC,
      variant: 0,
      moons: 0,
      tilt: -0.36,
    ),
    _CelestialDesign(
      'Ember',
      CelestialKind.volcanic,
      0xFFD89468,
      0xFF723B35,
      0xFF251B2C,
      0xFFC7A38E,
      variant: 0,
      moons: 0,
      tilt: -0.36,
    ),
    _CelestialDesign(
      'Viridian',
      CelestialKind.ocean,
      0xFF89DCD4,
      0xFF186D86,
      0xFF09293E,
      0xFFABC3B5,
      variant: 0,
      moons: 1,
      tilt: -0.36,
    ),
    _CelestialDesign(
      'Halo',
      CelestialKind.ringed,
      0xFFFFE5AE,
      0xFFD6A168,
      0xFF574661,
      0xFFEBC990,
      variant: 0,
      moons: 0,
      tilt: -0.36,
    ),
    _CelestialDesign(
      'The Veil',
      CelestialKind.blackHole,
      0xFF68D2CC,
      0xFFAA86C8,
      0xFF251B40,
      0xFFB8BCCF,
      variant: 0,
      moons: 0,
      tilt: -0.28,
    ),
    _CelestialDesign(
      'Solara',
      CelestialKind.star,
      0xFFFFF2C1,
      0xFFE8B767,
      0xFFA45539,
      0xFFEDD29A,
      variant: 0,
      moons: 0,
      tilt: -0.12,
    ),
    _CelestialDesign(
      'Frostwake',
      CelestialKind.ice,
      0xFFE4F4F0,
      0xFF83B6C5,
      0xFF294562,
      0xFFBEDCE8,
      variant: 0,
      moons: 1,
      tilt: 0.19,
    ),
    _CelestialDesign(
      'Cinder Tail',
      CelestialKind.comet,
      0xFFFFE5B7,
      0xFFD49669,
      0xFF59434B,
      0xFFE7C193,
      variant: 0,
      moons: 0,
      tilt: -0.24,
    ),
    _CelestialDesign(
      'Shard Sea',
      CelestialKind.asteroids,
      0xFFCEDDE4,
      0xFF718FA1,
      0xFF2D4256,
      0xFFAFCCD5,
      variant: 0,
      moons: 0,
      tilt: -0.25,
    ),
    _CelestialDesign(
      'Eidolon Spiral',
      CelestialKind.galaxy,
      0xFFEAE0F4,
      0xFFAA91C5,
      0xFF504567,
      0xFFBCAAD8,
      variant: 0,
      moons: 0,
      tilt: -0.32,
    ),
    _CelestialDesign(
      'Selene',
      CelestialKind.moon,
      0xFFE5DDEE,
      0xFF9A8FB5,
      0xFF3D3654,
      0xFFCBBBDD,
      variant: 1,
      moons: 1,
      tilt: 0.13,
    ),
    _CelestialDesign(
      'Pyra',
      CelestialKind.volcanic,
      0xFFE7B4A7,
      0xFFA05566,
      0xFF43253D,
      0xFFD3A4B5,
      variant: 1,
      moons: 1,
      tilt: 0.24,
    ),
    _CelestialDesign(
      'Pelagos',
      CelestialKind.ocean,
      0xFFA2DCE7,
      0xFF2F7EAA,
      0xFF173756,
      0xFFA3CCD8,
      variant: 1,
      moons: 2,
      tilt: -0.1,
    ),
    _CelestialDesign(
      'Aureole',
      CelestialKind.ringed,
      0xFFF4D6CE,
      0xFFBE8E91,
      0xFF513E60,
      0xFFE4BABA,
      variant: 1,
      moons: 1,
      tilt: 0.28,
    ),
    _CelestialDesign(
      'Eventide',
      CelestialKind.blackHole,
      0xFFF4D2AA,
      0xFFBF826C,
      0xFF392833,
      0xFFE4B08C,
      variant: 1,
      moons: 0,
      tilt: 0.24,
    ),
    _CelestialDesign(
      'Blue Lantern',
      CelestialKind.star,
      0xFFEAF6F7,
      0xFF8ACBDC,
      0xFF436994,
      0xFFB6E1E9,
      variant: 1,
      moons: 0,
      tilt: 0.1,
    ),
    _CelestialDesign(
      'Glass Harbor',
      CelestialKind.ice,
      0xFFD1F3E5,
      0xFF75B8B2,
      0xFF2C5B68,
      0xFFA7DED3,
      variant: 1,
      moons: 2,
      tilt: -0.23,
    ),
    _CelestialDesign(
      'Silver Kite',
      CelestialKind.comet,
      0xFFEDF6F1,
      0xFFA7C7D9,
      0xFF546B94,
      0xFFD1E2EA,
      variant: 1,
      moons: 0,
      tilt: 0.18,
    ),
    _CelestialDesign(
      'Copper Drift',
      CelestialKind.asteroids,
      0xFFE4C4A7,
      0xFFA47D65,
      0xFF493D42,
      0xFFCDB097,
      variant: 1,
      moons: 0,
      tilt: 0.18,
    ),
    _CelestialDesign(
      'Rosewheel',
      CelestialKind.galaxy,
      0xFFF4DFE3,
      0xFFC990AD,
      0xFF6B4E71,
      0xFFDDB8CC,
      variant: 1,
      moons: 0,
      tilt: 0.21,
    ),
    _CelestialDesign(
      'Opal',
      CelestialKind.moon,
      0xFFF4E6CF,
      0xFFBDAC92,
      0xFF625B6B,
      0xFFE2D3B7,
      variant: 2,
      moons: 2,
      tilt: -0.23,
    ),
    _CelestialDesign(
      'Brimstone',
      CelestialKind.volcanic,
      0xFFF1C883,
      0xFFA4693D,
      0xFF432B34,
      0xFFDFB57F,
      variant: 2,
      moons: 0,
      tilt: -0.18,
    ),
    _CelestialDesign(
      'Verdant Reach',
      CelestialKind.ocean,
      0xFFC0E7C9,
      0xFF408B7D,
      0xFF193F4D,
      0xFFB5D2AE,
      variant: 2,
      moons: 1,
      tilt: 0.22,
    ),
    _CelestialDesign(
      'Saffron',
      CelestialKind.ringed,
      0xFFF9DE9E,
      0xFFB5864E,
      0xFF554554,
      0xFFDFBA7F,
      variant: 2,
      moons: 2,
      tilt: -0.52,
    ),
    _CelestialDesign(
      'Nacre Rift',
      CelestialKind.blackHole,
      0xFFEDC7D9,
      0xFFA38CBF,
      0xFF33233F,
      0xFFD6BAD9,
      variant: 2,
      moons: 0,
      tilt: -0.48,
    ),
    _CelestialDesign(
      'Twin Suns',
      CelestialKind.star,
      0xFFFFF0BD,
      0xFFDFB174,
      0xFFA97D94,
      0xFFE8CF9E,
      variant: 2,
      moons: 0,
      tilt: 0.28,
    ),
    _CelestialDesign(
      'Thawline',
      CelestialKind.ice,
      0xFFE9E2F3,
      0xFFABA7D0,
      0xFF4B537C,
      0xFFD1CCE9,
      variant: 2,
      moons: 1,
      tilt: 0.34,
    ),
    _CelestialDesign(
      'Jade Comet',
      CelestialKind.comet,
      0xFFDFF4D9,
      0xFF97CAB6,
      0xFF426C7A,
      0xFFBCE0C4,
      variant: 2,
      moons: 0,
      tilt: -0.38,
    ),
    _CelestialDesign(
      'Obsidian Crown',
      CelestialKind.asteroids,
      0xFFC5BECE,
      0xFF797087,
      0xFF393647,
      0xFFADA3BF,
      variant: 2,
      moons: 0,
      tilt: -0.39,
    ),
    _CelestialDesign(
      'Tidal Arms',
      CelestialKind.galaxy,
      0xFFD5EEE7,
      0xFF78B2B9,
      0xFF375C84,
      0xFFB7DEDE,
      variant: 2,
      moons: 0,
      tilt: -0.49,
    ),
    _CelestialDesign(
      'Morrow',
      CelestialKind.moon,
      0xFFE3C4A9,
      0xFFA07D72,
      0xFF4D3F53,
      0xFFCEAEA2,
      variant: 3,
      moons: 0,
      tilt: 0.18,
    ),
    _CelestialDesign(
      'Kiln',
      CelestialKind.volcanic,
      0xFFF0B198,
      0xFF97505C,
      0xFF3D2737,
      0xFFD39D93,
      variant: 3,
      moons: 2,
      tilt: 0.3,
    ),
    _CelestialDesign(
      'Thalassa',
      CelestialKind.ocean,
      0xFFC4DDE8,
      0xFF567DA3,
      0xFF243C5B,
      0xFFB9C7D9,
      variant: 3,
      moons: 2,
      tilt: -0.16,
    ),
    _CelestialDesign(
      'Blue Halo',
      CelestialKind.ringed,
      0xFFC7E6ED,
      0xFF82AFC4,
      0xFF465875,
      0xFFB4D5DF,
      variant: 3,
      moons: 1,
      tilt: 0.42,
    ),
    _CelestialDesign(
      'Vesper Eye',
      CelestialKind.blackHole,
      0xFFB2E2DA,
      0xFF699DA7,
      0xFF263E56,
      0xFFA6D2D4,
      variant: 3,
      moons: 0,
      tilt: 0.4,
    ),
    _CelestialDesign(
      'Red Giant',
      CelestialKind.star,
      0xFFFFE1B9,
      0xFFD58B73,
      0xFF8B4D57,
      0xFFE6B29B,
      variant: 3,
      moons: 0,
      tilt: -0.3,
    ),
    _CelestialDesign(
      'Prism',
      CelestialKind.ice,
      0xFFF2EDF5,
      0xFFB9B4D7,
      0xFF5A6189,
      0xFFD5D0E9,
      variant: 3,
      moons: 0,
      tilt: -0.31,
    ),
    _CelestialDesign(
      'Goldfinch',
      CelestialKind.comet,
      0xFFFFF0C4,
      0xFFDBBB77,
      0xFF8A7A63,
      0xFFEAD49D,
      variant: 3,
      moons: 0,
      tilt: 0.32,
    ),
    _CelestialDesign(
      'Fossil Belt',
      CelestialKind.asteroids,
      0xFFE5DBC6,
      0xFFA59C8B,
      0xFF504C50,
      0xFFCBC5B2,
      variant: 3,
      moons: 0,
      tilt: 0.31,
    ),
    _CelestialDesign(
      'Lantern Galaxy',
      CelestialKind.galaxy,
      0xFFF5E4B8,
      0xFFC9AB79,
      0xFF7A626F,
      0xFFE1CCA0,
      variant: 3,
      moons: 0,
      tilt: 0.12,
    ),
    _CelestialDesign(
      'Pearl',
      CelestialKind.moon,
      0xFFE4EBED,
      0xFFA4B9C5,
      0xFF4F667A,
      0xFFCCDEE2,
      variant: 4,
      moons: 1,
      tilt: -0.14,
    ),
    _CelestialDesign(
      'Ashen Crown',
      CelestialKind.volcanic,
      0xFFC6DDD4,
      0xFF577B76,
      0xFF253B44,
      0xFFA5C9C2,
      variant: 4,
      moons: 1,
      tilt: -0.39,
    ),
    _CelestialDesign(
      'Mangrove',
      CelestialKind.ocean,
      0xFFDEE7B8,
      0xFF749F7C,
      0xFF2D595A,
      0xFFC8D8AE,
      variant: 4,
      moons: 0,
      tilt: 0.33,
    ),
    _CelestialDesign(
      'Orchid Rings',
      CelestialKind.ringed,
      0xFFECD5E9,
      0xFFAA8BAF,
      0xFF534567,
      0xFFD6B9DC,
      variant: 4,
      moons: 2,
      tilt: -0.17,
    ),
    _CelestialDesign(
      'Solstice Gate',
      CelestialKind.blackHole,
      0xFFEEDCA8,
      0xFFB19B82,
      0xFF363746,
      0xFFDEC99E,
      variant: 4,
      moons: 0,
      tilt: -0.14,
    ),
    _CelestialDesign(
      'Northstar',
      CelestialKind.star,
      0xFFF1F6EC,
      0xFFB2D9D7,
      0xFF6C9EB4,
      0xFFD9E9DC,
      variant: 4,
      moons: 0,
      tilt: 0.0,
    ),
    _CelestialDesign(
      'Glacier Crown',
      CelestialKind.ice,
      0xFFD7EDF0,
      0xFF78A6C1,
      0xFF354B73,
      0xFFB3D6E5,
      variant: 4,
      moons: 2,
      tilt: 0.17,
    ),
    _CelestialDesign(
      'Violet Runner',
      CelestialKind.comet,
      0xFFECDDF3,
      0xFFB19CCB,
      0xFF685D93,
      0xFFD5C2E6,
      variant: 4,
      moons: 0,
      tilt: -0.15,
    ),
    _CelestialDesign(
      'Pilgrim Stones',
      CelestialKind.asteroids,
      0xFFD0DEDC,
      0xFF809D9E,
      0xFF3E535C,
      0xFFB9D0CE,
      variant: 4,
      moons: 0,
      tilt: -0.12,
    ),
    _CelestialDesign(
      'Orison Spiral',
      CelestialKind.galaxy,
      0xFFEEE3D2,
      0xFFB7A6CB,
      0xFF535574,
      0xFFD4C9E0,
      variant: 4,
      moons: 0,
      tilt: -0.25,
    ),
  ];

  static const authoredDestinationCount = 50;
  static const routesPerPlanet = 15;
  static const routesPerGalaxy = routesPerPlanet * 5;
  final String name, galaxyName;

  /// Position within a five-stop sector; never an artwork discriminator.
  final int index;
  final int galaxyIndex, planetIndex;
  final _CelestialDesign _design;
  CelestialKind get kind => _design.kind;
  bool get isBlackHole => kind == CelestialKind.blackHole;
  int get catalogIndex => planetIndex % authoredDestinationCount;
  int get generation => planetIndex ~/ authoredDestinationCount;
  int get surfaceVariant => _design.variant + generation % 7 * 5;
  int get moonCount => _design.moons;
  double get tilt => _design.tilt;
  Color get accent => _shade(_design.accent);
  Color get highlight => _shade(_design.highlight);
  Color get bodyColor => _shade(_design.body);
  Color get shadow => _shade(_design.shadow);
  Color _shade(int value) {
    final color = Color(value);
    if (generation == 0) return color;
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + generation * 17 % 360) % 360).toColor();
  }

  static VoyageWorld forLevel(int level) {
    final planet = (math.max(1, level) - 1) ~/ routesPerPlanet;
    final galaxy = planet ~/ 5;
    final design = _catalog[planet % _catalog.length];
    final generation = planet ~/ _catalog.length;
    final galaxyBase = _galaxies[galaxy % _galaxies.length];
    return VoyageWorld._(
      design,
      name: generation == 0
          ? design.name
          : '${design.name} · ${generation + 1}',
      galaxyName: galaxy == 0 ? galaxyBase : '$galaxyBase · ${galaxy + 1}',
      index: planet % 5,
      galaxyIndex: galaxy,
      planetIndex: planet,
    );
  }

  /// Fifteen routes per world; three five-route legs tighten the clock.
  int routeWithin(int level) => (math.max(1, level) - 1) % routesPerPlanet + 1;
}

/// Slow star glide and rotating planet surfaces behind the steady board.
/// It never reads sensors or pointer movement, and stops when not visible.
class SpaceBackdrop extends StatefulWidget {
  const SpaceBackdrop({
    super.key,
    required this.level,
    required this.reduceMotion,
    required this.child,
    this.ambientMotion = true,
  });

  final int level;
  final bool reduceMotion, ambientMotion;
  final Widget child;

  @override
  State<SpaceBackdrop> createState() => _SpaceBackdropState();
}

class _SpaceBackdropState extends State<SpaceBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 180),
  );
  bool _foreground = true;
  bool _still = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(SpaceBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    _still =
        !widget.ambientMotion ||
        widget.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final animate =
        !_still && _foreground && TickerMode.valuesOf(context).enabled;
    if (animate && !_drift.isAnimating) _drift.repeat();
    if (!animate && _drift.isAnimating) _drift.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _spaceInk,
    child: ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey('ambient-space'),
                    painter: _SpacePainter(
                      VoyageWorld.forLevel(widget.level),
                      _still ? null : _drift,
                    ),
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    ),
  );
}

class PlanetMedallion extends StatelessWidget {
  const PlanetMedallion({
    super.key,
    required this.world,
    this.size = 64,
    this.portal = false,
  });

  final VoyageWorld world;
  final double size;
  final bool portal;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PlanetPainter(world, portal || world.isBlackHole),
      ),
    ),
  );
}

/// A small virtual window into the absolute voyage, independent of galaxy
/// boundaries. Only nearby destinations are built; every anchor has a future.
class VoyageDestinationWindow {
  VoyageDestinationWindow(this.current);

  final VoyageWorld current;
  static const futureDestinations = 3;
  static const chartDestinations = 4;

  int get firstPlanet => math.max(0, current.planetIndex - 1);

  List<VoyageWorld> get chart => List.generate(
    chartDestinations,
    (offset) => _world(firstPlanet + offset),
    growable: false,
  );

  List<VoyageWorld> get scene => List.generate(
    futureDestinations + 1,
    (offset) => _world(current.planetIndex + offset),
    growable: false,
  );

  static VoyageWorld _world(int planet) =>
      VoyageWorld.forLevel(planet * VoyageWorld.routesPerPlanet + 1);
}

/// The map is tethered to the currently accessible destination. A long pull
/// explores farther, but each additional pixel buys less camera movement.
abstract final class VoyageElasticity {
  static const maxDepth = 7.6;
  static const resistanceFactor = .30;

  static double minimumDepth(int planetIndex) => -math.min(
    maxDepth,
    planetIndex * VoyageDepthPainter.destinationSpacing + .8,
  );

  static double _extent(double direction, int? planetIndex) =>
      direction < 0 && planetIndex != null
      ? -minimumDepth(planetIndex)
      : maxDepth;

  static double depthForDrag(double pixels, double height, {int? planetIndex}) {
    final resistance = math.max(1.0, height) * resistanceFactor;
    // The beginning of the voyage has no preceding planet, but still has a
    // little room to pull back. Approach that limit progressively instead of
    // clamping the full-range curve after its first few pixels of movement.
    return _extent(pixels, planetIndex) * pixels / (resistance + pixels.abs());
  }

  static double dragForDepth(double depth, double height, {int? planetIndex}) {
    final extent = _extent(depth, planetIndex);
    final bounded = depth.clamp(-extent + .000001, extent - .000001);
    return math.max(1.0, height) *
        resistanceFactor *
        bounded /
        (extent - bounded.abs());
  }

  static double depthVelocityForDrag(
    double pixels,
    double pixelVelocity,
    double height, {
    int? planetIndex,
  }) {
    final resistance = math.max(1.0, height) * resistanceFactor;
    return pixelVelocity *
        _extent(pixels, planetIndex) *
        resistance /
        math.pow(resistance + pixels.abs(), 2);
  }
}

/// Retargets the same running animation without restarting its ticker. Wheel
/// signals may arrive more often than frames; restarting a ticker for each
/// signal would keep its elapsed time at zero until scrolling stops.
class _VoyageScrollSimulation extends Simulation {
  _VoyageScrollSimulation(this.spring, double from, double to, double velocity)
    : _segment = SpringSimulation(spring, from, to, velocity);

  final SpringDescription spring;
  SpringSimulation _segment;
  double _segmentStart = 0;

  void retarget(double target, double elapsed) {
    final position = x(elapsed);
    final velocity = dx(elapsed);
    _segment = SpringSimulation(spring, position, target, velocity);
    _segmentStart = elapsed;
  }

  @override
  double x(double time) => _segment.x(math.max(0, time - _segmentStart));

  @override
  double dx(double time) => _segment.dx(math.max(0, time - _segmentStart));

  // The session ends via its idle timer. Keep a single clock alive even when
  // the follower briefly catches up between adjacent mouse-wheel notches.
  @override
  bool isDone(double time) => false;
}

/// Direct manipulation belongs to the system scene, not the surrounding
/// sheet. It changes only a camera offset: progress and destination stay put.
class VoyageExplorer extends StatefulWidget {
  const VoyageExplorer({
    super.key,
    required this.current,
    required this.routesAtDestination,
    this.reduceMotion = false,
    this.showCourier = false,
    this.ambientMotion = false,
    this.verticalFocus = .30,
    this.sceneKey,
    this.arrivalDuration = const Duration(milliseconds: 1600),
    this.arrivalCurve = Curves.easeOutCubic,
    this.animateArrival = true,
    this.trailColor = _spaceGold,
    this.paintBackground = true,
  });

  final VoyageWorld current;
  final int routesAtDestination;
  final bool reduceMotion, showCourier, ambientMotion;
  final double verticalFocus;
  final Key? sceneKey;
  final Duration arrivalDuration;
  final Curve arrivalCurve;
  final bool animateArrival;
  final Color trailColor;
  final bool paintBackground;

  @override
  State<VoyageExplorer> createState() => _VoyageExplorerState();
}

class _VoyageExplorerState extends State<VoyageExplorer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: widget.arrivalDuration,
  );
  late final AnimationController _excursion = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 180),
  );
  bool _foreground = true;
  bool _initialized = false, _still = true, _dragging = false;
  bool _scrolling = false;
  Timer? _scrollReturn;
  _VoyageScrollSimulation? _scrollSimulation;
  double _scrollDirection = 0;
  static const _wheelGain = .28;
  static const _scrollIdle = Duration(milliseconds: 25);
  static const _scrollFollowSpring = SpringDescription(
    mass: 1,
    stiffness: 324,
    damping: 36,
  );
  static const _scrollReturnSpring = SpringDescription(
    mass: 1,
    stiffness: 150,
    damping: 18,
  );
  bool _resumeArrival = false;
  double _rawDrag = 0, _height = 350;
  int _returnGeneration = 0;

  double get _depth => _excursion.value.clamp(
    VoyageElasticity.minimumDepth(widget.current.planetIndex),
    VoyageElasticity.maxDepth,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(VoyageExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _arrival.duration = widget.arrivalDuration;
    if (oldWidget.current.planetIndex != widget.current.planetIndex ||
        oldWidget.routesAtDestination != widget.routesAtDestination) {
      _cancelScroll();
      _returnGeneration++;
      _dragging = false;
      _resumeArrival = false;
      _excursion.stop();
      _excursion.value = 0;
      _arrival.value = 0;
      _initialized = false;
    }
    _syncMotion();
  }

  void _syncMotion() {
    _still =
        widget.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    if (_still) {
      _arrival.value = 1;
      if (_scrolling) {
        _excursion.stop();
        _scrollSimulation = null;
        _excursion.value = _depthForRawDrag;
      } else if (!_dragging) {
        _returnGeneration++;
        _excursion.stop();
        _excursion.value = 0;
      }
    } else if (!_initialized) {
      if (widget.animateArrival) {
        _arrival.forward();
      } else {
        _arrival.value = 1;
      }
    }
    _initialized = true;
    final drift =
        widget.ambientMotion &&
        !_still &&
        _foreground &&
        TickerMode.valuesOf(context).enabled;
    if (drift && !_ambient.isAnimating) _ambient.repeat();
    if (!drift && _ambient.isAnimating) _ambient.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _scrolling) _returnHome();
    _syncMotion();
  }

  void _startDrag(DragStartDetails _) {
    if (!_dragging) _hold();
  }

  void _hold() {
    _cancelScroll();
    _dragging = true;
    _takeHold();
  }

  void _takeHold() {
    _returnGeneration++;
    _excursion.stop();
    _rawDrag = VoyageElasticity.dragForDepth(
      _depth,
      _height,
      planetIndex: widget.current.planetIndex,
    );
    _resumeArrival = _resumeArrival || _arrival.isAnimating;
    _arrival.stop();
  }

  double get _depthForRawDrag => VoyageElasticity.depthForDrag(
    _rawDrag,
    _height,
    planetIndex: widget.current.planetIndex,
  );

  void _updateDrag(DragUpdateDetails details) {
    _rawDrag += details.delta.dy;
    _excursion.value = _depthForRawDrag;
  }

  void _cancelScroll() {
    _scrollReturn?.cancel();
    _scrollReturn = null;
    _scrolling = false;
    _scrollDirection = 0;
    _scrollSimulation = null;
  }

  void _pointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        !event.scrollDelta.dy.isFinite) {
      return;
    }
    // Claim the signal even during a held drag: it must neither interrupt
    // that gesture nor escape into a surrounding page's scroll behavior.
    GestureBinding.instance.pointerSignalResolver.register(event, _scroll);
  }

  void _scroll(PointerSignalEvent event) {
    if (_dragging || !_foreground || event is! PointerScrollEvent) return;
    final velocity = _excursion.velocity;
    final direction = event.scrollDelta.dy.sign;
    if (!_scrolling) {
      _takeHold();
      _scrolling = true;
    } else if (direction != _scrollDirection) {
      // A reversal should act on the camera being shown, not require the
      // player to unwind distance that the previous burst has not reached.
      _rawDrag = VoyageElasticity.dragForDepth(
        _depth,
        _height,
        planetIndex: widget.current.planetIndex,
      );
    }
    _scrollDirection = direction;
    _scrollReturn?.cancel();
    _rawDrag += event.scrollDelta.dy * _wheelGain;
    final target = _depthForRawDrag;
    if (_still) {
      _excursion.value = target;
    } else if (_scrollSimulation case final simulation?) {
      simulation.retarget(
        target,
        (_excursion.lastElapsedDuration?.inMicroseconds ?? 0) /
            Duration.microsecondsPerSecond,
      );
    } else {
      final simulation = _VoyageScrollSimulation(
        _scrollFollowSpring,
        _depth,
        target,
        velocity,
      );
      _scrollSimulation = simulation;
      _excursion.animateWith(simulation);
    }
    // A short pause means release. Keep the follower continuous while
    // input arrives, then promptly hand over to the elastic return.
    _scrollReturn = Timer(_scrollIdle, _returnHome);
  }

  void _returnHome([double pixelVelocity = 0]) {
    // A 25ms release can arrive before the follower's first nonzero frame.
    // Show that frame before returning, rather than swallowing a short notch.
    if (_scrolling &&
        !_still &&
        _foreground &&
        _excursion.lastElapsedDuration == Duration.zero &&
        (_depthForRawDrag - _depth).abs() >= .0001) {
      final generation = _returnGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            generation == _returnGeneration &&
            _scrolling &&
            _scrollReturn?.isActive == false) {
          _returnHome(pixelVelocity);
        }
      });
      return;
    }
    final wasScrolling = _scrolling;
    final scrollVelocity = _excursion.velocity;
    _cancelScroll();
    _dragging = false;
    final generation = ++_returnGeneration;
    if (_resumeArrival && !_still) _arrival.forward();
    _resumeArrival = false;
    if (_still || _depth.abs() < .0001) {
      _excursion.value = 0;
      return;
    }
    final velocity = wasScrolling
        ? scrollVelocity
        : VoyageElasticity.depthVelocityForDrag(
            _rawDrag,
            pixelVelocity,
            _height,
            planetIndex: widget.current.planetIndex,
          ).clamp(-4.0, 4.0);
    _excursion
        .animateWith(
          SpringSimulation(
            wasScrolling
                ? _scrollReturnSpring
                : const SpringDescription(mass: 1, stiffness: 190, damping: 20),
            _depth,
            0,
            velocity,
            tolerance: const Tolerance(distance: .0005, velocity: .002),
          ),
        )
        .whenCompleteOrCancel(() {
          if (mounted && generation == _returnGeneration) {
            _excursion.value = 0;
          }
        });
  }

  void _nudge(double direction) {
    _cancelScroll();
    _returnGeneration++;
    _excursion.stop();
    _excursion.value = direction * .55;
    _rawDrag = VoyageElasticity.dragForDepth(
      _depth,
      _height,
      planetIndex: widget.current.planetIndex,
    );
    _returnHome();
  }

  @override
  void dispose() {
    _cancelScroll();
    _returnGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _arrival.dispose();
    _excursion.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      _height = bounds.maxHeight.isFinite ? bounds.maxHeight : 350;
      return Semantics(
        container: true,
        enabled: true,
        label: 'Voyage system',
        value:
            'Anchored at planet ${widget.current.planetIndex + 1}, ${widget.current.name}, route ${widget.routesAtDestination + 1} of 15. More destinations continue ahead.',
        increasedValue:
            'Looking ahead from ${widget.current.name}; returning to your destination.',
        decreasedValue:
            'Looking back from ${widget.current.name}; returning to your destination.',
        hint: 'Drag or scroll down to explore ahead, or up to look back. Pause scrolling or release to return to your destination.',
        onIncrease: () => _nudge(1),
        onDecrease: () => _nudge(-1),
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                    event.logicalKey == LogicalKeyboardKey.arrowUp)) {
              _nudge(event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            onPointerSignal: _pointerSignal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragDown: (_) => _hold(),
              onVerticalDragStart: _startDrag,
              onVerticalDragUpdate: _updateDrag,
              onVerticalDragEnd: (details) =>
                  _returnHome(details.velocity.pixelsPerSecond.dy),
              onVerticalDragCancel: _returnHome,
              child: RepaintBoundary(
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_arrival, _excursion]),
                    builder: (context, _) => CustomPaint(
                      key: widget.sceneKey,
                      painter: VoyageDepthPainter(
                        current: widget.current,
                        approach: widget.arrivalCurve.transform(_arrival.value),
                        routesAtDestination: widget.routesAtDestination,
                        showCourier: widget.showCourier,
                        trailColor: widget.trailColor,
                        cameraExcursion: _depth,
                        ambient: widget.ambientMotion && !_still
                            ? _ambient
                            : null,
                        verticalFocus: widget.verticalFocus,
                        paintBackground: widget.paintBackground,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class VoyageMap extends StatefulWidget {
  const VoyageMap({
    super.key,
    required this.completedRoutes,
    required this.onContinue,
    this.reduceMotion = false,
    this.ambientMotion = false,
    this.frontierLevel,
    this.currentLevel,
    this.records = const {},
    this.onReplay,
    this.isReplaying = false,
  });

  final int completedRoutes;
  final VoidCallback onContinue;
  final bool reduceMotion, ambientMotion;
  final int? frontierLevel, currentLevel;
  final Map<int, RouteRecord> records;
  final ValueChanged<int>? onReplay;
  final bool isReplaying;

  @override
  State<VoyageMap> createState() => _VoyageMapState();
}

class _VoyageMapState extends State<VoyageMap> {
  int? _selectedPlanet;
  bool _routes = false;
  int get completedRoutes => widget.completedRoutes;
  VoidCallback get onContinue => widget.onContinue;
  bool get reduceMotion => widget.reduceMotion;
  bool get ambientMotion => widget.ambientMotion;
  int get _frontier => math.max(1, widget.frontierLevel ?? completedRoutes + 1);
  int get _frontierPlanet => (_frontier - 1) ~/ 15;
  int get _planet =>
      (_selectedPlanet ?? ((widget.currentLevel ?? _frontier) - 1) ~/ 15).clamp(
        0,
        _frontierPlanet + 3,
      );

  void _browse(int planet) => setState(() {
    _selectedPlanet = planet.clamp(0, _frontierPlanet + 3);
  });

  Widget _continueSemantics(Widget child) => widget.isReplaying
      ? Semantics(
          label: 'Resume current route',
          button: true,
          enabled: true,
          onTap: onContinue,
          excludeSemantics: true,
          child: child,
        )
      : child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (widget.onReplay != null) {
        return SizedBox(
          height: bounds.hasBoundedHeight ? bounds.maxHeight : 620,
          child: _history(context),
        );
      }
      return bounds.hasBoundedHeight ? _bounded(context) : _unbounded(context);
    },
  );

  Widget _history(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final world = VoyageWorld.forLevel(_planet * 15 + 1);
      final large = MediaQuery.textScalerOf(context).scale(1) > 1.6;
      final compact = bounds.maxHeight < 420;
      final still =
          reduceMotion ||
          MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.reduceMotionOf(context);
      final reached = _planet <= _frontierPlanet;
      final route = _planet == _frontierPlanet ? (_frontier - 1) % 15 + 1 : 15;
      final nav = Row(
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
            child: compact
                ? LayoutBuilder(
                    builder: (context, area) => Semantics(
                      label:
                          '${world.name}. Viewing planet ${_planet + 1}. ${!reached ? 'Upcoming destination.' : 'Routes available to replay.'}',
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (area.maxWidth >= 180)
                              Text(
                                world.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: large ? 10 : 20,
                                  height: 1.1,
                                  color: world.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(
                              'P${_planet + 1}',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: large ? 7 : 12,
                                height: 1.2,
                                color: _spaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Text(
                    '${_planet + 1}',
                    semanticsLabel:
                        'Viewing planet ${_planet + 1} of ${_frontierPlanet + 1} reached',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: large ? 11 : 14,
                      color: _spaceMuted,
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
      );
      final logKey = OrbitMode(
        key: const ValueKey('voyage-route-log'),
        label: _routes ? 'Map' : 'Routes',
        selected: _routes,
        reduceMotion: still,
        onPressed: () => setState(() => _routes = !_routes),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            Text(
              world.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: large ? 14 : 26,
                color: world.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Planet ${_planet + 1} · ${!reached
                  ? 'Ahead'
                  : _planet == _frontierPlanet
                  ? 'Route $route / 15'
                  : '15 routes unlocked'}',
              style: _bodyStyle.copyWith(fontSize: large ? 10 : 13),
            ),
          ],
          SizedBox(height: compact && large ? 68 : 52, child: nav),
          Expanded(
            child: AnimatedSwitcher(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _routes
                  ? VoyageArchive(
                      key: ValueKey('archive-planet-$_planet'),
                      planetIndex: _planet,
                      frontierLevel: _frontier,
                      records: widget.records,
                      onReplay: widget.onReplay!,
                      reduceMotion: still,
                    )
                  : VoyageExplorer(
                      key: ValueKey('explore-planet-$_planet'),
                      current: world,
                      routesAtDestination: !reached
                          ? 0
                          : _planet == _frontierPlanet
                          ? route - 1
                          : 15,
                      reduceMotion: still,
                      ambientMotion: ambientMotion,
                      sceneKey: const ValueKey('voyage-depth-scene'),
                      verticalFocus: .36,
                      paintBackground: false,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (compact && large)
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  SizedBox(width: 100, child: logKey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _continueSemantics(
                      OrbitMode(
                        label: widget.isReplaying ? 'Resume' : 'Continue',
                        selected: false,
                        onPressed: onContinue,
                        reduceMotion: still,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                SizedBox(width: 90, child: logKey),
                const SizedBox(width: 8),
                Expanded(
                  child: _continueSemantics(
                    SpaceAction(
                      label: widget.isReplaying
                          ? (compact || large
                                ? 'Resume'
                                : 'Resume current route')
                          : large
                          ? 'Play'
                          : 'Continue',
                      onPressed: onContinue,
                      accent: _spaceTeal,
                      reduceMotion: still,
                      compact: true,
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    },
  );

  Widget _bounded(BuildContext context) {
    final completed = math.max(0, completedRoutes);
    final current = VoyageWorld.forLevel(completed + 1);
    final destinations = VoyageDestinationWindow(current).chart;
    final largeType = MediaQuery.textScalerOf(context).scale(1) > 1.6;
    final still =
        reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          current.name,
          maxLines: 2,
          style: TextStyle(
            fontSize: largeType ? 15 : 28,
            height: 1.15,
            color: current.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          largeType
              ? 'P${current.planetIndex + 1} · ${current.routeWithin(completed + 1)}/15'
              : 'Planet ${current.planetIndex + 1} · Route ${current.routeWithin(completed + 1)}/15',
          semanticsLabel:
              'Planet ${current.planetIndex + 1}. Route ${current.routeWithin(completed + 1)} of 15.',
          style: _bodyStyle.copyWith(fontSize: largeType ? 12 : 15),
        ),
        Expanded(
          child: VoyageExplorer(
            current: current,
            routesAtDestination: completed % VoyageWorld.routesPerPlanet,
            reduceMotion: still,
            ambientMotion: ambientMotion,
            sceneKey: const ValueKey('voyage-depth-scene'),
            verticalFocus: .36,
          ),
        ),
        Row(
          children: [
            for (final world in destinations)
              Expanded(
                child: _DestinationOrbitKey(
                  world: world,
                  completed:
                      (completed -
                              world.planetIndex * VoyageWorld.routesPerPlanet)
                          .clamp(0, 15),
                  current: current.planetIndex == world.planetIndex,
                  largeType: largeType,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _continueSemantics(
          SpaceAction(
            label: widget.isReplaying
                ? (largeType ? 'Resume' : 'Resume current route')
                : 'Continue',
            icon: Icons.rocket_launch_rounded,
            onPressed: onContinue,
            accent: _spaceTeal,
            reduceMotion: still,
            compact: largeType,
          ),
        ),
      ],
    );
  }

  Widget _unbounded(BuildContext context) {
    final completed = math.max(0, completedRoutes);
    final current = VoyageWorld.forLevel(completed + 1);
    final galaxyStart = current.galaxyIndex * VoyageWorld.routesPerGalaxy;
    final inGalaxy = completed - galaxyStart;
    final destinations = VoyageDestinationWindow(current).chart;
    final still =
        reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            current.galaxyName,
            style: const TextStyle(
              fontFamily: 'Manrope',
              color: _spaceText,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$inGalaxy of 75 routes charted · Galaxy ${current.galaxyIndex + 1}',
          style: _bodyStyle,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, bounds) => SizedBox(
            height: (bounds.maxWidth * 1.02).clamp(280.0, 470.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: VoyageExplorer(
                current: current,
                routesAtDestination: inGalaxy % VoyageWorld.routesPerPlanet,
                reduceMotion: still,
                ambientMotion: ambientMotion,
                sceneKey: const ValueKey('voyage-depth-scene'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Route ${inGalaxy % VoyageWorld.routesPerPlanet + 1} of 15 · ${current.name}',
          style: _bodyStyle.copyWith(color: current.accent, fontSize: 16),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, bounds) {
            final large = MediaQuery.textScalerOf(context).scale(1) > 1.6;
            final width = large ? bounds.maxWidth : (bounds.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final world in destinations)
                  SizedBox(
                    width: width,
                    child: _DestinationKey(
                      world: world,
                      completed:
                          (completed -
                                  world.planetIndex *
                                      VoyageWorld.routesPerPlanet)
                              .clamp(0, VoyageWorld.routesPerPlanet),
                      current: world.planetIndex == current.planetIndex,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _continueSemantics(
          SpaceAction(
            label: widget.isReplaying
                ? 'Resume current route'
                : 'Continue to ${current.name}',
            onPressed: onContinue,
            accent: _spaceTeal,
            reduceMotion: still,
          ),
        ),
      ],
    );
  }
}

class _DestinationOrbitKey extends StatelessWidget {
  const _DestinationOrbitKey({
    required this.world,
    required this.completed,
    required this.current,
    required this.largeType,
  });
  final VoyageWorld world;
  final int completed;
  final bool current, largeType;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${world.name}. ${current
            ? 'Current destination. '
            : completed == 0
            ? 'Upcoming destination. '
            : ''}'
        '$completed of 15 routes charted.${world.isBlackHole ? ' Black hole.' : ''}'
        '${!current && completed == 0 ? ' Complete earlier routes to unlock.' : ''}',
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlanetMedallion(world: world, size: largeType ? 28 : 34),
          if (!largeType)
            Text(
              world.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: current ? world.accent : _spaceMuted,
                fontSize: 10,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var leg = 0; leg < 3; leg++)
                Container(
                  width: 9,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: completed > leg * 5
                        ? world.accent
                        : _spaceMuted.withValues(alpha: .3),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

const _bodyStyle = TextStyle(
  fontFamily: 'Manrope',
  color: _spaceMuted,
  fontSize: 15,
  height: 1.4,
);

/// Compact chart key, not a second navigation menu. All destinations remain
/// available to screen readers even when a completed world is behind camera.
class _DestinationKey extends StatelessWidget {
  const _DestinationKey({
    required this.world,
    required this.completed,
    required this.current,
  });
  final VoyageWorld world;
  final int completed;
  final bool current;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${world.name}. ${current
            ? 'Current destination. '
            : completed == 0
            ? 'Upcoming destination. '
            : ''}'
        '$completed of 15 routes charted.${world.isBlackHole ? ' Black hole.' : ''}'
        '${!current && completed == 0 ? ' Complete earlier routes to unlock.' : ''}',
    child: ExcludeSemantics(
      child: Row(
        children: [
          PlanetMedallion(world: world, size: 40),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  world.name,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    color: current ? world.accent : _spaceText,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: List.generate(
                    3,
                    (i) => Container(
                      width: 18,
                      height: 4,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: completed > i * 5
                            ? world.accent.withValues(
                                alpha: ((completed - i * 5) / 5).clamp(.2, 1),
                              )
                            : Colors.transparent,
                        border: Border.all(
                          color: completed > i * 5 ? world.accent : _spaceMuted,
                        ),
                      ),
                    ),
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

/// Perspective coordinates use a real camera-depth divisor. During approach,
/// bodies grow and stars move radially out from the vanishing point; the chart
/// never slides vertically to fake forward travel. Optional idle drift is
/// painter-only, without camera movement or rebuilding the controls.
class VoyageDepthPainter extends CustomPainter {
  VoyageDepthPainter({
    required this.current,
    required this.approach,
    required this.routesAtDestination,
    this.showCourier = false,
    this.trailColor = _spaceGold,
    this.cameraExcursion = 0,
    this.ambient,
    this.verticalFocus = .30,
    this.paintBackground = true,
  }) : super(repaint: ambient);
  final VoyageWorld current;
  final double approach;
  final int routesAtDestination;
  final bool showCourier;
  final Color trailColor;
  final double cameraExcursion;
  final Animation<double>? ambient;
  final double verticalFocus;
  final bool paintBackground;
  static const destinationSpacing = 2.65;
  static const nearPlane = .8;

  /// Four bodies travel through a virtual window as the camera moves. The
  /// horizon is never populated with a crowd of increasingly tiny objects.
  late final List<VoyageWorld> _destinations = List.generate(4, (offset) {
    final firstAhead = math.max(
      -current.planetIndex,
      ((_cameraZ - (2.4 - nearPlane)) / destinationSpacing).ceil(),
    );
    return VoyageWorld.forLevel(
      (current.planetIndex + firstAhead + offset) *
              VoyageWorld.routesPerPlanet +
          1,
    );
  }, growable: false);

  double get ambientPhase => (ambient?.value ?? 0) * math.pi * 2;

  // Keep the composition, orbit markers and flight destination anchored.
  // Rotation belongs to the surface; moving the whole sphere reads as sway.

  /// Landscape tablets have much more width than available flight height.
  /// Scale the scene by that height while retaining the phone/map artwork.
  static double sceneSpan(Size size) => size.width > size.height
      ? math.min(size.width, size.height * .9)
      : size.width;

  double get _cameraZ => approach.clamp(0.0, 1.0) * .48 + _boundedExcursion;

  double get _boundedExcursion => cameraExcursion.clamp(
    VoyageElasticity.minimumDepth(current.planetIndex),
    VoyageElasticity.maxDepth,
  );

  static const _positions = [
    Offset(-.72, .72),
    Offset(1.35, .24),
    Offset(-.98, -.56),
    Offset(1.88, -1.92),
  ];

  Offset _lanePosition(int ahead) {
    // Monotone Hermite segments share tangents at every anchor. In particular,
    // the sideways reversals slow to zero instead of abruptly changing course.
    // Harmonic-mean tangents preserve each segment's bounds and existing art
    // positions; the clamped outer anchors have zero tangents.
    const anchors = [Offset(-1.2, 1.2), ..._positions];
    final distance = ahead - _boundedExcursion / destinationSpacing;
    final coordinate = distance + 1;
    if (coordinate <= 0) return anchors.first;
    if (coordinate >= anchors.length - 1) return anchors.last;

    double slope(double before, double after) =>
        before * after <= 0 ? 0 : 2 * before * after / (before + after);
    Offset tangent(int index) {
      if (index == 0 || index == anchors.length - 1) return Offset.zero;
      final before = anchors[index] - anchors[index - 1];
      final after = anchors[index + 1] - anchors[index];
      return Offset(slope(before.dx, after.dx), slope(before.dy, after.dy));
    }

    final lower = coordinate.floor();
    final t = coordinate - lower, t2 = t * t, t3 = t2 * t;
    return anchors[lower] * (2 * t3 - 3 * t2 + 1) +
        tangent(lower) * (t3 - 2 * t2 + t) +
        anchors[lower + 1] * (-2 * t3 + 3 * t2) +
        tangent(lower + 1) * (t3 - t2);
  }

  Rect _bodyBounds(Size size, VoyageWorld world, double z) {
    final ahead = world.planetIndex - current.planetIndex;
    final position = _lanePosition(ahead);
    final center = _project(size, position.dx, position.dy, z);
    return Rect.fromCircle(
      center: center,
      radius:
          sceneSpan(size) * (world.isBlackHole ? .46 : .42) / math.max(.05, z),
    );
  }

  /// The actual core-body bounds used by the renderer, before decorative
  /// rings/glow. Useful for checking that a destination fits the viewport.
  Rect currentPlanetBounds(Size size) =>
      _bodyBounds(size, current, 2.4 - _cameraZ);

  /// The core-body bounds painted by this frame, keyed by absolute planet
  /// index. Near clipping affects visibility, never the progression anchor.
  Map<int, Rect> visiblePlanetBounds(Size size) => {
    for (final world in _destinations)
      if (destinationVisibility(_planetDepth(world)) > .001)
        world.planetIndex: _bodyBounds(size, world, _planetDepth(world)),
  };

  double _planetDepth(VoyageWorld world) =>
      2.4 +
      (world.planetIndex - current.planetIndex) * destinationSpacing -
      _cameraZ;

  double destinationVisibility(double depth) =>
      ((depth - nearPlane) / .7).clamp(0.0, 1.0) *
      ((11.4 - depth) / 3.3).clamp(0.0, 1.0) *
      (1 - (depth - 1.9).clamp(0.0, 7.0) * .07);

  /// The actual projected flight path used for the courier and its trail.
  Offset courierPosition(Size size, {double? progress}) {
    final t = (progress ?? approach).clamp(0.0, 1.0);
    final excursion = _boundedExcursion;
    final angle = .72 + routesAtDestination.clamp(0, 14) * (.76 / 14);
    final orbitRadius = (current.isBlackHole ? .46 : .42) / .8 * 1.22;
    final destination =
        const Offset(-.72, .72) +
        Offset(math.cos(angle), math.sin(angle)) * orbitRadius;
    final x = .28 + (destination.dx - .28) * t + math.sin(t * math.pi) * .14;
    final y = .68 + (destination.dy - .68) * t - math.sin(t * math.pi) * .36;
    final z = 1.05 + (2.4 - 1.05) * t - t * .48 - excursion;
    return _project(size, x, y, z);
  }

  double courierUnit(Size size, {double? progress}) {
    final t = (progress ?? approach).clamp(0.0, 1.0);
    final z = 1.05 + .87 * t - _boundedExcursion;
    return sceneSpan(size) * .035 / math.max(.05, z);
  }

  static Offset project(
    Size size,
    double x,
    double y,
    double z, {
    double verticalFocus = .30,
  }) {
    final focal = sceneSpan(size) * .8;
    final safeDepth = math.max(.05, z);
    return Offset(
      size.width * .58 + x * focal / safeDepth,
      size.height * verticalFocus + y * focal / safeDepth,
    );
  }

  Offset _project(Size size, double x, double y, double z) =>
      project(size, x, y, z, verticalFocus: verticalFocus);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final phase = ambientPhase;
    // Match the surrounding universe exactly at every edge, including sheets.
    // Planet-local atmospheric light supplies depth without a visible scene box.
    if (paintBackground) canvas.drawRect(bounds, Paint()..color = _spaceInk);
    final cameraZ = _cameraZ;
    final focus = _project(size, 0, 0, 1);
    // A fixed field in world space: moving only camera z produces depth.
    for (var i = 0; i < 94; i++) {
      final angle = i * 2.3999632297;
      final spread = .8 + (i % 13) * .24;
      final x = math.cos(angle) * spread;
      final y = math.sin(angle) * spread;
      final z = 1.5 + (i * 7 % 107) / 7 - cameraZ;
      if (z < .3) continue;
      final distant = z > 3;
      final starDrift = Offset(
        math.sin(phase * 3) * (distant ? 5 : 15),
        (math.cos(phase * 3) - 1) * (distant ? 3 : 8),
      );
      final point = _project(size, x, y, z) + starDrift;
      final radius = (.55 + (i % 3) * .2) * 2.0 / z;
      final color = (i % 9 == 0 ? _spaceGold : _spaceText).withValues(
        alpha: (.25 + .45 / z).clamp(0.0, .8),
      );
      if (bounds.contains(point)) {
        canvas.drawCircle(
          point,
          radius.clamp(.45, 1.9),
          Paint()..color = color,
        );
        if (approach < .9 && z < 2.5) {
          final radial = point - focus;
          canvas.drawLine(
            point,
            point - radial * .014 * (1 - approach),
            Paint()
              ..color = color.withValues(alpha: .2)
              ..strokeWidth = .8,
          );
        }
      }
    }
    // Soft orbital arcs converge at the same focal point, giving the scene
    // depth without a floor grid or a chain of vertically stacked level dots.
    for (var i = 0; i < 3; i++) {
      final z = 2.1 + i * 1.7 - cameraZ;
      if (z < .4) continue;
      final radius = sceneSpan(size) * .74 / z;
      canvas.save();
      canvas.translate(focus.dx, focus.dy);
      canvas.rotate(-.45);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 3.5,
          height: radius * 1.45,
        ),
        .2,
        math.pi * 1.2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = _spaceTeal.withValues(alpha: .09),
      );
      canvas.restore();
    }
    // Back-to-front world coordinates. A backward pull can reveal the last
    // charted world; a forward pull approaches the next one. Near clipping
    // keeps projected bodies finite as the current world leaves the frame.
    for (final world in _destinations.reversed) {
      final ahead = world.planetIndex - current.planetIndex;
      final z = _planetDepth(world);
      if (z < nearPlane) continue;
      final visibility = destinationVisibility(z);
      if (visibility <= 0) continue;
      final body = _bodyBounds(size, world, z);
      final center = body.center;
      final radius = body.width / 2;
      if (ahead == 0) {
        final glow = Rect.fromCircle(center: center, radius: radius * 1.8);
        canvas.drawCircle(
          center,
          radius * 1.8,
          Paint()
            ..shader = RadialGradient(
              colors: [
                world.accent.withValues(alpha: .065 * visibility),
                world.accent.withValues(alpha: 0),
              ],
            ).createShader(glow),
        );
      }
      _drawPlanet(
        canvas,
        center,
        radius,
        world,
        world.isBlackHole,
        visibility,
        rotation: phase,
      );
      if (ahead == 0) {
        final orbit = Rect.fromCircle(center: center, radius: radius * 1.22);
        canvas.drawArc(
          orbit,
          -.45,
          .8,
          false,
          Paint()
            ..color = world.accent.withValues(alpha: .6 * visibility)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        for (var point = 0; point < 15; point++) {
          final angle = .72 + point * (.76 / 14);
          final location =
              center + Offset(math.cos(angle), math.sin(angle)) * radius * 1.22;
          // The full-screen tablet footer holds collection progress
          // and Play. Let only these decorative dots recede before its text;
          // the planet, courier and camera retain their full-universe geometry.
          final footerFade =
              size.shortestSide >= 600 &&
                  (size.width > size.height
                      ? verticalFocus <= .24
                      : verticalFocus >= .35)
              ? ((size.height - 300 - location.dy) / 28).clamp(0.0, 1.0)
              : 1.0;
          if (footerFade == 0) continue;
          canvas.drawCircle(
            location,
            point % 5 == 0 ? 2.3 : 1.7,
            Paint()
              ..style = point < routesAtDestination
                  ? PaintingStyle.fill
                  : PaintingStyle.stroke
              ..strokeWidth = .8
              ..color = world.accent.withValues(alpha: visibility * footerFade),
          );
        }
      }
    }
    if (showCourier) {
      final alpha = (1 - cameraExcursion.abs() / .8).clamp(0.0, 1.0);
      if (alpha >= 1) {
        _drawCourier(canvas, size);
      } else if (alpha > 0) {
        canvas.saveLayer(
          bounds,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
        _drawCourier(canvas, size);
        canvas.restore();
      }
    }
  }

  void _drawCourier(Canvas canvas, Size size) {
    final progress = approach.clamp(0.0, 1.0);
    final excursion = _boundedExcursion;
    final z = 1.05 + .87 * progress - excursion;
    if (z < .4) return;
    Offset position(double t) => courierPosition(size, progress: t);

    final point = position(progress);
    final tangent =
        position(math.min(1, progress + .01)) -
        position(math.max(0, progress - .01));
    final unit = courierUnit(size);
    final target = position(1);
    canvas.drawCircle(
      target,
      5.5,
      Paint()
        ..color = current.accent.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    if (progress > .01 && progress < .98) {
      final trail = Path();
      for (var sample = 0; sample <= 14; sample++) {
        final t = math.max(0.0, progress - .22 + sample / 14 * .22);
        final at = position(t);
        if (sample == 0) {
          trail.moveTo(at.dx, at.dy);
        } else {
          trail.lineTo(at.dx, at.dy);
        }
      }
      canvas.drawPath(
        trail,
        Paint()
          ..color = trailColor.withValues(alpha: .2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * .65
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        trail,
        Paint()
          ..color = _spaceText.withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.7, unit * .13)
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(
      math.atan2(tangent.dy, tangent.dx) +
          math.pi / 2 +
          math.sin(progress * math.pi) * .14,
    );
    canvas.scale(unit);
    if (progress < .98) {
      final flame = Path()
        ..moveTo(-.25, .78)
        ..quadraticBezierTo(-.31, 1.48, 0, 2.1)
        ..quadraticBezierTo(.31, 1.48, .25, .78)
        ..close();
      canvas.drawPath(
        flame,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_spaceText, trailColor, trailColor.withValues(alpha: 0)],
          ).createShader(const Rect.fromLTWH(-.35, .75, .7, 1.4)),
      );
    }
    drawOrbitalCraft(canvas, accent: trailColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(VoyageDepthPainter old) =>
      current.planetIndex != old.current.planetIndex ||
      approach != old.approach ||
      routesAtDestination != old.routesAtDestination ||
      showCourier != old.showCourier ||
      trailColor != old.trailColor ||
      cameraExcursion != old.cameraExcursion ||
      ambient != old.ambient ||
      verticalFocus != old.verticalFocus ||
      paintBackground != old.paintBackground;
}

class _SpacePainter extends CustomPainter {
  _SpacePainter(this.world, this.motion) : super(repaint: motion);
  final VoyageWorld world;
  final Animation<double>? motion;

  static const _stars = <Offset>[
    Offset(.04, .07),
    Offset(.24, .025),
    Offset(.58, .04),
    Offset(.76, .018),
    Offset(.94, .05),
    Offset(.985, .20),
    Offset(.025, .27),
    Offset(.965, .36),
    Offset(.045, .43),
    Offset(.98, .55),
    Offset(.02, .67),
    Offset(.955, .74),
    Offset(.035, .86),
    Offset(.97, .93),
    Offset(.17, .975),
    Offset(.83, .985),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final phase = (motion?.value ?? 0) * math.pi * 2;
    final nearDrift = Offset(
      math.sin(phase * 3) * 10,
      (math.cos(phase * 3) - 1) * 5,
    );
    final farDrift = Offset(
      math.sin(phase * 3) * 5,
      (math.cos(phase * 3) - 1) * 3,
    );
    for (var i = 0; i < _stars.length; i++) {
      final point =
          Offset(_stars[i].dx * size.width, _stars[i].dy * size.height) +
          (i.isEven ? farDrift : nearDrift);
      final color = (i % 4 == 0 ? _spaceGold : _spaceMuted).withValues(
        alpha: i % 3 == 0 ? .55 : .32,
      );
      if (i % 3 == 0) {
        _drawStar(canvas, point, 3.2, color);
      } else {
        canvas.drawCircle(point, i.isEven ? .8 : 1.2, Paint()..color = color);
      }
    }
    final center = Offset(size.width * .94, math.min(98.0, size.height * .13));
    final radius = math.min(58.0, size.width * .14);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 3.5,
        height: radius * 1.4,
      ),
      Paint()
        ..color = world.accent.withValues(alpha: .09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
    _drawPlanet(
      canvas,
      center,
      radius,
      world,
      world.isBlackHole,
      .28,
      rotation: phase,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(-size.width * .18, size.height * .83),
        radius: size.width * .24,
      ),
      -.9,
      1.8,
      false,
      Paint()
        ..color = _spaceTeal.withValues(alpha: .08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SpacePainter oldDelegate) =>
      oldDelegate.world.index != world.index ||
      oldDelegate.world.galaxyIndex != world.galaxyIndex ||
      oldDelegate.motion != motion;
}

class _PlanetPainter extends CustomPainter {
  _PlanetPainter(this.world, this.portal);
  final VoyageWorld world;
  final bool portal;

  @override
  void paint(Canvas canvas, Size size) => _drawPlanet(
    canvas,
    size.center(Offset.zero),
    math.min(size.width, size.height) * .32,
    world,
    portal,
    1,
  );

  @override
  bool shouldRepaint(_PlanetPainter oldDelegate) =>
      world.planetIndex != oldDelegate.world.planetIndex ||
      portal != oldDelegate.portal;
}

// Original procedural artwork. Each destination has a different silhouette,
// surface language and lighting, not a recolor of one sphere texture.
void _drawPlanet(
  Canvas canvas,
  Offset center,
  double radius,
  VoyageWorld world,
  bool portal,
  double opacity, {
  double rotation = 0,
}) {
  if (radius <= 0 || !radius.isFinite || opacity <= 0) return;
  Color shade(Color color, [double alpha = 1]) =>
      color.withValues(alpha: alpha * opacity);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  // Appearance follows the authored destination, never its slot in a sector.
  switch (world.kind) {
    case CelestialKind.blackHole:
      _drawVeil(
        canvas,
        radius,
        opacity,
        rotation,
        world: world.planetIndex < 5 ? null : world,
      );
      canvas.restore();
      return;
    case CelestialKind.star:
      _drawSun(canvas, radius, world, opacity, rotation);
      canvas.restore();
      return;
    case CelestialKind.comet:
      _drawComet(canvas, radius, world, opacity, rotation);
      canvas.restore();
      return;
    case CelestialKind.asteroids:
      _drawAsteroidField(canvas, radius, world, opacity, rotation);
      canvas.restore();
      return;
    case CelestialKind.galaxy:
      _drawGalaxy(canvas, radius, world, opacity, rotation);
      canvas.restore();
      return;
    default:
      break;
  }
  final ringed = world.kind == CelestialKind.ringed;
  if (ringed) {
    canvas.rotate(world.tilt);
    _drawRings(canvas, radius, opacity, front: false, world: world);
  }
  final bounds = Rect.fromCircle(center: Offset.zero, radius: radius);
  final silhouette = Path()..addOval(bounds);
  if (world.kind == CelestialKind.ocean) {
    canvas.drawCircle(
      Offset.zero,
      radius * 1.035,
      Paint()..color = shade(const Color(0xFF89DCE9), .2),
    );
  }
  canvas.drawPath(
    silhouette,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.62, -.65),
        radius: 1.2,
        colors: [
          world.highlight,
          world.bodyColor,
          world.shadow,
        ].map((color) => shade(color)).toList(),
        stops: const [0, .47, 1],
      ).createShader(bounds),
  );
  canvas.save();
  canvas.clipPath(silhouette);
  _drawIllustratedSurface(canvas, radius, world, opacity, rotation);
  // One shared light direction unifies materials while preserving their
  // distinct textures. The night side covers the surface marks as well.
  canvas.drawRect(
    bounds,
    Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-.85, -.4),
        end: const Alignment(.85, .5),
        colors: [
          shade(_spaceInk, 0),
          shade(_spaceInk, 0),
          shade(_spaceInk, .65),
        ],
        stops: const [0, .48, 1],
      ).createShader(bounds),
  );
  canvas.restore();
  canvas.drawArc(
    bounds.deflate(radius * .015),
    -math.pi * .98,
    math.pi * .72,
    false,
    Paint()
      ..color = shade(_spaceText, .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.6, radius * .018),
  );
  if (ringed) _drawRings(canvas, radius, opacity, front: true, world: world);
  if (world.planetIndex == 2) {
    // Keep Viridian's original little cold companion exactly in place.
    final moon = Offset(radius * .99, -radius * .9);
    canvas.drawCircle(
      moon,
      radius * .16,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.5, -.5),
          colors: [shade(_spaceText), shade(const Color(0xFF496B84))],
        ).createShader(Rect.fromCircle(center: moon, radius: radius * .16)),
    );
  } else if (world.planetIndex >= 5) {
    for (var i = 0; i < world.moonCount; i++) {
      final angle = -.83 + i * 3.9 + world.surfaceVariant * .13;
      final moon = Offset(math.cos(angle), math.sin(angle)) * radius * 1.33;
      final moonRadius = radius * (i == 0 ? .14 : .085);
      canvas.drawCircle(
        moon,
        moonRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.5, -.5),
            colors: [shade(world.highlight), shade(world.shadow)],
          ).createShader(Rect.fromCircle(center: moon, radius: moonRadius)),
      );
    }
  }
  canvas.restore();
}

// Surface patches rotate in longitude while the lit sphere stays anchored.
// Front-hemisphere clipping prevents patches jumping across the far-side seam.
void _surfacePatch(
  Canvas canvas,
  double radius,
  List<Offset> vertices,
  double rotation,
  Paint paint,
) {
  final phase = rotation % (math.pi * 2);
  for (final turn in [-1, 0, 1]) {
    var points = vertices
        .map((point) => point + Offset(phase + turn * math.pi * 2, 0))
        .toList();
    for (final edge in [-math.pi / 2, math.pi / 2]) {
      if (points.isEmpty) break;
      final input = points;
      points = [];
      bool inside(Offset point) =>
          edge < 0 ? point.dx >= edge : point.dx <= edge;
      var previous = input.last;
      for (final point in input) {
        final wasInside = inside(previous), isInside = inside(point);
        if (wasInside != isInside) {
          final t = (edge - previous.dx) / (point.dx - previous.dx);
          points.add(Offset(edge, previous.dy + (point.dy - previous.dy) * t));
        }
        if (isInside) points.add(point);
        previous = point;
      }
    }
    if (points.length < 3) continue;
    Offset project(Offset point) => Offset(
      math.sin(point.dx) * math.cos(point.dy) * radius,
      math.sin(point.dy) * radius,
    );
    final path = Path();
    final first = project(points.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 0; i < points.length; i++) {
      final from = points[i], to = points[(i + 1) % points.length];
      for (var step = 1; step <= 6; step++) {
        final point = project(Offset.lerp(from, to, step / 6)!);
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), paint);
  }
}

void _drawIllustratedSurface(
  Canvas canvas,
  double r,
  VoyageWorld world,
  double opacity,
  double rotation,
) {
  Color color(Color value, double alpha) =>
      value.withValues(alpha: alpha * opacity);
  final legacy = world.planetIndex < 5;
  final variant = world.surfaceVariant;
  final phase = rotation + (legacy ? world.galaxyIndex * .31 : variant * .57);
  Color tone(Color value) =>
      legacy ? value : Color.lerp(value, world.accent, .48)!;
  void patch(List<Offset> points, Color fill, double alpha) => _surfacePatch(
    canvas,
    r,
    points,
    phase,
    Paint()..color = color(tone(fill), alpha),
  );
  void band(
    double latitude,
    double width,
    Color fill,
    double alpha,
    double offset,
  ) {
    final path = Path();
    for (var i = 0; i <= 72; i++) {
      final longitude = -math.pi / 2 + i / 72 * math.pi;
      final lat = latitude + math.sin(longitude * 2 + phase + offset) * .035;
      final point = Offset(
        math.sin(longitude) * math.cos(lat) * r,
        math.sin(lat) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color(tone(fill), alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * width
        ..strokeCap = StrokeCap.round,
    );
  }

  if (world.kind == CelestialKind.moon) {
    // Luma: broad mist swaths and quiet, softly rimmed lunar craters.
    band(-.28, .17, const Color(0xFFE0F6E7), .18, .3);
    band(.43, .11, const Color(0xFFB9D9C7), .16, 1.4);
    for (var i = 0; i < 12 + variant % 3 * 3; i++) {
      final longitude = (i * 2.39996) % (math.pi * 2) - math.pi;
      final latitude = math.sin(i * 3.7 + variant * .6) * .85;
      final radius = .10 + (i % 3) * .035 + variant % 2 * .025;
      List<Offset> oval(double y) => List.generate(32, (step) {
        final angle = step / 32 * math.pi * 2;
        return Offset(
          longitude + math.cos(angle) * radius,
          latitude + math.sin(angle) * radius * .68 + y,
        );
      });
      patch(oval(0), const Color(0xFF275F6A), .23);
      _surfacePatch(
        canvas,
        r,
        oval(-.018),
        phase,
        Paint()
          ..color = color(const Color(0xFFE3F2DC), .28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.6, r * .008),
      );
    }
  } else if (world.kind == CelestialKind.volcanic) {
    // Ember: broad russet facets and a few warm, graphic fissures.
    for (var i = 0; i < 7 + variant % 3; i++) {
      final x = i * (legacy ? .93 : math.pi * 2 / (7 + variant % 3)) - math.pi;
      patch(
        [
          Offset(x - .4, -.8),
          Offset(x + .32, -.6),
          Offset(x + .45, -.1),
          Offset(x + .1, .16),
          Offset(x + .42, .63),
          Offset(x - .35, .9),
          Offset(x - .13, .23),
          Offset(x - .39, -.12),
        ],
        i.isEven ? const Color(0xFFD1764C) : const Color(0xFF5E3038),
        .32,
      );
      final seam = [
        Offset(x, -.78),
        Offset(x + .17, -.32),
        Offset(x - .05, -.07),
        Offset(x + .22, .37),
        Offset(x + .06, .73),
        Offset(x + .10, .72),
        Offset(x + .27, .37),
        Offset(x, -.07),
        Offset(x + .22, -.32),
        Offset(x + .04, -.78),
      ];
      patch(seam, legacy ? const Color(0xFFEFAD70) : world.highlight, .7);
    }
  } else if (world.kind == CelestialKind.ocean) {
    // Viridian: simple sage continent silhouettes, pale latitude clouds and moon.
    const continents = [
      [
        Offset(-1.52, -.57),
        Offset(-.90, -.70),
        Offset(-.37, -.51),
        Offset(-.15, -.24),
        Offset(-.43, .01),
        Offset(-.12, .30),
        Offset(-.37, .57),
        Offset(-.69, .82),
        Offset(-.78, .39),
        Offset(-1.18, .22),
        Offset(-1.42, -.12),
      ],
      [
        Offset(.54, -.79),
        Offset(.86, -.62),
        Offset(1.35, -.50),
        Offset(1.50, -.03),
        Offset(1.14, .11),
        Offset(.71, .03),
        Offset(.36, -.20),
        Offset(.56, -.44),
      ],
      [
        Offset(2.01, -.21),
        Offset(2.64, -.38),
        Offset(2.94, -.09),
        Offset(2.72, .42),
        Offset(2.38, .69),
        Offset(2.17, .25),
      ],
      [
        Offset(-2.95, -.74),
        Offset(-2.30, -.44),
        Offset(-2.09, -.08),
        Offset(-2.44, .15),
        Offset(-2.83, -.03),
      ],
    ];
    for (var i = 0; i < continents.length; i++) {
      final land = continents[i];
      final scale = legacy ? 1.0 : [1.0, .58, .88, 1.1, .48][variant % 5];
      final shift = legacy
          ? Offset.zero
          : Offset(
              math.sin(i * 2.1 + variant) * .42,
              math.cos(i * 1.7 + variant) * .18,
            );
      final anchor = land.reduce((a, b) => a + b) / land.length.toDouble();
      patch(
        legacy
            ? land
            : land
                  .map((point) => anchor + (point - anchor) * scale + shift)
                  .toList(),
        const Color(0xFF9FCAA8),
        .80,
      );
    }
    if (!legacy && variant.isOdd) {
      for (var i = 0; i < 7; i++) {
        final x = i * .87 - 2.8;
        final y = math.sin(i * 2.2 + variant) * .62;
        patch(
          [
            Offset(x - .10, y),
            Offset(x + .04, y - .10),
            Offset(x + .16, y + .02),
            Offset(x + .05, y + .09),
          ],
          world.highlight,
          .62,
        );
      }
    }
    patch(
      List.generate(24, (i) {
        final angle = i / 24 * math.pi * 2;
        return Offset(
          .35 + math.cos(angle) * .19,
          .69 + math.sin(angle) * .085,
        );
      }),
      const Color(0xFFAECAA4),
      .75,
    );
    band(-.64, .075, const Color(0xFFD3E9E1), .34, 0);
    band(-.02, .065, const Color(0xFFD9EEE3), .52, 1.1);
    band(.58, .055, const Color(0xFFB5DFDD), .30, 2.6);
  } else if (world.kind == CelestialKind.ringed) {
    // Halo: softly bowed cream and ochre bands under the original tilted rings.
    const latitudes = [-.83, -.53, -.23, .05, .34, .64];
    for (var i = 0; i < latitudes.length; i++) {
      band(
        latitudes[i] + (legacy ? 0 : math.sin(variant * 1.4 + i) * .055),
        (i.isEven ? .09 : .065) * (1 + variant % 3 * .2),
        i.isEven ? const Color(0xFFF7D998) : const Color(0xFFAC7C56),
        i.isEven ? .57 : .35,
        i * .8,
      );
    }
  } else if (world.kind == CelestialKind.ice) {
    // Translucent polar shelves and angular glacier seams, not lunar craters.
    for (final pole in [-1.0, 1.0]) {
      final edge = .68 - variant % 3 * .09;
      patch(
        [
          for (var i = 0; i <= 24; i++)
            Offset(
              -math.pi + i / 24 * math.pi * 2,
              pole * (edge + math.sin(i * 1.3 + variant) * .07),
            ),
          Offset(math.pi, pole * math.pi / 2),
          Offset(-math.pi, pole * math.pi / 2),
        ],
        world.highlight,
        .72,
      );
    }
    for (var i = 0; i < 7 + variant % 3; i++) {
      final x = i * .89 - math.pi;
      patch(
        [
          Offset(x - .12, -.9),
          Offset(x + .16, -.36),
          Offset(x - .06, .08),
          Offset(x + .21, .48),
          Offset(x + .09, .96),
          Offset(x + .13, .96),
          Offset(x + .25, .48),
          Offset(x - .01, .08),
          Offset(x + .21, -.36),
          Offset(x - .08, -.9),
        ],
        world.highlight,
        .58,
      );
      patch(
        [
          Offset(x + .22, -.22),
          Offset(x + .42, -.4),
          Offset(x + .62, -.08),
          Offset(x + .43, .34),
        ],
        world.bodyColor,
        .22,
      );
    }
    band(.1, .12, world.highlight, .16, variant.toDouble());
  }
}

void _drawRings(
  Canvas canvas,
  double r,
  double opacity, {
  required bool front,
  required VoyageWorld world,
}) {
  final legacy = world.planetIndex == 3;
  final count = legacy ? 7 : 6 + world.surfaceVariant % 4;
  for (var i = 0; i < count; i++) {
    final scale = 1.32 + i * (legacy ? .077 : .065);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: r * 2 * scale,
      height: r * scale * .64,
    );
    canvas.drawArc(
      bounds,
      front ? 0 : math.pi,
      math.pi,
      false,
      Paint()
        ..color =
            (i == (legacy ? 4 : 2 + world.surfaceVariant % 3)
                    ? _spaceInk
                    : i.isEven
                    ? (legacy ? const Color(0xFFE7C9A5) : world.highlight)
                    : (legacy ? const Color(0xFFB19287) : world.bodyColor))
                .withValues(alpha: (front ? .82 : .45) * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.6, r * .054),
    );
  }
}

void _drawVeil(
  Canvas canvas,
  double r,
  double opacity,
  double rotation, {
  VoyageWorld? world,
}) {
  canvas.rotate(world?.tilt ?? -.28);
  final bounds = Rect.fromCircle(center: Offset.zero, radius: r);
  canvas.drawCircle(
    Offset.zero,
    r * 1.3,
    Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFB7A3E4).withValues(alpha: .04 * opacity),
          const Color(0xFF907BD0).withValues(alpha: .17 * opacity),
          Colors.transparent,
        ],
        stops: const [.2, .54, 1],
      ).createShader(bounds.inflate(r * .3)),
  );
  for (var i = 11; i >= 0; i--) {
    final outer = .68 + i * .037;
    final flatten = world == null ? 1.0 : .86 + world.surfaceVariant % 3 * .12;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset.zero,
        width: r * 2.5 * outer,
        height: r * .63 * outer * flatten,
      ),
      rotation + i * .018,
      math.pi * 1.82,
      false,
      Paint()
        ..color = Color.lerp(
          world?.highlight ?? const Color(0xFF68D2CC),
          world?.bodyColor ?? const Color(0xFFAA86C8),
          i / 11,
        )!.withValues(alpha: (.46 - i * .018) * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.6, r * .012),
    );
  }
  canvas.drawCircle(
    Offset.zero,
    r * .43,
    Paint()..color = _spaceInk.withValues(alpha: opacity),
  );
  canvas.drawArc(
    Rect.fromCircle(center: Offset.zero, radius: r * .45),
    math.pi * .88,
    math.pi * 1.05,
    false,
    Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFFBBD8F1).withValues(alpha: .8 * opacity),
          const Color(0xFF8AA6BA).withValues(alpha: .08 * opacity),
        ],
        transform: GradientRotation(rotation),
      ).createShader(bounds)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .024,
  );
  canvas.drawArc(
    Rect.fromCenter(center: Offset.zero, width: r * 2.5, height: r * .63),
    0,
    math.pi,
    false,
    Paint()
      ..color = const Color(0xFF88C7D5).withValues(alpha: .65 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.7, r * .017),
  );
}

// New destinations use the same softly lit, painted shapes as the first worlds.
// No textures, image decoding, offscreen layers or per-frame random generation.
void _drawSun(
  Canvas canvas,
  double r,
  VoyageWorld world,
  double opacity,
  double rotation,
) {
  final variant = world.surfaceVariant % 5;
  Color shade(Color color, double alpha) =>
      color.withValues(alpha: alpha * opacity);
  canvas.rotate(world.tilt);
  void sun(Offset center, double radius, {bool companion = false}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final bounds = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawCircle(
      Offset.zero,
      radius * 1.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            shade(world.bodyColor, .20),
            shade(world.bodyColor, .06),
            shade(world.bodyColor, 0),
          ],
          stops: const [.4, .65, 1],
        ).createShader(bounds.inflate(radius * .6)),
    );
    final count = variant == 4 ? 4 : 6 + variant;
    for (var i = 0; i < count; i++) {
      final angle = i / count * math.pi * 2 + math.sin(rotation) * .16;
      canvas.save();
      canvas.rotate(angle);
      final plume = Path()
        ..moveTo(-radius * .21, -radius * .85)
        ..cubicTo(
          -radius * .32,
          -radius * 1.2,
          radius * .11,
          -radius * (variant == 4 ? 1.48 : 1.29),
          radius * .15,
          -radius * .94,
        )
        ..quadraticBezierTo(0, -radius * 1.11, -radius * .21, -radius * .85);
      canvas.drawPath(plume, Paint()..color = shade(world.bodyColor, .32));
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.45, -.5),
          radius: 1.25,
          colors: [
            shade(world.highlight, 1),
            shade(world.bodyColor, 1),
            shade(companion ? world.shadow : world.bodyColor, 1),
          ],
          stops: const [0, .65, 1],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));
    for (var i = 0; i < 5; i++) {
      final latitude = -.7 + i * .34;
      final path = Path();
      for (var step = 0; step <= 36; step++) {
        final x = -1.1 + step / 36 * 2.2;
        final y = latitude + math.sin(x * 2 + i + rotation) * .065;
        if (step == 0) {
          path.moveTo(x * radius, y * radius);
        } else {
          path.lineTo(x * radius, y * radius);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = shade(world.highlight, .22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * (i.isEven ? .065 : .035)
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < 3; i++) {
      final x = math.sin(i * 2.8 + variant + rotation) * .65;
      final y = -.3 + i * .28;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x * radius, y * radius),
          width: radius * .14,
          height: radius * .055,
        ),
        Paint()..color = shade(world.shadow, .13),
      );
    }
    canvas.restore();
    canvas.drawArc(
      bounds.deflate(radius * .014),
      -math.pi * .98,
      math.pi * .7,
      false,
      Paint()
        ..color = shade(world.highlight, .62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.7, radius * .019),
    );
    canvas.restore();
  }

  if (variant == 2) {
    // Twin Suns is visibly a binary system, not another recolored disk.
    final orbit = Rect.fromCenter(
      center: Offset.zero,
      width: r * 2.5,
      height: r * 1.05,
    );
    canvas.drawOval(
      orbit,
      Paint()
        ..color = shade(world.accent, .13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.5, r * .009),
    );
    sun(Offset(-r * .37, -r * .13), r * .66);
    sun(Offset(r * .58, r * .26), r * .43, companion: true);
  } else {
    sun(Offset.zero, r * (variant == 3 ? .9 : .79));
  }
}

void _drawComet(
  Canvas canvas,
  double r,
  VoyageWorld world,
  double opacity,
  double rotation,
) {
  final variant = world.surfaceVariant % 5;
  Color shade(Color color, double alpha) =>
      color.withValues(alpha: alpha * opacity);
  canvas.save();
  canvas.rotate(world.tilt);
  final core = Offset(-r * .45, r * .34);
  final reach = 1.25 + variant * .065;
  // A broad dust sail and a separate narrow ion tail keep the silhouette clear
  // even when this destination is a small point in the distance.
  for (var i = 0; i < 3; i++) {
    final tail = Path()
      ..moveTo(core.dx - r * .13, core.dy - r * .05)
      ..cubicTo(
        r * .04,
        -r * .36,
        r * .68,
        -r * (.87 + i * .1),
        r * reach,
        -r * (.78 + i * .12),
      )
      ..cubicTo(
        r * .64,
        -r * (.4 + i * .06),
        r * .16,
        r * .26,
        core.dx + r * .15,
        core.dy + r * .12,
      )
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, 1),
          end: const Alignment(1, -1),
          colors: [
            shade(i == 1 ? world.highlight : world.bodyColor, .43 - i * .08),
            shade(world.bodyColor, 0),
          ],
        ).createShader(Rect.fromLTRB(-r * .7, -r * 1.2, r * 1.7, r * .6)),
    );
  }
  final ion = Path()
    ..moveTo(core.dx, core.dy)
    ..quadraticBezierTo(r * .37, -r * .21, r * 1.48, -r * .43);
  canvas.drawPath(
    ion,
    Paint()
      ..color = shade(world.highlight, .35)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(.7, r * .023),
  );
  for (var i = 0; i < 10; i++) {
    final t = (i / 10 + rotation / (math.pi * 2)) % 1;
    final p =
        Offset.lerp(core, Offset(r * 1.42, -r * .82), t)! +
        Offset(math.sin(i * 2.1) * r * .08, math.sin(i * 2.6) * r * .12);
    canvas.drawCircle(
      p,
      r * (.012 + (i % 3) * .005),
      Paint()..color = shade(world.highlight, math.sin(t * math.pi) * .52),
    );
  }
  canvas.drawCircle(
    core,
    r * .44,
    Paint()
      ..shader = RadialGradient(
        colors: [shade(world.highlight, .24), shade(world.highlight, 0)],
      ).createShader(Rect.fromCircle(center: core, radius: r * .44)),
  );
  _drawRock(canvas, core, r * .29, world, opacity, variant + 17);
  canvas.drawArc(
    Rect.fromCircle(center: core, radius: r * .31),
    -.95,
    1.9,
    false,
    Paint()
      ..color = shade(world.highlight, .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .025,
  );
  canvas.restore();
}

void _drawRock(
  Canvas canvas,
  Offset center,
  double r,
  VoyageWorld world,
  double opacity,
  int shape,
) {
  Color shade(Color color, double alpha) =>
      color.withValues(alpha: alpha * opacity);
  final points = List.generate(9, (i) {
    final angle = i / 9 * math.pi * 2;
    final size = r * (.78 + .14 * math.sin(i * 2.3 + shape));
    return center +
        Offset(math.cos(angle) * size, math.sin(angle) * size * .83);
  });
  final path = Path()..addPolygon(points, true);
  canvas.drawPath(
    path,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.65, -.65),
        radius: 1.3,
        colors: [
          shade(world.highlight, 1),
          shade(world.bodyColor, 1),
          shade(world.shadow, 1),
        ],
        stops: const [0, .5, 1],
      ).createShader(Rect.fromCircle(center: center, radius: r)),
  );
  final ridge = center + Offset(-r * .13, -r * .12);
  for (final i in [0, 2, 5]) {
    final facet = Path()
      ..moveTo(ridge.dx, ridge.dy)
      ..lineTo(points[i].dx, points[i].dy)
      ..lineTo(points[(i + 1) % 9].dx, points[(i + 1) % 9].dy)
      ..close();
    canvas.drawPath(
      facet,
      Paint()..color = shade(i == 5 ? world.highlight : world.shadow, .18),
    );
  }
  canvas.drawOval(
    Rect.fromCenter(
      center: center + Offset(r * .12, r * .07),
      width: r * .31,
      height: r * .21,
    ),
    Paint()..color = shade(world.shadow, .32),
  );
  final rim = Path()
    ..moveTo(points[4].dx, points[4].dy)
    ..lineTo(points[5].dx, points[5].dy)
    ..lineTo(points[6].dx, points[6].dy)
    ..lineTo(points[7].dx, points[7].dy);
  canvas.drawPath(
    rim,
    Paint()
      ..color = shade(world.highlight, .38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.5, r * .026),
  );
}

void _drawAsteroidField(
  Canvas canvas,
  double r,
  VoyageWorld world,
  double opacity,
  double rotation,
) {
  canvas.save();
  canvas.rotate(world.tilt);
  final variant = world.surfaceVariant % 5;
  final orbit = Rect.fromCenter(
    center: Offset.zero,
    width: r * 2.7,
    height: r * 1.17,
  );
  canvas.drawOval(
    orbit,
    Paint()
      ..color = world.accent.withValues(alpha: .12 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.5, r * .009),
  );
  for (var i = 0; i < 15; i++) {
    final angle = i / 15 * math.pi * 2 + variant * .52 + rotation;
    final spread = .82 + (i % 3) * .13;
    final center = Offset(
      math.cos(angle) * r * spread,
      math.sin(angle) * r * .49 * spread,
    );
    final size = r * (i % 5 == 0 ? .27 : .065 + i % 3 * .032);
    _drawRock(
      canvas,
      center,
      size,
      world,
      opacity * (i < 7 ? .7 : 1),
      i + variant * 13,
    );
  }
  // An asymmetric central body gives each field a readable centre of gravity.
  _drawRock(
    canvas,
    Offset(-r * .18, r * .04),
    r * (.48 - variant * .025),
    world,
    opacity,
    variant * 11 + 3,
  );
  _drawRock(
    canvas,
    Offset(r * .4, -r * .2),
    r * .22,
    world,
    opacity,
    variant + 21,
  );
  canvas.restore();
}

class _GalaxyArt {
  const _GalaxyArt(this.ribbons, this.clusters);
  final List<({Path path, double alpha})> ribbons;
  final List<({Offset point, double radius, double alpha, bool glow})> clusters;
}

// Five small unit-coordinate silhouettes are cached once. Animation transforms
// those paths; it never reconstructs a feathered arm for each frame or size.
final _galaxyArt = <int, _GalaxyArt>{};

_GalaxyArt _createGalaxyArt(int variant) {
  final arms = [2, 3, 2, 4, 3][variant];
  final ribbons = <({Path path, double alpha})>[];
  final clusters = <({Offset point, double radius, double alpha, bool glow})>[];
  for (var arm = 0; arm < arms; arm++) {
    Offset centre(double t) {
      final distance = .045 + t * 1.27;
      final angle = arm / arms * math.pi * 2 + t * 4.6;
      return Offset(math.cos(angle), math.sin(angle)) * distance;
    }

    Offset normal(double t) {
      final tangent = centre(t + .001) - centre(t - .001);
      return Offset(-tangent.dy, tangent.dx) / tangent.distance;
    }

    double width(double t) =>
        .105 *
        math.pow(math.sin(t * math.pi), .7) *
        (1 + math.sin(t * 17 + arm * 2.8) * .18);
    final samples = List.generate(73, (i) {
      final t = i / 72;
      return (point: centre(t), edge: normal(t) * width(t));
    });
    for (var layer = 0; layer < 16; layer++) {
      final spread = 2.4 * (1 - layer / 16);
      final left = <Offset>[], right = <Offset>[];
      for (final sample in samples) {
        left.add(sample.point + sample.edge * spread);
        right.add(sample.point - sample.edge * spread);
      }
      ribbons.add((
        path: Path()..addPolygon([...left, ...right.reversed], true),
        alpha: .009 + layer * .0012,
      ));
    }
    for (var i = 0; i < 62; i++) {
      final t = (i + .5) / 62;
      final scatter = math.sin(i * 4.37 + arm * 1.7);
      clusters.add((
        point: centre(t) + normal(t) * width(t) * scatter * 1.45,
        radius: i % 13 == 0 ? .015 : .0045 + i % 3 * .002,
        alpha: (.14 + (i % 5) * .045) * math.sin(t * math.pi),
        glow: i % 13 == 0,
      ));
    }
  }
  return _GalaxyArt(ribbons, clusters);
}

void _drawGalaxy(
  Canvas canvas,
  double r,
  VoyageWorld world,
  double opacity,
  double rotation,
) {
  canvas.save();
  canvas.rotate(world.tilt);
  final variant = world.surfaceVariant % 5;
  final flatten = [.55, .74, .45, .65, .85][variant];
  final bounds = Rect.fromCenter(
    center: Offset.zero,
    width: r * 3,
    height: r * 2.3,
  );
  canvas.drawOval(
    bounds,
    Paint()
      ..shader = RadialGradient(
        colors: [
          world.bodyColor.withValues(alpha: .15 * opacity),
          world.bodyColor.withValues(alpha: 0),
        ],
      ).createShader(bounds),
  );
  final art = _galaxyArt.putIfAbsent(variant, () => _createGalaxyArt(variant));
  canvas.save();
  canvas.scale(r, r * flatten);
  canvas.rotate(math.sin(rotation) * .16);
  // Fine opacity steps give broad arms a feathered edge without filters or
  // offscreen layers; each silhouette tapers naturally into diffuse stardust.
  for (final ribbon in art.ribbons) {
    canvas.drawPath(
      ribbon.path,
      Paint()
        ..color = world.bodyColor.withValues(alpha: ribbon.alpha * opacity),
    );
  }
  for (final cluster in art.clusters) {
    final radius = math.max(.35 / r, cluster.radius);
    canvas.drawCircle(
      cluster.point,
      radius,
      Paint()
        ..color = world.highlight.withValues(alpha: cluster.alpha * opacity),
    );
    if (cluster.glow) {
      canvas.drawCircle(
        cluster.point,
        radius * 3.8,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  world.highlight.withValues(
                    alpha: cluster.alpha * .4 * opacity,
                  ),
                  world.highlight.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: cluster.point, radius: radius * 3.8),
              ),
      );
    }
  }
  canvas.restore();
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: r * .85, height: r * .6),
    Paint()
      ..shader = RadialGradient(
        colors: [
          world.highlight.withValues(alpha: .68 * opacity),
          world.highlight.withValues(alpha: .18 * opacity),
          world.highlight.withValues(alpha: 0),
        ],
        stops: const [0, .35, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * .43)),
  );
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: r * .16, height: r * .1),
    Paint()..color = world.highlight.withValues(alpha: .65 * opacity),
  );
  canvas.restore();
}

void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
  final path = Path()
    ..moveTo(center.dx, center.dy - radius)
    ..lineTo(center.dx + radius * .2, center.dy - radius * .15)
    ..lineTo(center.dx + radius * .7, center.dy)
    ..lineTo(center.dx + radius * .16, center.dy + radius * .2)
    ..lineTo(center.dx, center.dy + radius)
    ..lineTo(center.dx - radius * .2, center.dy + radius * .15)
    ..lineTo(center.dx - radius * .7, center.dy)
    ..lineTo(center.dx - radius * .16, center.dy - radius * .2)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}
