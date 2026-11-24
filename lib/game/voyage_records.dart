import 'puzzle.dart';

/// Earned resources only. These are not store products or cash balances.
enum PowerUp {
  timeCell('Time cell', 'Add eight seconds to this launch.', 25),
  routeLens('Route lens', 'Align up to three relays on a legal route.', 25);

  const PowerUp(this.label, this.description, this.cost);
  final String label, description;
  final int cost;
}

/// A route keeps its score and fastest active solving time independently.
/// Untimed legacy rounds can have a score without inventing a time record.
class RouteRecord {
  const RouteRecord({
    required this.level,
    required this.bestScore,
    this.bestTime,
    this.bestScoreAssisted = false,
    this.bestTimeAssisted = false,
    this.clears = 1,
    this.rewardedTier = 0,
    this.layout = 'bounty-v6',
    this.difficulty = Difficulty.balanced,
  });

  final int level, bestScore, clears, rewardedTier;
  final Duration? bestTime;
  final bool bestScoreAssisted, bestTimeAssisted;
  final String layout;
  final Difficulty difficulty;

  Map<String, dynamic> toJson() => {
    'level': level,
    'bestScore': bestScore,
    if (bestTime != null) 'bestTimeMs': bestTime!.inMilliseconds,
    'bestScoreAssisted': bestScoreAssisted,
    'bestTimeAssisted': bestTimeAssisted,
    'clears': clears,
    'rewardedTier': rewardedTier,
    'layout': layout,
    'difficulty': difficulty.name,
  };

  static RouteRecord? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    bool valid(Object? n, int low, int high) =>
        n is int && n >= low && n <= high;
    if (!valid(value['level'], 1, 1000000) ||
        !valid(value['bestScore'], 0, 1000) ||
        !valid(value['clears'], 1, 1000000000) ||
        !valid(value['rewardedTier'], 0, 10)) {
      return null;
    }
    final time = value['bestTimeMs'];
    final layout = value['layout'];
    if (layout is! String ||
        !const [
          'intro-v1',
          'generated-v2',
          'voyage-v3',
          'planet-v4',
          'planet-v5',
          'bounty-v6',
        ].contains(layout)) {
      return null;
    }
    Difficulty? difficulty;
    for (final item in Difficulty.values) {
      if (item.name == value['difficulty']) difficulty = item;
    }
    if (difficulty == null) return null;
    return RouteRecord(
      level: value['level'] as int,
      bestScore: value['bestScore'] as int,
      bestTime: valid(time, 1, 86400000)
          ? Duration(milliseconds: time as int)
          : null,
      bestScoreAssisted: value['bestScoreAssisted'] == true,
      bestTimeAssisted: value['bestTimeAssisted'] == true,
      clears: value['clears'] as int,
      rewardedTier: value['rewardedTier'] as int,
      layout: layout,
      difficulty: difficulty,
    );
  }
}
