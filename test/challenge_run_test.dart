import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in [GameMode.daily, GameMode.weekly]) {
    final expectedBudgets = mode == GameMode.daily
        ? [22, 20, 18]
        : [24, 22, 20, 18, 16];
    final expectedLevels = mode == GameMode.daily
        ? [31, 91, 151]
        : [61, 91, 121, 151, 181];
    test(
      '${mode.name} sprint retains boards and records first clears only',
      () async {
        final fixture = await Fixture.create();
        final game = fixture.game;
        game.setMode(mode);
        var expectedScore = 0;
        var expectedCoins = 0;
        for (var index = 0; index < expectedBudgets.length; index++) {
          expect(game.challengeLaunchBudget.inSeconds, expectedBudgets[index]);
          expect(game.puzzle.levelNumber, expectedLevels[index]);
          expect(game.roundLayout, 'planet-v5');
          expect(game.roundDifficulty, Difficulty.balanced);
          game.updateAttemptTiming(
            const Duration(seconds: 7),
            game.challengeLaunchBudget,
          );
          solve(game);
          expectedScore += game.lastReward!.score!;
          expectedCoins += game.lastReward!.coinsEarned;
          final run = game.challengeRunSummary!;
          expect(run.completed, index + 1);
          expect(run.count, expectedBudgets.length);
          expect(run.totalScore, expectedScore);
          expect(run.cleanStreak, index + 1);
          expect(run.bestStreak, index + 1);
          expect(run.earnedStars, (index + 1) * 3);
          expect(run.coinsEarned, expectedCoins);
          expect(run.stageRecords[index]!.elapsed, const Duration(seconds: 7));
          expect(run.stageRecords[index]!.clean, isTrue);
          expect(run.stageRecords[index]!.assisted, isFalse);
          expect(game.hasVerifiedReplay, isTrue);
          if (index != expectedBudgets.length - 1) game.nextPuzzle();
        }
        expect(game.challengeRunSummary!.isComplete, isTrue);
        final first = game.challengeRunSummary!.toJson();
        final stars = game.stars, coins = game.coinBalance;
        await game.flush();
        final restored = await fixture.reload();
        expect(restored.challengeRunSummary!.toJson(), first);
        for (var index = 0; index < expectedBudgets.length; index++) {
          restored.nextPuzzle();
          restored.updateAttemptTiming(
            const Duration(seconds: 1),
            restored.challengeLaunchBudget,
          );
          if (index == 0) {
            restored.rotate(restored.puzzle.solutionActions.first);
            restored.undo();
            restored.restart();
            restored.updateAttemptTiming(
              const Duration(seconds: 1),
              restored.challengeLaunchBudget,
            );
          }
          solve(restored);
          expect(restored.lastReward!.coinsEarned, 0);
        }
        expect(restored.coinBalance, coins);
        expect(restored.stars, stars);
        expect(restored.challengeRunSummary!.toJson(), first);
      },
    );

    test(
      '${mode.name} timeout resets current board and retains cleared stages',
      () async {
        final fixture = await Fixture.create();
        final game = fixture.game;
        game.setMode(mode);
        game.updateAttemptTiming(
          const Duration(seconds: 5),
          game.challengeLaunchBudget,
        );
        solve(game);
        final stageOne = game.challengeRunSummary!.stageRecords[0]!.toJson();
        final total = game.challengeRunSummary!.totalScore;
        final coins = game.coinBalance, stars = game.stars;
        game.nextPuzzle();
        final original = rotations(game), seed = game.puzzle.seed;
        game.rotate(game.puzzle.solutionActions.first);
        game.updateAttemptTiming(
          game.challengeLaunchBudget,
          game.challengeLaunchBudget,
        );
        expect(game.challengeRunSummary!.cleanStreak, 0);
        expect(game.challengeRunSummary!.retries, 0);
        final revision = game.attemptRevision;
        expect(game.retryAfterTimeout(), isTrue);
        expect(rotations(game), original);
        expect(game.puzzle.seed, seed);
        expect(game.moves, 0);
        expect(game.attemptElapsed, Duration.zero);
        expect(game.attemptExtraTime, Duration.zero);
        expect(game.attemptRevision, greaterThan(revision));
        expect(game.retryCount, 1);
        expect(game.challengeRunSummary!.retries, 1);
        expect(game.challengeRunSummary!.cleanStreak, 0);
        expect(game.challengeRunSummary!.bestStreak, 1);
        expect(game.challengeRunSummary!.totalScore, total);
        expect(game.challengeRunSummary!.stageRecords[0]!.toJson(), stageOne);
        expect(game.coinBalance, coins);
        expect(game.stars, stars);
        expect(game.retryAfterTimeout(), isFalse);
        game.updateAttemptTiming(
          const Duration(seconds: 3),
          game.challengeLaunchBudget,
        );
        game.setMode(GameMode.voyage);
        await game.flush();
        final restored = await fixture.reload();
        restored.setMode(mode);
        expect(restored.challengeRunSummary!.retries, 1);
        expect(restored.attemptElapsed, const Duration(seconds: 3));
        expect(restored.retryCount, 1);
        expect(rotations(restored), original);
        solve(restored);
        expect(restored.challengeRunSummary!.completed, 2);
        expect(restored.challengeRunSummary!.cleanStreak, 0);
        expect(restored.challengeRunSummary!.stageRecords[1]!.clean, isFalse);
        expect(restored.challengeRunSummary!.stageRecords[1]!.retries, 1);
        expect(
          restored.challengeRunSummary!.stageRecords[1]!.elapsed,
          const Duration(seconds: 3),
        );
        expect(
          restored.challengeRunSummary!.totalScore,
          total + restored.lastReward!.score!,
        );
      },
    );

    test(
      '${mode.name} parked stage keeps period then next period resets sprint',
      () async {
        final fixture = await Fixture.create();
        final game = fixture.game;
        game.setMode(mode);
        game.updateAttemptTiming(
          const Duration(seconds: 5),
          game.challengeLaunchBudget,
        );
        solve(game);
        game.nextPuzzle();
        game.rotate(game.puzzle.solutionActions.first);
        game.updateAttemptTiming(
          const Duration(seconds: 4),
          game.challengeLaunchBudget,
        );
        final seed = game.puzzle.seed, pending = rotations(game);
        final period = game.challengeRunSummary!.period;
        game.setMode(GameMode.voyage);
        fixture.now = fixture.now.add(
          Duration(days: mode == GameMode.daily ? 1 : 7),
        );
        await game.flush();
        final restored = await fixture.reload();
        restored.setMode(mode);
        expect(restored.hasNewChallenge, isTrue);
        expect(restored.challengeRunSummary!.period, period);
        expect(restored.challengeRunSummary!.completed, 1);
        expect(restored.puzzle.seed, seed);
        expect(rotations(restored), pending);
        expect(restored.attemptElapsed, const Duration(seconds: 4));
        solve(restored);
        expect(restored.challengeRunSummary!.completed, 2);
        expect(restored.nextPuzzle(), isTrue);
        expect(restored.challengeRunSummary!.period, isNot(period));
        expect(restored.challengeRunSummary!.completed, 0);
        expect(restored.challengeRunSummary!.totalScore, 0);
        expect(restored.challengeRunSummary!.cleanStreak, 0);
        expect(restored.challengeRunSummary!.retries, 0);
        expect(restored.challengeLaunchBudget.inSeconds, expectedBudgets.first);
        expect(restored.puzzle.levelNumber, expectedLevels.first);
      },
    );
  }

  test(
    'active legacy budget remains intact; new stages use sprint profiles',
    () async {
      final fixture = await Fixture.create();
      final game = fixture.game;
      game.setDaily(true);
      game.updateAttemptTiming(
        const Duration(seconds: 14),
        const Duration(seconds: 30),
      );
      await game.flush();
      final restored = await fixture.reload();
      expect(restored.challengeLaunchBudget, const Duration(seconds: 30));
      expect(restored.attemptElapsed, const Duration(seconds: 14));
      solve(restored);
      restored.nextPuzzle();
      expect(restored.challengeLaunchBudget, const Duration(seconds: 20));
    },
  );

  test(
    'legacy completed challenge stages stay unknown and cannot be paid again',
    () async {
      final fixture = await Fixture.create();
      final game = fixture.game;
      game.setDaily(true);
      for (var index = 0; index < 3; index++) {
        game.updateAttemptTiming(
          const Duration(seconds: 5),
          game.challengeLaunchBudget,
        );
        solve(game);
        if (index < 2) game.nextPuzzle();
      }
      await game.flush();
      final saved = jsonDecode(
        fixture.prefs.getString(GameController.storageKey)!,
      ) as Map<String, dynamic>;
      saved.remove('challengeRuns');
      await fixture.prefs.setString(
        GameController.storageKey,
        jsonEncode(saved),
      );
      final restored = await fixture.reload();
      final before = restored.coinBalance;
      final run = restored.challengeRunSummary!;
      expect(run.completed, 3);
      expect(run.totalScore, 0);
      expect(run.earnedStars, 0);
      expect(run.coinsEarned, 0);
      expect(run.elapsedTotal, Duration.zero);
      expect(
        run.stageRecords.values.every(
          (stage) =>
              stage.score == null &&
              stage.elapsed == null &&
              stage.assisted == null,
        ),
        isTrue,
      );
      restored.nextPuzzle();
      restored.updateAttemptTiming(
        const Duration(seconds: 1),
        restored.challengeLaunchBudget,
      );
      solve(restored);
      expect(restored.challengeRunSummary!.totalScore, 0);
      expect(restored.coinBalance, before);
    },
  );

  test(
    'undo and manual restart break clean streak without multiplying score',
    () async {
      final fixture = await Fixture.create();
      final game = fixture.game;
      game.setDaily(true);
      game.updateAttemptTiming(
        const Duration(seconds: 5),
        game.challengeLaunchBudget,
      );
      solve(game);
      game.nextPuzzle();
      game.rotate(game.puzzle.solutionActions.first);
      expect(game.undo(), isTrue);
      expect(game.challengeRunSummary!.cleanStreak, 0);
      game.updateAttemptTiming(
        const Duration(seconds: 5),
        game.challengeLaunchBudget,
      );
      solve(game);
      expect(game.challengeRunSummary!.stageRecords[1]!.clean, isFalse);
      game.nextPuzzle();
      game.updateAttemptTiming(
        const Duration(seconds: 5),
        game.challengeLaunchBudget,
      );
      expect(game.restart(), isTrue);
      expect(game.retryCount, 1);
      game.updateAttemptTiming(
        const Duration(seconds: 5),
        game.challengeLaunchBudget,
      );
      solve(game);
      final run = game.challengeRunSummary!;
      expect(run.bestStreak, 1);
      expect(run.retries, 1);
      expect(run.stageRecords[2]!.clean, isFalse);
      expect(
        run.totalScore,
        run.stageRecords.values.fold<int>(
          0,
          (sum, stage) => sum + stage.score!,
        ),
      );
    },
  );
}

class Fixture {
  Fixture(this.prefs);
  final SharedPreferences prefs;
  DateTime now = DateTime.utc(2026, 11, 23, 12);
  late GameController game;

  static Future<Fixture> create() async {
    SharedPreferences.setMockInitialValues({});
    final fixture = Fixture(await SharedPreferences.getInstance());
    fixture.game = await fixture.reload();
    return fixture;
  }

  Future<GameController> reload() async {
    final controller = GameController(preferences: prefs, now: () => now);
    await controller.load();
    return controller;
  }
}

List<int> rotations(GameController game) =>
    game.puzzle.tiles.map((tile) => tile.rotation).toList();

void solve(GameController game) {
  for (final action in game.puzzle.solutionActions) {
    if (game.status.solved) break;
    game.rotate(action);
  }
  expect(game.status.solved, isTrue);
}
