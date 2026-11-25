import 'support/solve_rendered_puzzle.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/challenge_result.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/reward_progress.dart';
import 'package:glowpath/ui/rewards_panel.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _savedSnapshots = <GameController, String>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(_savedSnapshots.clear);
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets(
    'a played win immediately shows earned rewards and the permanent star bank',
    (tester) async {
      final game = await _launch(tester, journeyLevel: 1);
      expect(_text(tester, 'star-bank'), contains('0'));
      await solveRenderedPuzzle(tester);
      await tester.pumpAndSettle();
      final receipt = tester.widget<CompletionRewardBadge>(
        find.byType(CompletionRewardBadge),
      );
      expect(receipt.reward.earnedStars, 3);
      expect(
        receipt.reward.newAchievements,
        containsAll(['first_signal', 'efficient_200']),
      );
      final progress = tester.widget<RewardProgress>(
        find.byKey(const ValueKey('open-rewards')),
      );
      expect(progress.stars, 3);
      expect(progress.nextTrail, ShipTrail.ember);
      expect(find.textContaining('3 stars'), findsOneWidget);
      expect(
        find.textContaining('${receipt.reward.coinsEarned} coins'),
        findsOneWidget,
      );
      expect(game.coinBalance, receipt.reward.coinsEarned);
      await _tap(tester, 'next-puzzle');
      expect(_text(tester, 'star-bank'), contains('3'));
      expect(game.stars, 3);
      expect(game.puzzle.levelNumber, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'equipping an earned trail changes the voyage, board and countdown rendering',
    (tester) async {
      final game = await _launch(tester, stars: 45);
      expect(game.equippedTrail, ShipTrail.aurora);
      _solve(game);
      await tester.pumpAndSettle();
      await _tap(tester, 'open-rewards');
      expect(find.byType(RewardsPanel), findsOneWidget);
      await _tap(tester, 'trail-ember');
      expect(game.equippedTrail, ShipTrail.ember);
      expect(
        tester.widget<RewardsPanel>(find.byType(RewardsPanel)).equippedTrail,
        ShipTrail.ember,
      );
      await _tap(tester, 'close-sheet');
      final expectedColor = Color(ShipTrail.ember.colorValue);
      expect(
        tester.widget<VoyageExplorer>(find.byType(VoyageExplorer)).trailColor,
        expectedColor,
      );
      await _tap(tester, 'next-puzzle');
      expect(
        tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).trailColor,
        expectedColor,
      );
      expect(
        tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).trailColor,
        expectedColor,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('weekly navigation and reload preserve all three parked routes', (
    tester,
  ) async {
    final game = await _launch(tester);
    await _tap(tester, 'tile-0');
    final voyage = _rotations(game);
    await _tap(tester, 'mode-daily');
    await _tap(tester, 'tile-1');
    final daily = _rotations(game);
    await _tap(tester, 'mode-weekly');
    expect(game.mode, GameMode.weekly);
    final editable = game.puzzle.tiles.indexWhere((tile) => !tile.isLocked);
    await _tap(tester, 'tile-$editable');
    final weekly = _rotations(game);
    await _tap(tester, 'mode-journey');
    expect(_rotations(game), voyage);
    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.setMockInitialValues({
      GameController.storageKey: _savedSnapshots[game]!,
    });
    final resumed = await _loadSaved(tester);
    await _mount(tester, resumed);
    expect(resumed.mode, GameMode.voyage);
    expect(_rotations(resumed), voyage);
    await _tap(tester, 'mode-weekly');
    expect(_rotations(resumed), weekly);
    expect(resumed.moves, 1);
    expect(resumed.canUndo, isTrue);
    await _tap(tester, 'mode-daily');
    expect(_rotations(resumed), daily);
    expect(resumed.moves, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the completed weekly gauntlet shows its medal and returns to saved Voyage',
    (tester) async {
      final game = await _launch(tester, stars: 18);
      await _tap(tester, 'tile-0');
      final voyage = _rotations(game);
      await _tap(tester, 'mode-weekly');
      var earnedCoins = 0;
      for (var route = 0; route < 5; route++) {
        _solve(game);
        expect(game.weeklyCompleted.length, route + 1);
        final reward = game.lastReward!;
        expect(reward.earnedStars, 3);
        expect(reward.weeklyMedal, route == 4);
        earnedCoins += reward.coinsEarned;
        if (route == 4) {
          expect(reward.newAchievements, contains('weekly_expedition'));
        }
        await _finishChallengeStage(tester);
        expect(find.byKey(const ValueKey('next-puzzle')), findsNothing);
        if (route < 4) {
          expect(game.weeklyIndex, route + 1);
          expect(game.status.solved, isFalse);
        }
      }
      final result = tester.widget<ChallengeResult>(
        find.byType(ChallengeResult),
      );
      expect(result.weekly, isTrue);
      expect(result.medalEarned, isTrue);
      expect(result.starsEarned, 15);
      expect(result.coinsEarned, earnedCoins);
      expect(find.textContaining('Gauntlet medal earned'), findsOneWidget);
      await _tap(tester, 'challenge-return-voyage');
      expect(game.mode, GameMode.voyage);
      expect(_rotations(game), voyage);
      expect(game.moves, 1);
      expect(game.weeklyMedals, 1);
      expect(game.stars, 33);
      expect(game.coinBalance, earnedCoins);
      expect(find.byKey(const ValueKey('voyage-home-heading')), findsOneWidget);
      expect(find.byType(PuzzleBoard), findsNothing);
      await _tap(tester, 'next-puzzle');
      expect(find.byType(PuzzleBoard), findsOneWidget);
      expect(_rotations(game), voyage);
      await _tap(tester, 'mode-weekly');
      expect(find.byType(ChallengeResult), findsOneWidget);
      expect(game.weeklyMedals, 1);
      expect(game.stars, 33);
      expect(game.coinBalance, earnedCoins);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final mode in [GameMode.daily, GameMode.weekly]) {
    testWidgets(
      'the result opens a new ${mode.name} set when its period rolls over',
      (tester) async {
        var now = DateTime.utc(2026, 11, 22, 23, 59);
        final game = await _launch(tester, now: () => now);
        await _tap(tester, 'mode-${mode.name}');
        final count = mode == GameMode.daily ? 3 : 5;
        for (var route = 0; route < count; route++) {
          _solve(game);
          await _finishChallengeStage(tester);
        }
        expect(find.byType(ChallengeResult), findsOneWidget);
        expect(game.hasNewChallenge, isFalse);
        final coins = game.coinBalance;
        final medals = mode == GameMode.daily
            ? game.dailyMedals
            : game.weeklyMedals;
        now = now.add(const Duration(minutes: 2));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        expect(game.hasNewChallenge, isTrue);
        expect(
          tester
              .widget<ChallengeResult>(find.byType(ChallengeResult))
              .hasNewChallenge,
          isTrue,
        );
        expect(
          find.text(
            mode == GameMode.daily ? 'Start new sprint' : 'Start new gauntlet',
          ),
          findsOneWidget,
        );
        await _tap(tester, 'challenge-return-voyage');
        expect(game.mode, mode);
        expect(game.status.solved, isFalse);
        expect(game.puzzle.levelNumber, mode == GameMode.daily ? 31 : 61);
        expect(
          mode == GameMode.daily ? game.dailyDate : game.weeklyDate,
          '2026-11-23',
        );
        expect(
          mode == GameMode.daily ? game.dailyCompleted : game.weeklyCompleted,
          isEmpty,
        );
        expect(game.stars, count * 3);
        expect(game.coinBalance, coins);
        expect(
          mode == GameMode.daily ? game.dailyMedals : game.weeklyMedals,
          medals,
        );
        expect(game.challengeRunSummary!.completed, 0);
        expect(game.challengeRunSummary!.totalScore, 0);
        expect(game.challengeRunSummary!.earnedStars, 0);
        expect(find.byType(PuzzleBoard), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final viewport in [const Size(320, 568), const Size(844, 320)]) {
    testWidgets(
      'the real collection sheet fits $viewport with large text and no scrolling',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final game = await _launch(
          tester,
          journeyLevel: 1,
          stars: 18,
          viewport: viewport,
        );
        expect(tester.takeException(), isNull, reason: 'Initial game layout');
        _solve(game);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Completion layout');
        await _tap(tester, 'open-rewards');
        expect(
          tester.takeException(),
          isNull,
          reason: 'Trails collection layout',
        );
        final panel = find.byType(RewardsPanel);
        expect(panel, findsOneWidget);
        final bounds = tester.getRect(panel);
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(viewport.height));
        for (final trail in ShipTrail.values) {
          final target = find.byKey(ValueKey('trail-${trail.name}'));
          expect(target.hitTestable(), findsOneWidget);
          final rect = tester.getRect(target);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
        }
        await _tap(tester, 'collection-medals');
        expect(
          tester.takeException(),
          isNull,
          reason: 'Medal collection layout',
        );
        final next = find.byKey(const ValueKey('medals-next'));
        expect(next.hitTestable(), findsOneWidget);
        expect(tester.getRect(next).bottom, lessThanOrEqualTo(bounds.bottom));
        expect(
          find.descendant(
            of: panel,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            ),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: panel,
            matching: find.byType(SingleChildScrollView),
          ),
          findsNothing,
        );
        await _tap(tester, 'close-sheet');
        expect(panel, findsNothing);
        expect(
          find.byKey(const ValueKey('next-puzzle')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Future<void> _finishChallengeStage(WidgetTester tester) async {
  // The route payoff finishes before its brief auto-chain timer is scheduled.
  // pumpAndSettle alone does not wait for a future timer with no pending frame.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 950));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

Future<GameController> _launch(
  WidgetTester tester, {
  int journeyLevel = 8,
  int stars = 0,
  Size viewport = const Size(390, 844),
  DateTime Function()? now,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'journeyLevel': journeyLevel,
    'stars': stars,
  });
  final game = await _loadSaved(tester, now: now);
  await _mount(tester, game);
  return game;
}

Future<GameController> _loadSaved(
  WidgetTester tester, {
  DateTime Function()? now,
}) async {
  final preferences = (await tester.runAsync(SharedPreferences.getInstance))!;
  late GameController game;
  game = GameController(
    preferences: preferences,
    now: now ?? () => DateTime.utc(2026, 11, 22, 12),
    snapshotWriter: (snapshot) async {
      _savedSnapshots[game] = snapshot;
      return true;
    },
  );
  await game.load();
  await game.flush();
  addTearDown(game.dispose);
  return game;
}

Future<void> _mount(WidgetTester tester, GameController game) async {
  await tester.pumpWidget(
    GlowpathApp(
      showBriefings: false,
      controller: game,
      ambientMotion: false,
      clockNow: () => Duration.zero,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: '$key must be reachable without scrolling.',
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _solve(GameController game) {
  for (var moves = 0; moves < 60 && !game.status.solved; moves++) {
    expect(game.hint(), isTrue);
  }
  expect(game.status.solved, isTrue);
}

List<int> _rotations(GameController game) =>
    game.puzzle.tiles.map((tile) => tile.rotation).toList();

String _text(WidgetTester tester, String key) {
  final target = find.byKey(ValueKey(key));
  final widget = tester.widget(target);
  if (widget is Text) return widget.data ?? '';
  return tester
      .widgetList<Text>(
        find.descendant(of: target, matching: find.byType(Text)),
      )
      .map((text) => text.data ?? '')
      .join(' ');
}
