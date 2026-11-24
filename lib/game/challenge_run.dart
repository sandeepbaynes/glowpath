import 'dart:math' as math;

import 'rewards.dart';

/// Local sprint profiles. Board seeds and verified move scores stay unchanged.
Duration challengeStageBudget(GameMode mode, int index) {
  final seconds = switch (mode) {
    GameMode.daily => const [22, 20, 18],
    GameMode.weekly => const [24, 22, 20, 18, 16],
    GameMode.voyage => const <int>[],
  };
  if (seconds.isEmpty) return Duration.zero;
  return Duration(seconds: seconds[index.clamp(0, seconds.length - 1)]);
}

/// Only the first period-clear is recorded. Unknown legacy results stay null.
class ChallengeStageRecord {
  const ChallengeStageRecord({
    required this.index,
    this.score,
    this.elapsed,
    this.assisted,
    this.clean = false,
    this.retries = 0,
    this.earnedStars = 0,
    this.coinsEarned = 0,
  });

  final int index, retries, earnedStars, coinsEarned;
  final int? score;
  final Duration? elapsed;
  final bool? assisted;
  final bool clean;

  Map<String, dynamic> toJson() => {
    'index': index,
    if (score != null) 'score': score,
    if (elapsed != null) 'elapsedMs': elapsed!.inMilliseconds,
    if (assisted != null) 'assisted': assisted,
    'clean': clean,
    'retries': retries,
    'earnedStars': earnedStars,
    'coinsEarned': coinsEarned,
  };

  static ChallengeStageRecord? fromJson(Object? value, {required int count}) {
    if (value is! Map<String, dynamic>) return null;
    final index = value['index'], score = value['score'];
    final time = value['elapsedMs'], assisted = value['assisted'];
    if (index is! int || index < 0 || index >= count) return null;
    if (score != null && (score is! int || score < 0 || score > 1000)) {
      return null;
    }
    if (time != null && (time is! int || time <= 0 || time > 86400000)) {
      return null;
    }
    if (assisted != null && assisted is! bool) return null;
    final retries = _counter(value['retries']);
    return ChallengeStageRecord(
      index: index,
      score: score as int?,
      elapsed: time == null ? null : Duration(milliseconds: time as int),
      assisted: assisted as bool?,
      clean:
          value['clean'] == true &&
          score != null &&
          time != null &&
          assisted == false &&
          retries == 0,
      retries: retries,
      earnedStars: _counter(value['earnedStars'], maximum: 3),
      coinsEarned: _counter(value['coinsEarned'], maximum: 30),
    );
  }
}

/// First-clear local sprint results, separate from the verified leaderboard.
/// A clean streak is feedback, not a coin or score multiplier.
class ChallengeRunSummary {
  ChallengeRunSummary({
    required this.mode,
    required this.period,
    Map<int, ChallengeStageRecord> stageRecords = const {},
    this.cleanStreak = 0,
    this.bestStreak = 0,
    this.retries = 0,
  }) : stageRecords = Map.unmodifiable(stageRecords);

  final GameMode mode;
  final String period;
  final Map<int, ChallengeStageRecord> stageRecords;
  final int cleanStreak, bestStreak, retries;
  int get count => mode == GameMode.daily ? 3 : 5;
  int get completed => stageRecords.length;
  bool get isComplete => completed == count;
  int get totalScore =>
      stageRecords.values.fold(0, (sum, stage) => sum + (stage.score ?? 0));
  int get localTotalScore => totalScore;
  int get earnedStars =>
      stageRecords.values.fold(0, (sum, stage) => sum + stage.earnedStars);
  int get coinsEarned =>
      stageRecords.values.fold(0, (sum, stage) => sum + stage.coinsEarned);
  Duration get elapsedTotal => stageRecords.values.fold(
    Duration.zero,
    (sum, stage) => sum + (stage.elapsed ?? Duration.zero),
  );
  DateTime get resetAtUtc =>
      DateTime.parse('${period}T00:00:00Z')
          .add(Duration(days: mode == GameMode.daily ? 1 : 7));

  ChallengeRunSummary breakStreak({bool retry = false}) => ChallengeRunSummary(
    mode: mode,
    period: period,
    stageRecords: stageRecords,
    cleanStreak: 0,
    bestStreak: bestStreak,
    retries: retries + (retry ? 1 : 0),
  );

  ChallengeRunSummary record(ChallengeStageRecord stage) {
    if (stageRecords.containsKey(stage.index)) return this;
    final streak = stage.clean ? cleanStreak + 1 : 0;
    return ChallengeRunSummary(
      mode: mode,
      period: period,
      stageRecords: {...stageRecords, stage.index: stage},
      cleanStreak: streak,
      bestStreak: math.max(bestStreak, streak),
      retries: retries,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'period': period,
    'stages': stageRecords.values.map((stage) => stage.toJson()).toList(),
    'cleanStreak': cleanStreak,
    'bestStreak': bestStreak,
    'retries': retries,
  };

  static ChallengeRunSummary? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final mode = switch (value['mode']) {
      'daily' => GameMode.daily,
      'weekly' => GameMode.weekly,
      _ => null,
    };
    final period = value['period'];
    if (mode == null || period is! String) return null;
    final date = DateTime.tryParse('${period}T00:00:00Z');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(period) ||
        date == null ||
        date.toIso8601String().split('T').first != period ||
        (mode == GameMode.weekly && date.weekday != DateTime.monday)) {
      return null;
    }
    final count = mode == GameMode.daily ? 3 : 5;
    final stages = <int, ChallengeStageRecord>{};
    final stored = value['stages'];
    if (stored is List) {
      for (final entry in stored.take(count)) {
        final stage = ChallengeStageRecord.fromJson(entry, count: count);
        if (stage != null) stages.putIfAbsent(stage.index, () => stage);
      }
    }
    final best = _counter(value['bestStreak'], maximum: count);
    return ChallengeRunSummary(
      mode: mode,
      period: period,
      stageRecords: stages,
      cleanStreak: _counter(value['cleanStreak'], maximum: best),
      bestStreak: best,
      retries: _counter(value['retries']),
    );
  }
}

int _counter(Object? value, {int maximum = 1000000}) =>
    value is int && value >= 0 && value <= maximum ? value : 0;
