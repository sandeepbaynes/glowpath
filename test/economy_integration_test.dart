import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'replaying from a cargo arrival returns directly to unfinished frontier',
    (tester) async {
      final game = await prepare(tester, 31);
      final route = game.puzzle.solvedCopy().evaluate().route;
      game.updateAttemptTiming(
        const Duration(seconds: 10),
        const Duration(seconds: 30),
      );
      game.beginTrace();
      expect(game.updateTrace(route), isTrue);
      expect(game.endTrace(), isTrue);
      expect(game.lastReward!.cargoId, isNotNull);
      final coins = game.coinBalance;
      final cargo = Map<CargoKind, int>.of(game.cargoCollection);
      await tester.pumpWidget(
        GlowpathApp(
          controller: game,
          showBriefings: false,
          ambientMotion: false,
          clockNow: () => Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('next-stop-summary')), findsOneWidget);
      expect(game.replayLevel(1), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleBoard), findsOneWidget);
      expect(game.returnToFrontier(), isTrue);
      await tester.pumpAndSettle();
      expect(game.puzzle.levelNumber, 32);
      expect(game.status.solved, isFalse);
      expect(game.lastReward, isNull);
      expect(find.byType(PuzzleBoard), findsOneWidget);
      expect(game.coinBalance, coins);
      expect(game.cargoCollection, cargo);
      expect(find.byKey(const ValueKey('next-stop-summary')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'panels and background do not enter score time; retry keeps active effort',
    (tester) async {
      final game = await prepare(tester, 8);
      var now = Duration.zero;
      await tester.pumpWidget(
        GlowpathApp(
          controller: game,
          showBriefings: false,
          ambientMotion: false,
          clockNow: () => now,
        ),
      );
      await tester.pumpAndSettle();
      now += const Duration(seconds: 7);
      await tester.pump(const Duration(milliseconds: 220));
      expect(game.attemptElapsed, const Duration(seconds: 7));
      await tester.tap(find.byKey(const ValueKey('open-help')));
      await tester.pumpAndSettle();
      now += const Duration(minutes: 3);
      await tester.pump(const Duration(milliseconds: 220));
      expect(game.attemptElapsed, const Duration(seconds: 7));
      await tester.tap(find.byKey(const ValueKey('close-sheet')));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now += const Duration(minutes: 5);
      await tester.pump(const Duration(milliseconds: 220));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(game.attemptElapsed, const Duration(seconds: 7));
      now += const Duration(seconds: 20);
      await tester.pumpAndSettle();
      expect(game.attemptElapsed, const Duration(seconds: 27));
      expect(find.text('Signal lost'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('retry-flight')));
      await tester.pumpAndSettle();
      expect(game.attemptElapsed, const Duration(seconds: 27));
      expect(game.retryCount, 1);
      expect(
        tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).remaining,
        const Duration(seconds: 27),
      );
      now += const Duration(seconds: 3);
      await tester.pump(const Duration(milliseconds: 220));
      expect(game.attemptElapsed, const Duration(seconds: 30));
      expect(game.timedScore, lessThanOrEqualTo(200));
      expect(tester.takeException(), isNull);
    },
  );
}

Future<GameController> prepare(WidgetTester tester, int level) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'journeyLevel': level});
  final game = (await tester.runAsync(() async {
    final game = GameController(
      preferences: await SharedPreferences.getInstance(),
      snapshotWriter: (_) async => true,
      now: () => DateTime(2026, 11, 23, 12),
    );
    await game.load();
    return game;
  }))!;
  addTearDown(game.dispose);
  return game;
}
