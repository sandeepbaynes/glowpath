import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a new clear earns once, persists its receipt and unlocks a usable trail',
    () async {
      final preferences = await _preferences({'journeyLevel': 5, 'stars': 12});
      final game = await _load(preferences);
      expect(game.nextTrail, ShipTrail.ember);
      _solve(game);
      expect(game.stars, 15);
      expect(game.lastReward!.earnedStars, 3);
      expect(game.lastReward!.newTrails, [ShipTrail.ember]);
      expect(game.lastReward!.newAchievements, contains('navigator_5'));
      expect(game.equippedTrail, ShipTrail.ember);
      expect(game.equipTrail(ShipTrail.solar), isFalse);
      expect(game.equipTrail(ShipTrail.starlight), isTrue);
      await game.flush();
      final resumed = await _load(preferences);
      expect(resumed.stars, 15);
      expect(resumed.equippedTrail, ShipTrail.starlight);
      expect(resumed.lastReward!.newTrails, [ShipTrail.ember]);
      expect(
        resumed.earnedAchievementIds,
        containsAll(['first_signal', 'navigator_5']),
      );
      expect(resumed.requestHint(), isFalse);
      resumed.setMode(GameMode.daily);
      resumed.setMode(GameMode.voyage);
      expect(resumed.stars, 15);
      expect(resumed.status.solved, isTrue);
      expect(resumed.nextPuzzle(), isTrue);
      expect(resumed.lastReward, isNull);
    },
  );

  test(
    'daily tiers award a trio medal once and replays cannot farm stars',
    () async {
      final game = await _load(await _preferences());
      expect(game.setDaily(true), isTrue);
      for (var index = 0; index < 3; index++) {
        expect(game.puzzle.levelNumber, [31, 91, 151][index]);
        _solve(game);
        expect(game.lastReward!.earnedStars, 3);
        expect(game.lastReward!.dailyMedal, index == 2);
        expect(game.nextPuzzle(), isTrue);
      }
      expect(game.stars, 9);
      expect(game.dailyMedals, 1);
      expect(game.earnedAchievementIds, contains('daily_trio'));
      _solve(game);
      expect(game.stars, 9);
      expect(game.lastReward!.earnedStars, 0);
      expect(game.lastReward!.dailyMedal, isFalse);
      expect(game.dailyMedals, 1);
      expect(game.weeklyMedals, 0);
    },
  );

  test(
    'weekly expedition has five fixed tiers and one permanent medal',
    () async {
      final preferences = await _preferences();
      final game = await _load(preferences);
      game.setMode(GameMode.weekly);
      expect(game.weeklyDate, '2026-11-16');
      for (var index = 0; index < 5; index++) {
        expect(game.weeklyIndex, index);
        expect(game.puzzle.levelNumber, [61, 91, 121, 151, 181][index]);
        _solve(game);
        expect(game.lastReward!.weeklyMedal, index == 4);
        if (index < 4) game.nextPuzzle();
      }
      expect(game.stars, 15);
      expect(game.weeklyCompleted, {0, 1, 2, 3, 4});
      expect(game.weeklyMedals, 1);
      expect(game.earnedAchievementIds, contains('weekly_expedition'));
      await game.flush();
      final resumed = await _load(preferences);
      expect(resumed.mode, GameMode.weekly);
      expect(resumed.status.solved, isTrue);
      expect(resumed.weeklyMedals, 1);
      expect(resumed.stars, 15);
      resumed.nextPuzzle();
      _solve(resumed);
      expect(resumed.lastReward!.earnedStars, 0);
      expect(resumed.lastReward!.weeklyMedal, isFalse);
      expect(resumed.stars, 15);
    },
  );

  test(
    'all three parked routes retain edits and weekly rollover waits for Next',
    () async {
      var now = DateTime.utc(2026, 11, 22, 23, 59);
      final preferences = await _preferences({'journeyLevel': 8});
      final game = await _load(preferences, now: () => now);
      game.rotate(0);
      final voyage = _rotations(game);
      game.setDaily(true);
      game.rotate(1);
      final daily = _rotations(game);
      game.setMode(GameMode.weekly);
      final weeklyIndex = game.puzzle.tiles.indexWhere(
        (tile) => !tile.isLocked,
      );
      game.rotate(weeklyIndex);
      final weekly = _rotations(game);
      final seed = game.puzzle.seed;
      game.setMode(GameMode.voyage);
      now = now.add(const Duration(minutes: 2));
      await game.flush();
      final resumed = await _load(preferences, now: () => now);
      expect(_rotations(resumed), voyage);
      expect(resumed.moves, 1);
      resumed.setDaily(true);
      expect(_rotations(resumed), daily);
      expect(resumed.dailyDate, '2026-11-22');
      resumed.setMode(GameMode.weekly);
      expect(_rotations(resumed), weekly);
      expect(resumed.puzzle.seed, seed);
      expect(resumed.weeklyDate, '2026-11-16');
      expect(resumed.canUndo, isTrue);
      _solve(resumed);
      expect(resumed.weeklyCompleted, {0});
      resumed.nextPuzzle();
      expect(resumed.weeklyDate, '2026-11-23');
      expect(resumed.weeklyIndex, 0);
      expect(resumed.weeklyCompleted, isEmpty);
      expect(resumed.puzzle.seed, seed + 700);
      expect(resumed.stars, 3);
    },
  );

  test('weekly seeds follow UTC Monday and ignore personal pace', () async {
    final now = DateTime.parse('2026-11-23T01:00:00+02:00');
    final a = await _load(await _preferences(), now: () => now);
    final b = await _load(await _preferences(), now: () => now);
    a.setDifficulty(Difficulty.gentle);
    b.setDifficulty(Difficulty.bright);
    a.setWeekly(true);
    b.setWeekly(true);
    expect(a.weeklyDate, '2026-11-16');
    expect(a.puzzle.seed, b.puzzle.seed);
    expect(_rotations(a), _rotations(b));
    expect(a.roundDifficulty, Difficulty.balanced);
    final old = a.puzzle;
    a.setDifficulty(Difficulty.bright);
    expect(identical(a.puzzle, old), isTrue);
  });

  test('claim history prevents farming when the local date returns to an older set', () async {
    var now = DateTime.utc(2026, 11, 22);
    final game = await _load(await _preferences(), now: () => now);
    game.setDaily(true);
    _solve(game);
    now = now.add(const Duration(days: 1));
    game.nextPuzzle();
    _solve(game);
    expect(game.stars, 6);
    now = now.subtract(const Duration(days: 1));
    game.nextPuzzle();
    _solve(game);
    expect(game.lastReward!.earnedStars, 0);
    expect(game.stars, 6);
  });

  test('locked relay input is rejected and hint planning respects one-way orientation', () async {
    final game = await _load(await _preferences({'journeyLevel': 31}));
    final lock = game.puzzle.tiles.indexWhere((tile) => tile.isLocked);
    expect(lock, greaterThanOrEqualTo(0));
    final initial = _rotations(game);
    expect(game.rotate(lock), isFalse);
    expect(game.moves, 0);
    expect(_rotations(game), initial);
    expect(game.puzzle.tiles.any((tile) => tile.isOneWay), isTrue);
    _solve(game);
    expect(game.status.solved, isTrue);
    expect(game.stars, 3);
  });

  test('legacy generated board restores exactly then advances into progressive layout', () async {
    const level = 14;
    const difficulty = Difficulty.balanced;
    final initial = Puzzle.generate(
      seed: 731 + level * 97 + difficulty.index * 1907,
      levelNumber: level,
      difficulty: difficulty,
    );
    final rotations = initial.tiles.map((tile) => tile.rotation).toList();
    rotations[0] = (rotations[0] + 1) % 4;
    final preferences = await _preferences({
      GameController.storageKey: jsonEncode({
        'schemaVersion': 1,
        'generatorVersion': puzzleGeneratorVersion,
        'journeyLevel': level,
        'stars': 12,
        'best': 180,
        'isDaily': false,
        'difficulty': difficulty.name,
        'dailyDate': '2026-11-22',
        'dailyIndex': 0,
        'dailyCompleted': [],
        'round': {
          'layout': 'generated-v2',
          'difficulty': difficulty.name,
          'level': level,
          'seed': initial.seed,
          'rotations': rotations,
          'moves': 1,
          'recorded': false,
          'assisted': false,
          'history': [],
        },
      }),
    });
    final game = await _load(preferences);
    expect(game.puzzle.size, 5);
    expect(game.isProgressionRound, isFalse);
    expect(_rotations(game), rotations);
    expect(game.moves, 1);
    _solve(game);
    game.nextPuzzle();
    expect(game.puzzle.levelNumber, 15);
    expect(game.puzzle.size, 4);
    expect(game.roundLayout, 'bounty-v6');
    expect(game.isProgressionRound, isTrue);
  });

  test(
    'legacy evidence unlocks only supported achievements and trail choices',
    () async {
      final game = await _load(
        await _preferences({
          'journeyLevel': 101,
          'stars': 180,
          'best': 200,
          'dailyDate': '2026-11-22',
          'dailyCompleted': ['0', '1', '2'],
        }),
      );
      expect(
        game.earnedAchievementIds,
        containsAll([
          'first_signal',
          'navigator_5',
          'navigator_25',
          'navigator_100',
          'efficient_200',
          'daily_trio',
        ]),
      );
      expect(game.earnedAchievementIds, isNot(contains('daily_7')));
      expect(game.earnedAchievementIds, isNot(contains('weekly_expedition')));
      expect(game.dailyMedals, 1);
      expect(game.weeklyMedals, 0);
      expect(game.unlockedTrails, ShipTrail.values);
      expect(game.equippedTrail, ShipTrail.solar);
      expect(game.lastReward, isNull);
    },
  );

  test(
    'distinct completed sets build permanent daily and weekly achievements',
    () async {
      var now = DateTime.utc(2026, 11, 22, 12);
      final preferences = await _preferences();
      final game = await _load(preferences, now: () => now);
      game.setDaily(true);
      for (var day = 0; day < 7; day++) {
        for (var index = 0; index < 3; index++) {
          _solve(game);
          if (index < 2) game.nextPuzzle();
        }
        if (day < 6) {
          now = now.add(const Duration(days: 1));
          game.nextPuzzle();
        }
      }
      expect(game.dailyMedals, 7);
      expect(game.lastReward!.newAchievements, contains('daily_7'));
      game.setWeekly(true);
      for (var week = 0; week < 4; week++) {
        for (var index = 0; index < 5; index++) {
          _solve(game);
          if (index < 4) game.nextPuzzle();
        }
        if (week < 3) {
          now = now.add(const Duration(days: 7));
          game.nextPuzzle();
        }
      }
      expect(game.weeklyMedals, 4);
      expect(game.lastReward!.newAchievements, contains('weekly_4'));
      expect(game.stars, 123);
      await game.flush();
      final resumed = await _load(preferences, now: () => now);
      expect(resumed.dailyMedals, 7);
      expect(resumed.weeklyMedals, 4);
      expect(resumed.stars, 123);
      expect(
        resumed.earnedAchievementIds,
        containsAll(['daily_7', 'weekly_4']),
      );
    },
  );

  test(
    'claim histories stay bounded without resetting lifetime medal totals',
    () async {
      String date(DateTime value) => value.toIso8601String().split('T').first;
      final days = List.generate(
        210,
        (index) => date(DateTime.utc(2025, 1, 1).add(Duration(days: index))),
      );
      final weeks = List.generate(
        120,
        (index) =>
            date(DateTime.utc(2023, 1, 2).add(Duration(days: index * 7))),
      );
      final preferences = await _preferences({
        GameController.storageKey: jsonEncode({
          'schemaVersion': 1,
          'generatorVersion': puzzleGeneratorVersion,
          'rewards': {
            'dailyClaims': {for (final day in days) day: 7},
            'weeklyClaims': {for (final week in weeks) week: 31},
            'dailyMedalDates': days,
            'weeklyMedalDates': weeks,
            'dailyMedals': 240,
            'weeklyMedals': 160,
          },
        }),
      });
      final game = await _load(preferences);
      await game.flush();
      final saved = jsonDecode(
        preferences.getString(GameController.storageKey)!,
      );
      final rewards = saved['rewards'] as Map<String, dynamic>;
      expect((rewards['dailyClaims'] as Map).length, 180);
      expect((rewards['dailyMedalDates'] as List).length, 180);
      expect((rewards['weeklyClaims'] as Map).length, 104);
      expect((rewards['weeklyMedalDates'] as List).length, 104);
      expect(rewards['dailyClaimFloor'], days[29]);
      expect(rewards['weeklyClaimFloor'], weeks[15]);
      expect(game.dailyMedals, 240);
      expect(game.weeklyMedals, 160);
      expect(game.earnedAchievementIds, containsAll(['daily_7', 'weekly_4']));
    },
  );

  for (final mode in [GameMode.daily, GameMode.weekly]) {
    test(
      'a completed old ${mode.name} set exposes and starts the new period after reload',
      () async {
        var now = DateTime.utc(2026, 11, 22, 23, 59);
        final preferences = await _preferences();
        final game = await _load(preferences, now: () => now);
        game.setMode(mode);
        final count = mode == GameMode.daily ? 3 : 5;
        for (var index = 0; index < count; index++) {
          _solve(game);
          if (index < count - 1) game.nextPuzzle();
        }
        expect(game.hasNewChallenge, isFalse);
        await game.flush();
        now = now.add(const Duration(minutes: 2));
        final resumed = await _load(preferences, now: () => now);
        expect(resumed.mode, mode);
        expect(resumed.status.solved, isTrue);
        expect(resumed.hasNewChallenge, isTrue);
        expect(resumed.nextChallengeIndex, 0);
        expect(resumed.nextChallengeLevel, mode == GameMode.daily ? 31 : 61);
        expect(resumed.stars, count * 3);
        expect(resumed.nextPuzzle(), isTrue);
        expect(resumed.mode, mode);
        expect(resumed.hasNewChallenge, isFalse);
        expect(resumed.status.solved, isFalse);
        expect(
          mode == GameMode.daily ? resumed.dailyDate : resumed.weeklyDate,
          '2026-11-23',
        );
        expect(
          mode == GameMode.daily
              ? resumed.dailyCompleted
              : resumed.weeklyCompleted,
          isEmpty,
        );
        expect(resumed.stars, count * 3);
      },
    );

    test(
      'a new ${mode.name} period never discards an unfinished old route',
      () async {
        var now = DateTime.utc(2026, 11, 22, 23, 59);
        final game = await _load(await _preferences(), now: () => now);
        game.setMode(mode);
        final index = game.puzzle.tiles.indexWhere((tile) => !tile.isLocked);
        game.rotate(index);
        final rotations = _rotations(game);
        final seed = game.puzzle.seed;
        now = now.add(const Duration(minutes: 2));
        expect(game.hasNewChallenge, isTrue);
        expect(game.nextPuzzle(), isFalse);
        expect(game.puzzle.seed, seed);
        expect(_rotations(game), rotations);
        expect(game.moves, 1);
        _solve(game);
        expect(game.nextPuzzle(), isTrue);
        expect(game.hasNewChallenge, isFalse);
        expect(game.puzzle.levelNumber, mode == GameMode.daily ? 31 : 61);
      },
    );
  }
}

Future<SharedPreferences> _preferences([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<GameController> _load(
  SharedPreferences preferences, {
  DateTime Function()? now,
}) async {
  final game = GameController(
    preferences: preferences,
    now: now ?? () => DateTime.utc(2026, 11, 22, 12),
  );
  addTearDown(game.dispose);
  await game.load();
  return game;
}

void _solve(GameController game) {
  for (var turns = 0; turns < 60 && !game.status.solved; turns++) {
    expect(game.hint(), isTrue);
  }
  expect(game.status.solved, isTrue);
}

List<int> _rotations(GameController game) =>
    game.puzzle.tiles.map((tile) => tile.rotation).toList();
