import 'support/solve_rendered_puzzle.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/challenge_result.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/voyage_atlas.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets(
    'after briefing is dismissed the app opens directly on a playable puzzle',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(SharedPreferences.getInstance);
      await tester.pumpWidget(
        const GlowpathApp(showBriefings: false, ambientMotion: false),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(PipeTile), findsNWidgets(16));
      expect(find.text('Begin Mission'), findsNothing);
      expect(find.text('Commit to Launch'), findsNothing);
      expect(
        find.byWidgetPredicate((widget) => widget is PipeTile && widget.teach),
        findsNothing,
      );
      await solveRenderedPuzzle(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('completion')), findsOneWidget);
      expect(find.byKey(const ValueKey('next-puzzle')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'turn springs past its angle then settles; undo returns exactly',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final controller = await _launch(tester);
      final tile = find.byKey(const ValueKey('tile-0'));
      double renderedTurns() => tester
          .widget<RotationTransition>(
            find.descendant(
              of: tile,
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value;
      final initial = renderedTurns();
      final bounds = tester.getRect(tile);
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(renderedTurns(), greaterThan(initial + .25));
      expect(renderedTurns(), lessThan(initial + .29));
      expect(tester.getRect(tile), bounds);
      await tester.pumpAndSettle();
      expect(renderedTurns(), closeTo(initial + .25, .0001));
      controller.undo();
      await tester.pumpAndSettle();
      expect(renderedTurns(), closeTo(initial, .0001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('turn and undo update the rendered tile and move count', (
    tester,
  ) async {
    final controller = await _launch(tester);
    final tile = find.byKey(const ValueKey('tile-0'));
    final initialRotation = tester.widget<PipeTile>(tile).tile.rotation;
    expect(controller.canUndo, isFalse);
    await _tap(tester, 'tile-0');
    expect(controller.moves, 1);
    expect(
      tester.widget<PipeTile>(tile).tile.rotation,
      (initialRotation + 1) % 4,
    );
    expect(_visibleText(tester, 'move-count'), contains('1'));
    await _tap(tester, 'undo');
    expect(controller.moves, 0);
    expect(tester.widget<PipeTile>(tile).tile.rotation, initialRotation);
    expect(controller.canUndo, isFalse);
    expect(_visibleText(tester, 'move-count'), contains('0'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'normal motion animates and rapid turns finish at the right angle',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final controller = await _launch(tester);
      final tile = find.byKey(const ValueKey('tile-0'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      double renderedTurns() => tester
          .widget<RotationTransition>(
            find.descendant(
              of: tile,
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value;
      final initialTurns = renderedTurns();
      final initialRotation = controller.puzzle.tiles[0].rotation;

      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(controller.moves, 1);
      expect(renderedTurns(), greaterThan(initialTurns));
      expect(renderedTurns(), lessThan(initialTurns + .25));

      // Interrupt the first turn three times; four clockwise taps return the
      // logical pipe to its start while the animation completes one full turn.
      for (var turn = 1; turn < 4; turn++) {
        await tester.tap(tile);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(controller.moves, 4);
      expect(controller.puzzle.tiles[0].rotation, initialRotation);
      expect(renderedTurns(), closeTo(initialTurns + 1, .0001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mode controls preserve each in-progress route and undo history',
    (tester) async {
      final controller = await _launch(tester);
      final initial = _connections(controller);
      await _tap(tester, 'tile-0');
      final voyage = _connections(controller);
      await _tap(tester, 'mode-journey');
      expect(
        controller.moves,
        1,
        reason: 'Returning to Voyage home preserves the active route.',
      );
      await _tap(tester, 'mode-daily');
      expect(controller.isDaily, isTrue);
      expect(controller.moves, 0);
      expect(_connections(controller), isNot(initial));
      await _tap(tester, 'tile-1');
      final daily = _connections(controller);
      await _tap(tester, 'mode-journey');
      expect(controller.isDaily, isFalse);
      expect(controller.moves, 1);
      expect(_connections(controller), voyage);
      expect(controller.canUndo, isTrue);
      expect(find.byKey(const ValueKey('voyage-home-heading')), findsOneWidget);
      await _tap(tester, 'next-puzzle');
      await _tap(tester, 'undo');
      expect(controller.moves, 0);
      expect(_connections(controller), initial);
      await _tap(tester, 'mode-daily');
      expect(controller.isDaily, isTrue);
      expect(controller.moves, 1);
      expect(_connections(controller), daily);
      expect(controller.canUndo, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hint outlines first and only the second request makes a move', (
    tester,
  ) async {
    final controller = await _launch(tester);
    final initial = _connections(controller);
    final candidate = controller.suggestedHintIndex!;
    await _tap(tester, 'hint');
    expect(controller.assisted, isTrue);
    expect(controller.moves, 0);
    expect(_connections(controller), initial);
    expect(controller.canUndo, isFalse);
    expect(_hintedTiles(tester).map((tile) => tile.index), [candidate]);
    expect(_visibleText(tester, 'hint'), contains('Turn this relay'));
    await _tap(tester, 'hint');
    expect(controller.moves, greaterThan(0));
    expect(_connections(controller), isNot(initial));
    expect(_hintedTiles(tester), isEmpty);
    expect(controller.canUndo, isTrue);
    await _tap(tester, 'undo');
    expect(_connections(controller), initial);
    expect(controller.moves, 0);
    expect(controller.assisted, isTrue, reason: 'Undo cannot erase help used.');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a manual turn after a hint is applied once and clears the outline',
    (tester) async {
      final controller = await _launch(tester);
      final candidate = controller.suggestedHintIndex!;
      final before = controller.puzzle.tiles[candidate].rotation;
      await _tap(tester, 'hint');
      expect(_hintedTiles(tester).map((tile) => tile.index), [candidate]);
      await _tap(tester, 'tile-$candidate');
      expect(controller.moves, 1);
      expect(controller.puzzle.tiles[candidate].rotation, (before + 1) % 4);
      expect(controller.historyLength, 1);
      expect(_hintedTiles(tester), isEmpty);
      expect(_visibleText(tester, 'hint'), contains('Show a hint'));
      expect(controller.assisted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restart cancellation preserves the route and confirmation resets it',
    (tester) async {
      final controller = await _launch(tester);
      final initial = _connections(controller);
      final stars = controller.stars;
      await _tap(tester, 'tile-0');
      await _tap(tester, 'hint');
      final inProgress = _connections(controller);
      await _tap(tester, 'open-settings');
      await _tap(tester, 'restart');
      expect(find.byKey(const ValueKey('restart-dialog')), findsOneWidget);
      expect(controller.moves, 1);
      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('restart-dialog')), findsNothing);
      expect(controller.moves, 1);
      expect(_connections(controller), inProgress);
      expect(controller.assisted, isTrue);
      expect(controller.canUndo, isTrue);

      await _tap(tester, 'open-settings');
      await _tap(tester, 'restart');
      await _tap(tester, 'confirm-restart');
      expect(find.byKey(const ValueKey('restart-dialog')), findsNothing);
      expect(_connections(controller), initial);
      expect(controller.moves, 0);
      expect(controller.assisted, isFalse);
      expect(controller.canUndo, isFalse);
      expect(_hintedTiles(tester), isEmpty);
      expect(controller.stars, stars);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the first planet needs several turns and never preselects a tile',
    (tester) async {
      final controller = await _launch(tester, journeyLevel: 1);
      expect(controller.isPlanetRound, isTrue);
      expect(
        tester
            .widgetList<PipeTile>(find.byType(PipeTile))
            .where((tile) => tile.teach),
        isEmpty,
      );
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<PipeTile>(),
        isNull,
      );
      await solveRenderedPuzzle(tester);
      expect(controller.status.solved, isTrue);
      expect(controller.moves, greaterThanOrEqualTo(3));
      expect(controller.assisted, isFalse);
      expect(controller.stars, 3);
      await tester.pumpAndSettle();
      expect(controller.lastReward!.score, greaterThan(200));
      expect(
        _visibleText(tester, 'move-count'),
        contains('${controller.lastReward!.score} points'),
      );
      expect(controller.lastReward!.elapsedMilliseconds, isNotNull);
      expect(find.byKey(const ValueKey('completion')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('success stays fixed then travels to one Play at $viewport', (
      tester,
    ) async {
      final controller = await _launch(
        tester,
        journeyLevel: 1,
        viewport: viewport,
      );
      final board = find.byKey(const ValueKey('puzzle-board'));
      final before = tester.getRect(board);
      await solveRenderedPuzzle(tester);
      expect(controller.status.solved, isTrue);
      expect(
        tester.getRect(board),
        before,
        reason: 'Completion must not move or resize the board.',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(board), before);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('next-stop-flight')), findsOneWidget);
      expect(find.byKey(const ValueKey('next-puzzle')), findsOneWidget);
      expect(_visibleText(tester, 'next-puzzle'), 'Play');
      expect(
        controller.puzzle.levelNumber,
        1,
        reason: 'The next puzzle clock starts only when Play is pressed.',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Next accepts input while the arrival animation is still running',
    (tester) async {
      final controller = await _launch(tester, journeyLevel: 1);
      await solveRenderedPuzzle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      final progress = tester
          .widget<PuzzleBoard>(find.byType(PuzzleBoard))
          .completionProgress;
      expect(progress, greaterThan(0));
      expect(progress, lessThan(1));
      final next = find.byKey(const ValueKey('next-puzzle'));
      expect(next, findsOneWidget);
      await tester.ensureVisible(next);
      await tester.pump();
      expect(next.hitTestable(), findsOneWidget);
      expect(
        tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).completionProgress,
        lessThan(1),
      );
      await tester.tap(next);
      await tester.pump();
      expect(controller.puzzle.levelNumber, 2);
      expect(controller.moves, 0);
      expect(controller.status.solved, isFalse);
      expect(controller.stars, 3);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in ['open-help', 'open-settings']) {
    testWidgets('$entry opens and Escape returns to the same puzzle', (
      tester,
    ) async {
      final controller = await _launch(tester);
      await _tap(tester, 'tile-0');
      final before = _connections(controller);
      await _tap(tester, entry);
      expect(_gameRoute(tester).isCurrent, isFalse);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_gameRoute(tester).isCurrent, isTrue);
      expect(controller.moves, 1);
      expect(_connections(controller), before);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('completion exposes the next action and advances once', (
    tester,
  ) async {
    final controller = await _launch(tester);
    final level = controller.puzzle.levelNumber;
    _completeWithHints(controller);
    await tester.pumpAndSettle();
    expect(controller.status.solved, isTrue);
    expect(find.byKey(const ValueKey('next-puzzle')), findsOneWidget);
    final stars = controller.stars;
    await _tap(tester, 'next-puzzle');
    expect(controller.puzzle.levelNumber, level + 1);
    expect(controller.status.solved, isFalse);
    expect(controller.moves, 0);
    expect(controller.assisted, isFalse);
    expect(controller.stars, stars);
    expect(find.byKey(const ValueKey('next-puzzle')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing the daily trio returns to the saved Voyage route', (
    tester,
  ) async {
    final controller = await _launch(tester);
    await _tap(tester, 'tile-0');
    final voyage = _connections(controller);
    await _tap(tester, 'mode-daily');
    for (var route = 0; route < 3; route++) {
      _completeWithHints(controller);
      expect(controller.dailyCompleted.length, route + 1);
      expect(controller.lastReward!.earnedStars, 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('next-puzzle')), findsNothing);
      if (route < 2) {
        expect(controller.dailyIndex, route + 1);
        expect(controller.status.solved, isFalse);
      }
    }
    final result = tester.widget<ChallengeResult>(find.byType(ChallengeResult));
    expect(result.starsEarned, 9);
    expect(result.medalEarned, isTrue);
    expect(result.hasNewChallenge, isFalse);
    final coins = controller.coinBalance;
    await _tap(tester, 'challenge-return-voyage');
    expect(controller.isDaily, isFalse);
    expect(controller.moves, 1);
    expect(_connections(controller), voyage);
    expect(controller.status.solved, isFalse);
    expect(controller.stars, 9);
    expect(controller.coinBalance, coins);
    expect(controller.dailyMedals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Map returns to the existing Voyage home and Play resumes edits',
    (tester) async {
      final controller = await _launch(tester);
      await _tap(tester, 'tile-0');
      await _tap(tester, 'tile-1');
      final voyage = _connections(controller);
      final level = controller.puzzle.levelNumber;
      await _tap(tester, 'open-atlas');
      expect(find.byType(VoyageAtlas), findsNothing);
      expect(_gameRoute(tester).isCurrent, isTrue);
      expect(find.byType(PuzzleBoard), findsNothing);
      expect(find.byKey(const ValueKey('next-stop-flight')), findsOneWidget);
      expect(find.byKey(const ValueKey('voyage-home-heading')), findsOneWidget);
      expect(find.byKey(const ValueKey('next-stop-summary')), findsNothing);
      expect(find.byKey(const ValueKey('shared-navigation')), findsOneWidget);
      expect(find.byKey(const ValueKey('voyage-route-log')), findsOneWidget);
      await _tap(tester, 'next-puzzle');
      expect(find.byType(PuzzleBoard), findsOneWidget);
      expect(controller.puzzle.levelNumber, level);
      expect(controller.moves, 2);
      expect(_connections(controller), voyage);
      expect(controller.canUndo, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [GameMode.daily, GameMode.weekly]) {
    testWidgets('$mode Map restores Voyage home and parks the challenge', (
      tester,
    ) async {
      final controller = await _launch(tester);
      await _tap(tester, 'tile-0');
      final voyage = _connections(controller);
      controller.setMode(mode);
      await tester.pumpAndSettle();
      await _tap(tester, 'tile-2');
      final challenge = _connections(controller);
      await _tap(tester, 'open-atlas');
      expect(find.byType(VoyageAtlas), findsNothing);
      expect(_gameRoute(tester).isCurrent, isTrue);
      expect(controller.mode, GameMode.voyage);
      expect(find.byKey(const ValueKey('voyage-home-heading')), findsOneWidget);
      expect(find.byKey(const ValueKey('next-stop-flight')), findsOneWidget);
      expect(controller.moves, 1);
      expect(_connections(controller), voyage);
      await _tap(tester, 'next-puzzle');
      expect(controller.moves, 1);
      expect(_connections(controller), voyage);
      expect(find.byType(PuzzleBoard), findsOneWidget);
      await _tap(tester, 'mode-${mode.name}');
      expect(controller.mode, mode);
      expect(controller.moves, 1);
      expect(_connections(controller), challenge);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Voyage home route log replays history and restores the frontier',
    (tester) async {
      final controller = await _launch(tester, journeyLevel: 8);
      await _tap(tester, 'tile-0');
      final voyage = _connections(controller);
      await _tap(tester, 'open-atlas');
      await _tap(tester, 'voyage-route-log');
      expect(_gameRoute(tester).isCurrent, isFalse);
      expect(find.byType(VoyageAtlas), findsNothing);
      await _tap(tester, 'replay-route-1');
      expect(_gameRoute(tester).isCurrent, isTrue);
      expect(controller.isReplaying, isTrue);
      expect(controller.puzzle.levelNumber, 1);
      expect(find.byType(PuzzleBoard), findsOneWidget);
      await _tap(tester, 'open-atlas');
      await _tap(tester, 'voyage-resume-frontier');
      expect(controller.isReplaying, isFalse);
      expect(controller.puzzle.levelNumber, 8);
      expect(controller.moves, 1);
      expect(_connections(controller), voyage);
      expect(find.byKey(const ValueKey('voyage-home-heading')), findsOneWidget);
      await _tap(tester, 'next-puzzle');
      expect(find.byType(PuzzleBoard), findsOneWidget);
      expect(controller.moves, 1);
      expect(_connections(controller), voyage);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Tab reaches a tile and keyboard activation turns it once', (
    tester,
  ) async {
    final controller = await _launch(tester);
    var reachedTile = false;
    for (var step = 0; step < 40; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focusedTile = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<PipeTile>();
      if (focusedTile?.index == 0) {
        reachedTile = true;
        break;
      }
    }
    expect(
      reachedTile,
      isTrue,
      reason: 'The board must be keyboard reachable.',
    );
    final before = controller.puzzle.tiles[0].rotation;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.moves, 1);
    expect(controller.puzzle.tiles[0].rotation, (before + 1) % 4);
    expect(tester.takeException(), isNull);
  });
}

Future<GameController> _launch(
  WidgetTester tester, {
  int journeyLevel = 8,
  Size viewport = const Size(390, 844),
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'journeyLevel': journeyLevel});
  final controller = (await tester.runAsync(() async {
    final preferences = await SharedPreferences.getInstance();
    final value = GameController(
      preferences: preferences,
      now: () => DateTime.utc(2026, 11, 22, 12),
      snapshotWriter: (_) async => true,
    );
    await value.load();
    await value.flush();
    return value;
  }))!;
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    GlowpathApp(
      showBriefings: false,
      controller: controller,
      ambientMotion: false,
    ),
  );
  await tester.pumpAndSettle();
  expect(controller.ready, isTrue);
  return controller;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

String _visibleText(WidgetTester tester, String key) {
  final target = find.byKey(ValueKey(key));
  return tester
      .widgetList<Text>(
        find.descendant(
          of: target,
          matching: find.byType(Text),
          matchRoot: true,
        ),
      )
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .join(' ');
}

List<int> _connections(GameController controller) =>
    controller.puzzle.tiles.map((tile) => tile.connections).toList();

Iterable<PipeTile> _hintedTiles(WidgetTester tester) => tester
    .widgetList<PipeTile>(find.byType(PipeTile))
    .where((tile) => tile.hinted);

ModalRoute<dynamic> _gameRoute(WidgetTester tester) => ModalRoute.of(
  tester.element(find.byType(GameScreen, skipOffstage: false)),
)!;

void _completeWithHints(GameController controller) {
  for (var hint = 0; hint < 25 && !controller.status.solved; hint++) {
    expect(controller.hint(), isTrue);
  }
  expect(controller.status.solved, isTrue);
}
