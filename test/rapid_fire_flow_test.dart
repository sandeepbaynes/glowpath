import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/challenge_result.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/voyage_atlas.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final mode in [GameMode.daily, GameMode.weekly]) {
    testWidgets(
      '$mode automatically chains its signals and ends without a planet journey',
      (tester) async {
        final run = await _launch(tester);
        run.game.setMode(mode);
        await tester.pumpAndSettle();
        final budgets = mode == GameMode.daily
            ? [22, 20, 18]
            : [24, 22, 20, 18, 16];
        for (var stage = 0; stage < budgets.length; stage++) {
          expect(_clock(tester).total.inSeconds, budgets[stage]);
          run.now += const Duration(seconds: 5);
          await tester.pump(const Duration(milliseconds: 200));
          await _solve(tester, run.game);
          expect(run.game.status.solved, isTrue);
          expect(find.byKey(const ValueKey('next-puzzle')), findsNothing);
          expect(find.byKey(const ValueKey('next-stop-flight')), findsNothing);
          await tester.pump(const Duration(milliseconds: 950));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump(const Duration(milliseconds: 450));
          if (stage < budgets.length - 1) {
            expect(run.game.status.solved, isFalse);
            expect(
              mode == GameMode.daily
                  ? run.game.dailyIndex
                  : run.game.weeklyIndex,
              stage + 1,
            );
          }
        }
        expect(find.byType(ChallengeResult), findsOneWidget);
        expect(find.byType(PuzzleBoard), findsNothing);
        final result = tester.widget<ChallengeResult>(
          find.byType(ChallengeResult),
        );
        expect(result.points, run.game.challengeRunSummary!.totalScore);
        expect(result.activeElapsed, Duration(seconds: 5 * budgets.length));
        expect(result.cleanStreak, budgets.length);
        expect(result.medalEarned, isTrue);
        expect(find.byKey(const ValueKey('next-stop-flight')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('challenge-return-voyage')));
        await tester.pumpAndSettle();
        expect(run.game.mode, GameMode.voyage);
        expect(run.game.journeyLevel, 31);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await run.game.flush();
        run.game.dispose();
      },
    );
  }

  testWidgets(
    'a challenge timeout restarts its signal instead of carrying an edited route',
    (tester) async {
      final run = await _launch(tester);
      run.game.setMode(GameMode.daily);
      await tester.pumpAndSettle();
      final initial = run.game.puzzle.tiles
          .map((tile) => tile.rotation)
          .toList();
      final action = run.game.puzzle.solutionActions.first;
      await tester.tap(find.byKey(ValueKey('tile-$action')));
      await tester.pump();
      expect(run.game.moves, greaterThan(0));
      run.now += const Duration(seconds: 22);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.byType(ChallengeRetryOverlay), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mode-journey')).hitTestable(),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('retry-flight')));
      await tester.pumpAndSettle();
      expect(run.game.moves, 0);
      expect(run.game.puzzle.tiles.map((tile) => tile.rotation), initial);
      expect(run.game.challengeRunSummary!.retries, 1);
      expect(_clock(tester).remaining.inSeconds, 22);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await run.game.flush();
      run.game.dispose();
    },
  );

  testWidgets(
    'a pending signal stays parked at Voyage home and resumes one handoff',
    (tester) async {
      final run = await _launch(tester);
      run.game.setMode(GameMode.daily);
      await tester.pumpAndSettle();
      await _solve(tester, run.game);
      run.game.setMode(GameMode.voyage);
      await tester.pumpAndSettle();
      expect(run.game.journeyLevel, 31);
      run.game.setMode(GameMode.daily);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('open-atlas')).hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(VoyageAtlas), findsNothing);
      expect(find.byKey(const ValueKey('voyage-home-heading')), findsOneWidget);
      expect(run.game.mode, GameMode.voyage);
      expect(run.game.dailyIndex, 0);
      expect(run.game.status.solved, isFalse);
      run.now += const Duration(minutes: 1);
      await tester.pump(const Duration(seconds: 1));
      expect(run.game.dailyIndex, 0);
      await tester.tap(find.byKey(const ValueKey('mode-daily')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(run.game.dailyIndex, 1);
      expect(run.game.mode, GameMode.daily);
      expect(_clock(tester).remaining.inSeconds, 20);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await run.game.flush();
      run.game.dispose();
    },
  );

  for (final mode in [GameMode.daily, GameMode.weekly]) {
    testWidgets('$mode Map parks active time until that mode resumes', (
      tester,
    ) async {
      final run = await _launch(tester);
      run.now += const Duration(seconds: 4);
      await tester.pump(const Duration(milliseconds: 200));
      final voyage = run.game.puzzle.tiles
          .map((tile) => tile.rotation)
          .toList();
      await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
      await tester.pumpAndSettle();
      final action = run.game.puzzle.solutionActions.first;
      await tester.tap(find.byKey(ValueKey('tile-$action')));
      await tester.pumpAndSettle();
      final challenge = run.game.puzzle.tiles
          .map((tile) => tile.rotation)
          .toList();
      final moves = run.game.moves;
      run.now += const Duration(seconds: 3);
      await tester.pump(const Duration(milliseconds: 200));
      final remaining = _clock(tester).remaining;
      await tester.tap(find.byKey(const ValueKey('open-atlas')));
      await tester.pumpAndSettle();
      expect(run.game.mode, GameMode.voyage);
      expect(run.game.attemptElapsed, const Duration(seconds: 4));
      run.now += const Duration(minutes: 3);
      await tester.pump(const Duration(milliseconds: 250));
      expect(run.game.attemptElapsed, const Duration(seconds: 4));
      expect(find.byType(ChallengeRetryOverlay), findsNothing);
      await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
      await tester.pumpAndSettle();
      expect(run.game.mode, mode);
      expect(run.game.moves, moves);
      expect(run.game.puzzle.tiles.map((tile) => tile.rotation), challenge);
      expect(run.game.attemptElapsed, const Duration(seconds: 3));
      expect(_clock(tester).remaining, remaining);
      await tester.tap(find.byKey(const ValueKey('mode-journey')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('voyage-home-heading')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('next-puzzle')));
      await tester.pumpAndSettle();
      expect(run.game.puzzle.tiles.map((tile) => tile.rotation), voyage);
      expect(run.game.attemptElapsed, const Duration(seconds: 4));
      expect(_clock(tester).remaining.inSeconds, 26);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await run.game.flush();
      run.game.dispose();
    });
  }

  for (final size in [
    const Size(393, 852),
    const Size(1024, 1366),
    const Size(1366, 1024),
  ]) {
    testWidgets(
      'mode switch keeps header timer board and controls aligned on $size',
      (tester) async {
        final run = await _launch(tester, size: size);
        final header = tester.getRect(find.byKey(const ValueKey('open-atlas')));
        final timer = tester.getRect(find.byType(LaunchCountdown));
        final controls = tester.getRect(
          find.byKey(const ValueKey('route-tools')),
        );
        final board = tester.getRect(find.byType(PuzzleBoard));
        for (final mode in [GameMode.daily, GameMode.weekly, GameMode.voyage]) {
          run.game.setMode(mode);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(const ValueKey('open-atlas'))),
            header,
          );
          expect(tester.getRect(find.byType(LaunchCountdown)), timer);
          expect(
            tester.getRect(find.byKey(const ValueKey('route-tools'))),
            controls,
          );
          expect(tester.getRect(find.byType(PuzzleBoard)), board);
          for (final scroll in tester.stateList<ScrollableState>(
            find.byType(Scrollable),
          )) {
            expect(scroll.position.maxScrollExtent, 0);
            expect(scroll.position.minScrollExtent, 0);
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await run.game.flush();
        run.game.dispose();
      },
    );
  }
}

LaunchCountdown _clock(WidgetTester tester) =>
    tester.widget<LaunchCountdown>(find.byType(LaunchCountdown));
Future<void> _solve(WidgetTester tester, GameController game) async {
  final actions = [...game.puzzle.solutionActions];
  for (final action in actions) {
    if (game.status.solved) break;
    await tester.tap(find.byKey(ValueKey('tile-$action')));
    await tester.pump(const Duration(milliseconds: 10));
  }
}

class _Run {
  _Run(this.game);
  final GameController game;
  Duration now = Duration.zero;
}

Future<_Run> _launch(
  WidgetTester tester, {
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'journeyLevel': 31});
  final game = GameController(
    preferences: await SharedPreferences.getInstance(),
    now: () => DateTime.utc(2026, 11, 23, 12),
  );
  await game.load();
  final run = _Run(game);
  await tester.pumpWidget(
    GlowpathApp(
      controller: game,
      ambientMotion: false,
      showBriefings: false,
      clockNow: () => run.now,
    ),
  );
  await tester.pumpAndSettle();
  return run;
}
