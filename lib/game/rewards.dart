/// Modes are persisted by name; the original isDaily flag remains readable.
enum GameMode { voyage, daily, weekly }

/// These colors are used by the rendered rocket trail, not just a collection
/// label. Stars are earned through new route clears; replays cannot farm them.
enum ShipTrail {
  starlight('Starlight', 0, 0xFFF4C873),
  ember('Ember', 15, 0xFFFF9E64),
  aurora('Aurora', 45, 0xFF79DCCC),
  ion('Ion', 90, 0xFFB9A0FF),
  solar('Solar', 180, 0xFFFFECAF);

  const ShipTrail(this.label, this.requiredStars, this.colorValue);
  final String label;
  final int requiredStars, colorValue;
}

class Achievement {
  const Achievement(this.id, this.label, this.description);
  final String id, label, description;
}

const achievementCatalog = <Achievement>[
  Achievement('first_signal', 'First signal', 'Complete your first route.'),
  Achievement('navigator_5', 'Planet finder', 'Complete 5 Voyage routes.'),
  Achievement('navigator_25', 'Galaxy navigator', 'Complete 25 Voyage routes.'),
  Achievement(
    'navigator_100',
    'Deep-space explorer',
    'Complete 100 Voyage routes.',
  ),
  Achievement(
    'efficient_200',
    'Precision pilot',
    'Earn 200 points without hints.',
  ),
  Achievement(
    'daily_trio',
    'Three-star day',
    'Complete all 3 routes in one daily trio.',
  ),
  Achievement(
    'daily_7',
    'Seven bright days',
    'Complete daily trios on 7 different days.',
  ),
  Achievement(
    'weekly_expedition',
    'Expedition complete',
    'Complete all 5 weekly routes.',
  ),
  Achievement(
    'weekly_4',
    'Seasoned voyager',
    'Complete 4 different weekly expeditions.',
  ),
  Achievement(
    'first_cargo',
    'Precious cargo',
    'Deliver your first optional discovery.',
  ),
  Achievement('cargo_5', 'Cabinet of wonders', 'Collect five discoveries.'),
  Achievement(
    'rare_cargo',
    'Window watcher',
    'Deliver a rare dawn or evening discovery.',
  ),
];

/// A result attached to the solved round, so a resumed destination can explain
/// its earned rewards without granting or claiming them a second time.
class CompletionReward {
  const CompletionReward({
    required this.earnedStars,
    this.newAchievements = const [],
    this.newTrails = const [],
    this.dailyMedal = false,
    this.weeklyMedal = false,
    this.score,
    this.elapsedMilliseconds,
    this.coinsEarned = 0,
    this.cargoId,
    this.newPersonalBest = false,
  });

  final int earnedStars;
  final List<String> newAchievements;
  final List<ShipTrail> newTrails;
  final bool dailyMedal, weeklyMedal;
  final int? score, elapsedMilliseconds;
  final int coinsEarned;
  final String? cargoId;
  final bool newPersonalBest;

  Map<String, dynamic> toJson() => {
    'earnedStars': earnedStars,
    'newAchievements': newAchievements,
    'newTrails': newTrails.map((trail) => trail.name).toList(),
    'dailyMedal': dailyMedal,
    'weeklyMedal': weeklyMedal,
    if (score != null) 'score': score,
    if (elapsedMilliseconds != null) 'elapsedMilliseconds': elapsedMilliseconds,
    'coinsEarned': coinsEarned,
    if (cargoId != null) 'cargoId': cargoId,
    'newPersonalBest': newPersonalBest,
  };

  static CompletionReward? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final stars = value['earnedStars'];
    if (stars is! int || stars < 0 || stars > 3) return null;
    final ids = value['newAchievements'];
    final trails = value['newTrails'];
    return CompletionReward(
      earnedStars: stars,
      newAchievements: List.unmodifiable([
        for (final achievement in achievementCatalog)
          if (ids is List && ids.contains(achievement.id)) achievement.id,
      ]),
      newTrails: List.unmodifiable([
        for (final trail in ShipTrail.values)
          if (trails is List && trails.contains(trail.name)) trail,
      ]),
      dailyMedal: value['dailyMedal'] == true,
      weeklyMedal: value['weeklyMedal'] == true,
      score:
          value['score'] is int && value['score'] >= 0 && value['score'] <= 1000
          ? value['score'] as int
          : null,
      elapsedMilliseconds:
          value['elapsedMilliseconds'] is int &&
              value['elapsedMilliseconds'] > 0 &&
              value['elapsedMilliseconds'] <= 86400000
          ? value['elapsedMilliseconds'] as int
          : null,
      coinsEarned:
          value['coinsEarned'] is int &&
              value['coinsEarned'] >= 0 &&
              value['coinsEarned'] <= 100
          ? value['coinsEarned'] as int
          : 0,
      cargoId:
          value['cargoId'] is String &&
              (value['cargoId'] as String).length <= 40
          ? value['cargoId'] as String
          : null,
      newPersonalBest: value['newPersonalBest'] == true,
    );
  }
}
