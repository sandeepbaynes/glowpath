import 'dart:math' as math;

/// Fifteen routes per destination. Geometry and obstacle counts are fixed for
/// the planet; its three five-route legs tighten only the launch window.
class VoyageProgression extends PlanetV4Progression {
  VoyageProgression.forLevel(super.value) : super.forLevel();
  static const levelsPerPlanet = PlanetV4Progression.levelsPerPlanet;
  static int dailyLevel(int index) => PlanetV4Progression.dailyLevel(index);
  static int weeklyLevel(int index) => PlanetV4Progression.weeklyLevel(index);
  @override
  int get size => planetIndex <= 2 ? 4 : 5;
  @override
  int get minimumRouteLength => size == 4 ? 11 : 19;
  @override
  bool get hasTwins => planetIndex >= 2;
  @override
  String get stageName => planetIndex == 2 ? 'Twin orbits' : super.stageName;
}

/// Frozen profile for reconstructing already saved planet-v4 rounds.
class PlanetV4Progression {
  PlanetV4Progression.forLevel(int value) : level = math.max(1, value);
  static const levelsPerPlanet = 15;
  static int dailyLevel(int index) => 31 + index * 60;
  static int weeklyLevel(int index) => 61 + index * 30;
  final int level;
  int get planetIndex => (level - 1) ~/ levelsPerPlanet + 1;
  int get levelInPlanet => (level - 1) % levelsPerPlanet + 1;
  int get bandIndex => (levelInPlanet - 1) ~/ 5;
  int get size => planetIndex == 1
      ? 3
      : planetIndex == 2
      ? 4
      : 5;
  int get launchSeconds => 30 - bandIndex * 3;
  int get baseScrambles => planetIndex == 1
      ? 8
      : planetIndex == 2
      ? 7
      : math.min(16, 9 + planetIndex ~/ 5);
  int get minimumRouteLength => size == 3
      ? 9
      : size == 4
      ? 12
      : 19;
  int get lockedRelays => planetIndex < 2
      ? 0
      : planetIndex < 6
      ? 1
      : 2;
  int get oneWayRelays => planetIndex < 3
      ? 0
      : planetIndex < 12
      ? 1
      : 2;
  bool get hasTwins => planetIndex >= 4;
  bool get hasBridges => planetIndex >= 5;
  bool get hasCrossways => planetIndex >= 6;
  bool get hasWormholes => planetIndex >= 7;
  bool get hasBlackHoles => planetIndex >= 8;
  bool get hasWhiteHoles => planetIndex >= 9;
  bool get hasTriplets => planetIndex >= 10;
  bool get hasGravityForks => planetIndex >= 11;
  bool get hasWeapons => planetIndex >= 12;
  bool get hasShields => planetIndex >= 13;
  bool get hasGravityLanes => planetIndex >= 14;
  String get stageName => switch (planetIndex) {
    1 => 'Launch academy',
    2 => 'Fixed orbit',
    3 => 'One-way frontier',
    4 => 'Twin signals',
    5 => 'Orbital bridges',
    6 => 'Braided crossings',
    7 => 'Wormhole passage',
    8 => 'Black-hole pull',
    9 => 'White-hole push',
    10 => 'Triple resonance',
    11 => 'Gravity junctions',
    12 => 'Defense network',
    13 => 'Shield corridor',
    14 => 'Tidal crossings',
    _ => 'Deep-space expedition',
  };
  String get challengeLabel => '$size × $size · leg ${bandIndex + 1} of 3';
}

// Kept byte-for-byte in behavior for saved voyage-v3 rounds.
class LegacyVoyageProgression {
  LegacyVoyageProgression.forLevel(int value) : level = math.max(1, value);

  final int level;

  int get size => level <= 5
      ? 3
      : level <= 15
      ? 4
      : 5;
  String get stageName => level <= 5
      ? 'Launch academy'
      : level <= 15
      ? 'Orbital routes'
      : level < 20
      ? 'Deep-space charting'
      : 'Directional flight';

  int get baseScrambles => level <= 5
      ? level
      : level <= 15
      ? 3 + (level - 6) ~/ 2
      : math.min(19, 5 + (level - 16) ~/ 3);

  int get minimumRouteLength => level <= 5
      ? math.min(8, 4 + level)
      : level <= 15
      ? math.min(14, 8 + (level - 6) ~/ 2)
      : math.min(23, 12 + (level - 16) ~/ 4);

  int get lockedRelays => level < 10
      ? 0
      : level < 14
      ? 1
      : level < 30
      ? 2
      : 3;

  int get oneWayRelays => level < 20
      ? 0
      : level < 25
      ? 1
      : level < 35
      ? 2
      : level < 50
      ? 3
      : 4;

  /// Balanced pace. Entering a larger board grants breathing room; the
  /// following routes shorten its window gradually, never below 30 seconds.
  int get launchSeconds => level <= 5
      ? 60 - (level - 1) * 4
      : level <= 15
      ? 56 - ((level - 6) ~/ 2) * 3
      : math.max(35, 55 - ((level - 16) ~/ 5) * 3);

  String get challengeLabel => oneWayRelays > 0
      ? 'Follow the arrows'
      : lockedRelays > 0
      ? 'Plan around fixed relays'
      : '$size × $size routes';
}
