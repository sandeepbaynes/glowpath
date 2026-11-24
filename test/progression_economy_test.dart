import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'timed replay improves records without repeating clear rewards',
    () async {
      final prefs = await preferences();
      final game = await load(prefs);
      game.updateAttemptTiming(
        const Duration(seconds: 20),
        const Duration(seconds: 30),
      );
      solve(game);
      final first = game.recordForLevel(1)!;
      final earned = game.coinBalance;
      expect(first.bestTime, const Duration(seconds: 20));
      expect(first.bestScore, game.puzzle.scoreForMoves(game.moves) + 267);
      expect(game.lastReward!.coinsEarned, 20 + first.bestScore ~/ 100);
      expect(game.nextPuzzle(), isTrue);
      expect(game.replayLevel(1), isTrue);
      game.updateAttemptTiming(
        const Duration(seconds: 10),
        const Duration(seconds: 30),
      );
      solve(game);
      final improved = game.recordForLevel(1)!;
      expect(improved.bestTime, const Duration(seconds: 10));
      expect(improved.bestScore, greaterThan(first.bestScore));
      expect(game.lastReward!.newPersonalBest, isTrue);
      expect(game.lastReward!.earnedStars, 0);
      expect(
        game.coinBalance - earned,
        improved.rewardedTier - first.rewardedTier,
      );
      expect(game.stars, 3);
      final balance = game.coinBalance;
      await game.flush();
      final restored = await load(prefs);
      expect(restored.isReplaying, isTrue);
      expect(restored.coinBalance, balance);
      expect(restored.recordForLevel(1)!.bestTime, const Duration(seconds: 10));
      expect(restored.nextPuzzle(), isTrue);
      expect(restored.puzzle.levelNumber, 2);
      expect(restored.replayLevel(1), isTrue);
      restored.updateAttemptTiming(
        const Duration(seconds: 12),
        const Duration(seconds: 30),
      );
      solve(restored);
      expect(restored.coinBalance, balance);
      expect(restored.recordForLevel(1)!.bestTime, const Duration(seconds: 10));
      expect(restored.journeyLevel, 2);
    },
  );

  test(
    'replay parks edits and time, including through a challenge and relaunch',
    () async {
      final prefs = await preferences({'journeyLevel': 46, 'stars': 135});
      final game = await load(prefs);
      game.rotate(game.puzzle.tiles.indexWhere((tile) => !tile.isLocked));
      game.updateAttemptTiming(
        const Duration(seconds: 7),
        const Duration(seconds: 30),
      );
      final pending = rotations(game), pendingSeed = game.puzzle.seed;
      expect(game.replayLevel(1), isTrue);
      game.rotate(0);
      game.updateAttemptTiming(
        const Duration(seconds: 4),
        const Duration(seconds: 30),
      );
      final replay = rotations(game);
      game.setMode(GameMode.weekly);
      await game.flush();
      final restored = await load(prefs);
      expect(restored.mode, GameMode.weekly);
      restored.setMode(GameMode.voyage);
      expect(restored.isReplaying, isTrue);
      expect(rotations(restored), replay);
      expect(restored.attemptElapsed, const Duration(seconds: 4));
      expect(restored.returnToFrontier(), isTrue);
      expect(restored.puzzle.levelNumber, 46);
      expect(restored.puzzle.seed, pendingSeed);
      expect(rotations(restored), pending);
      expect(restored.attemptElapsed, const Duration(seconds: 7));
      expect(restored.moves, 1);
      expect(restored.journeyLevel, 46);
      expect(restored.replayLevel(46), isFalse);
      expect(restored.replayLevel(100), isFalse);
      expect(restored.replayLevel(0), isFalse);
    },
  );

  test('replays pin the recorded puzzle layout and difficulty', () async {
    final game = await load(await preferences());
    game.setDifficulty(Difficulty.bright);
    game.updateAttemptTiming(
      const Duration(seconds: 12),
      const Duration(seconds: 27),
    );
    final seed = game.puzzle.seed, initial = rotations(game);
    solve(game);
    game.nextPuzzle();
    game.setDifficulty(Difficulty.gentle);
    expect(game.replayLevel(1), isTrue);
    expect(game.roundDifficulty, Difficulty.bright);
    expect(game.puzzle.seed, seed);
    expect(rotations(game), initial);
    expect(game.roundLayout, game.recordForLevel(1)!.layout);
  });

  test(
    'timeout keeps elapsed effort and cannot manufacture a fast result',
    () async {
      final game = await load(await preferences());
      game.updateAttemptTiming(
        const Duration(seconds: 30),
        const Duration(seconds: 30),
      );
      game.rotate(0);
      final pending = rotations(game);
      expect(game.retryAfterTimeout(), isTrue);
      expect(rotations(game), pending);
      expect(game.attemptElapsed, const Duration(seconds: 30));
      expect(game.attemptExtraTime, const Duration(seconds: 30));
      expect(game.retryAfterTimeout(), isFalse);
      game.updateAttemptTiming(
        const Duration(seconds: 33),
        const Duration(seconds: 30),
      );
      solve(game);
      expect(game.lastReward!.score, lessThanOrEqualTo(200));
      expect(game.recordForLevel(1)!.bestTime, const Duration(seconds: 33));
    },
  );

  test('full restart resets the board and measured attempt together', () async {
    final game = await load(await preferences());
    final initial = rotations(game), revision = game.attemptRevision;
    game.rotate(0);
    game.updateAttemptTiming(
      const Duration(seconds: 30),
      const Duration(seconds: 30),
    );
    game.retryAfterTimeout();
    expect(game.restart(), isTrue);
    expect(rotations(game), initial);
    expect(game.attemptElapsed, Duration.zero);
    expect(game.attemptExtraTime, Duration.zero);
    expect(game.retryCount, 0);
    expect(game.attemptRevision, greaterThan(revision));
  });

  test(
    'launch gauge uses the current retry window and its own time cell',
    () async {
      final prefs = await fundedPreferences(50);
      final game = await load(prefs);
      game.updateAttemptTiming(Duration.zero, const Duration(seconds: 30));
      expect(game.attemptWindowBudget, const Duration(seconds: 30));
      expect(game.buyPowerUp(PowerUp.timeCell), isTrue);
      expect(game.useTimeCell(), isTrue);
      expect(game.attemptWindowBudget, const Duration(seconds: 38));
      game.updateAttemptTiming(
        const Duration(seconds: 38),
        const Duration(seconds: 30),
      );
      expect(game.retryAfterTimeout(), isTrue);
      expect(game.attemptWindowBudget, const Duration(seconds: 30));
      expect(
        game.attemptBudget + game.attemptExtraTime - game.attemptElapsed,
        game.attemptWindowBudget,
      );
      await game.flush();
      final restored = await load(prefs);
      expect(restored.attemptWindowBudget, const Duration(seconds: 30));
      expect(restored.attemptElapsed, const Duration(seconds: 38));

      expect(restored.restart(), isTrue);
      restored.updateAttemptTiming(
        const Duration(seconds: 30),
        const Duration(seconds: 30),
      );
      expect(restored.retryAfterTimeout(), isTrue);
      expect(restored.buyPowerUp(PowerUp.timeCell), isTrue);
      expect(restored.useTimeCell(), isTrue);
      expect(restored.attemptWindowBudget, const Duration(seconds: 38));
      await restored.flush();
      expect(
        (await load(prefs)).attemptWindowBudget,
        const Duration(seconds: 38),
      );
      final snapshot = jsonDecode(
        prefs.getString(GameController.storageKey)!,
      ) as Map<String, dynamic>;
      ((snapshot['round'] as Map)['timing'] as Map).remove('timeCellRetry');
      await prefs.setString(GameController.storageKey, jsonEncode(snapshot));
      expect(
        (await load(prefs)).attemptWindowBudget,
        const Duration(seconds: 38),
      );
    },
  );

  test('timing saves without notifications and cannot run backwards', () async {
    final prefs = await preferences();
    final game = await load(prefs);
    var notifications = 0;
    game.addListener(() => notifications++);
    game.updateAttemptTiming(
      const Duration(milliseconds: 7135),
      const Duration(seconds: 30),
    );
    game.updateAttemptTiming(
      const Duration(seconds: 2),
      const Duration(seconds: 60),
    );
    expect(notifications, 0);
    expect(game.attemptElapsed, const Duration(milliseconds: 7135));
    expect(game.attemptBudget, const Duration(seconds: 30));
    await game.flush();
    final restored = await load(prefs);
    expect(restored.attemptElapsed, const Duration(milliseconds: 7135));
    expect(restored.attemptBudget, const Duration(seconds: 30));
  });

  test(
    'edited untimed legacy boards cannot invent a time bonus or record',
    () async {
      final prefs = await preferences();
      final original = await load(prefs);
      original.rotate(0);
      await original.flush();
      final snapshot = jsonDecode(
        prefs.getString(GameController.storageKey)!,
      ) as Map<String, dynamic>;
      (snapshot['round'] as Map).remove('timing');
      (snapshot['round'] as Map)['layout'] = 'planet-v5';
      snapshot.remove('economy');
      await prefs.setString(GameController.storageKey, jsonEncode(snapshot));
      final restored = await load(prefs);
      expect(restored.roundLayout, 'planet-v5');
      restored.updateAttemptTiming(
        const Duration(seconds: 1),
        const Duration(seconds: 30),
      );
      solve(restored);
      expect(restored.lastReward!.score, lessThanOrEqualTo(200));
      expect(restored.lastReward!.elapsedMilliseconds, isNull);
      expect(restored.recordForLevel(1)!.bestTime, isNull);
      expect(restored.recordForLevel(1)!.layout, 'planet-v5');
    },
  );

  test(
    'wallet purchases and powers consume exactly once and survive restart',
    () async {
      final prefs = await fundedPreferences(200);
      final game = await load(prefs);
      expect(game.buyHint(), isTrue);
      expect(game.hintCredits, 1);
      expect(game.coinBalance, 190);
      expect(game.consumeHintCredit(), isTrue);
      expect(game.consumeHintCredit(), isFalse);
      expect(game.buyPowerUp(PowerUp.timeCell), isTrue);
      expect(game.buyPowerUp(PowerUp.routeLens), isTrue);
      expect(game.coinBalance, 140);
      game.updateAttemptTiming(
        const Duration(seconds: 5),
        const Duration(seconds: 30),
      );
      expect(game.useTimeCell(), isTrue);
      expect(game.useTimeCell(), isFalse);
      expect(game.attemptExtraTime, const Duration(seconds: 8));
      expect(game.powerUpCount(PowerUp.timeCell), 0);
      final moves = game.moves;
      expect(game.useRouteLens(), isTrue);
      expect(game.moves, greaterThan(moves));
      expect(game.useRouteLens(), isFalse);
      expect(game.assisted, isTrue);
      await game.flush();
      final restored = await load(prefs);
      expect(restored.coinBalance, 140);
      expect(restored.hintCredits, 0);
      expect(restored.attemptExtraTime, const Duration(seconds: 8));
      expect(restored.assisted, isTrue);
    },
  );

  test(
    'paid skip is atomic, gives no clear reward, and cannot skip a replay',
    () async {
      final game = await load(await fundedPreferences(100, level: 2));
      expect(game.buySkip(), isTrue);
      expect(game.coinBalance, 25);
      expect(game.journeyLevel, 3);
      expect(game.stars, 0);
      expect(game.recordForLevel(2), isNull);
      expect(game.buySkip(), isFalse);
      expect(game.coinBalance, 25);
      game.replayLevel(1);
      expect(game.buySkip(), isFalse);
      expect(game.skipCurrentLevel(), isFalse);
      expect(game.journeyLevel, 3);
    },
  );

  test(
    'optional cargo is absent from a successful shortcut, then collected once',
    () async {
      final prefs = await preferences({'journeyLevel': 31});
      final game = await load(prefs);
      expect(game.currentCargo!.kind, CargoKind.moonPearl);
      traceSolution(game, cargo: false);
      expect(game.status.solved, isTrue);
      expect(game.cargoCollection, isEmpty);
      expect(game.lastReward!.cargoId, isNull);
      expect(game.replayLevel(31), isTrue);
      traceSolution(game, cargo: true);
      expect(game.lastReward!.cargoId, CargoKind.moonPearl.name);
      expect(game.cargoCollection[CargoKind.moonPearl], 1);
      expect(game.earnedAchievementIds, contains('first_cargo'));
      final balance = game.coinBalance;
      await game.flush();
      final restored = await load(prefs);
      expect(restored.cargoCollection[CargoKind.moonPearl], 1);
      expect(restored.coinBalance, balance);
      restored.returnToFrontier();
      restored.replayLevel(31);
      traceSolution(restored, cargo: true);
      expect(restored.cargoCollection[CargoKind.moonPearl], 1);
      expect(restored.lastReward!.cargoId, isNull);
      expect(restored.coinBalance, balance);
    },
  );

  test(
    'rare encounter is pinned, claimed once per window, and recurs next day',
    () async {
      var now = DateTime(2026, 11, 23, 7);
      final prefs = await preferences({'journeyLevel': 31});
      final game = await load(prefs, now: () => now);
      expect(game.currentCargo!.kind, CargoKind.dawnPrism);
      now = DateTime(2026, 11, 23, 12);
      await game.flush();
      final restored = await load(prefs, now: () => now);
      expect(restored.currentCargo!.kind, CargoKind.dawnPrism);
      traceSolution(restored, cargo: true);
      expect(restored.cargoCollection[CargoKind.dawnPrism], 1);
      expect(restored.earnedAchievementIds, contains('rare_cargo'));
      now = DateTime(2026, 11, 23, 8);
      restored.replayLevel(31);
      traceSolution(restored, cargo: true);
      expect(restored.cargoCollection[CargoKind.dawnPrism], 1);
      now = DateTime(2026, 11, 24, 8);
      restored.replayLevel(31);
      traceSolution(restored, cargo: true);
      expect(restored.cargoCollection[CargoKind.dawnPrism], 2);
    },
  );

  test(
    'power cargo adds usable inventory without consuming the collection',
    () async {
      final game = await load(await preferences({'journeyLevel': 41}));
      expect(game.currentCargo!.kind, CargoKind.chronoCell);
      traceSolution(game, cargo: true);
      expect(game.cargoCollection[CargoKind.chronoCell], 1);
      expect(game.powerUpCount(PowerUp.timeCell), 1);
      game.nextPuzzle();
      game.updateAttemptTiming(
        const Duration(seconds: 2),
        const Duration(seconds: 30),
      );
      expect(game.useTimeCell(), isTrue);
      expect(game.powerUpCount(PowerUp.timeCell), 0);
      expect(game.cargoCollection[CargoKind.chronoCell], 1);
    },
  );

  test('a claimed daily route cannot farm currency on replay', () async {
    final game = await load(await preferences());
    game.setDaily(true);
    for (var i = 0; i < 3; i++) {
      game.updateAttemptTiming(
        const Duration(seconds: 10),
        const Duration(seconds: 30),
      );
      solve(game);
      game.nextPuzzle();
    }
    final coins = game.coinBalance;
    game.updateAttemptTiming(
      const Duration(seconds: 1),
      const Duration(seconds: 30),
    );
    solve(game);
    expect(game.coinBalance, coins);
    expect(game.lastReward!.coinsEarned, 0);
  });

  test(
    'hint credits and a three-relay lens each save one complete transaction',
    () async {
      final prefs = await fundedPreferences(200, level: 16);
      final writes = <Map<String, dynamic>>[];
      final game = GameController(
        preferences: prefs,
        snapshotWriter: (value) async {
          writes.add(jsonDecode(value) as Map<String, dynamic>);
          return true;
        },
      );
      await game.load();
      game.buyHint();
      await game.flush();
      writes.clear();
      final beforeHint = game.moves;
      expect(game.useHintCredit(), isTrue);
      await game.flush();
      expect(writes, hasLength(1));
      expect((writes.single['economy'] as Map)['hintCredits'], 0);
      expect((writes.single['round'] as Map)['moves'], greaterThan(beforeHint));

      game.buyPowerUp(PowerUp.routeLens);
      await game.flush();
      writes.clear();
      final beforeLens = rotations(game), beforeHistory = game.historyLength;
      final beforeMoves = game.moves;
      expect(game.useRouteLens(), isTrue);
      await game.flush();
      expect(writes, hasLength(1));
      expect(game.historyLength, beforeHistory + 1);
      expect(game.moves, greaterThan(beforeMoves));
      expect(game.replayActions.length, game.moves);
      expect(
        ((writes.single['economy'] as Map)['powerUps'] as Map)['routeLens'],
        0,
      );
      if (!game.status.solved) {
        expect(game.undo(), isTrue);
        expect(rotations(game), beforeLens);
        expect(game.assisted, isTrue);
        expect(game.powerUpCount(PowerUp.routeLens), 0);
      }
    },
  );

  test(
    'flush preserves the fractional active time after a throttled update',
    () async {
      final prefs = await preferences();
      final game = await load(prefs);
      game.updateAttemptTiming(
        const Duration(milliseconds: 7001),
        const Duration(seconds: 30),
      );
      game.updateAttemptTiming(
        const Duration(milliseconds: 7999),
        const Duration(seconds: 30),
      );
      await game.flush();
      final restored = await load(prefs);
      expect(restored.attemptElapsed, const Duration(milliseconds: 7999));
    },
  );

  test('disposal preserves its final fractional clock sample', () async {
    final prefs = await preferences();
    final game = await load(prefs);
    game.updateAttemptTiming(
      const Duration(milliseconds: 7001),
      const Duration(seconds: 30),
    );
    await game.flush();
    game.updateAttemptTiming(
      const Duration(milliseconds: 7999),
      const Duration(seconds: 30),
    );
    game.dispose();
    await game.flush();
    final restored = await load(prefs);
    expect(restored.attemptElapsed, const Duration(milliseconds: 7999));
  });
}

Future<SharedPreferences> preferences([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<GameController> load(
  SharedPreferences prefs, {
  DateTime Function()? now,
}) async {
  final game = GameController(
    preferences: prefs,
    now: now ?? () => DateTime(2026, 11, 23, 12),
  );
  await game.load();
  return game;
}

Future<SharedPreferences> fundedPreferences(int coins, {int level = 1}) async {
  final prefs = await preferences({'journeyLevel': level});
  final game = await load(prefs);
  await game.flush();
  final data = jsonDecode(
    prefs.getString(GameController.storageKey)!,
  ) as Map<String, dynamic>;
  (data['economy'] as Map)['coins'] = coins;
  await prefs.setString(GameController.storageKey, jsonEncode(data));
  return prefs;
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

void traceSolution(GameController game, {required bool cargo}) {
  final puzzle = game.puzzle;
  final solved = cargo
      ? puzzle.solvedCopy()
      : puzzle.copyWithTiles([
          for (var i = 0; i < puzzle.tiles.length; i++)
            puzzle.tiles[i].withRotation(puzzle.bountyShortcutRotations![i]),
        ]);
  expect(solved.evaluate().solved, isTrue);
  expect(game.beginTrace(), isTrue);
  expect(game.updateTrace(solved.evaluate().route), isTrue);
  expect(game.endTrace(), isTrue);
  expect(game.status.solved, isTrue);
}
