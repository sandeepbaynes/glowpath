import 'support/solve_rendered_puzzle.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'full-device travel stays draggable behind HUD and does not consume Play',
    (tester) async {
      final flight = await _launch(tester);
      await solveRenderedPuzzle(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 350));
      final scene = find.byKey(const ValueKey('next-stop-flight'));
      VoyageDepthPainter painter() =>
          tester.widget<CustomPaint>(scene).painter! as VoyageDepthPainter;
      expect(tester.getRect(scene), const Rect.fromLTWH(0, 0, 390, 844));
      expect(
        painter().approach,
        inExclusiveRange(0, .3),
        reason: 'The onward flight takes 2.6 seconds, rather than jumping to its end.',
      );
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(const Offset(190, 380));
      await drag.moveBy(const Offset(0, 180));
      await tester.pump();
      expect(
        painter().cameraExcursion,
        greaterThan(0),
        reason:
            'Floating HUD must leave the universe responsive to direct touch.',
      );
      expect(flight.game.puzzle.levelNumber, 1);
      expect(flight.game.stars, 3);
      await drag.up();
      await tester.pumpAndSettle();
      expect(painter().cameraExcursion, 0);
      await flight.advance(tester, 120);
      await _tap(tester, 'next-puzzle');
      expect(flight.game.puzzle.levelNumber, 2);
      expect(flight.instrument(tester).remaining.inSeconds, 30);
      expect(flight.game.stars, 3);
    },
  );

  testWidgets('automatic clock, automatic travel, then exactly one Play', (
    tester,
  ) async {
    final flight = await _launch(tester);
    expect(flight.instrument(tester).remaining.inSeconds, 30);
    expect(find.text('Begin Mission'), findsNothing);
    expect(find.text('Commit to Launch'), findsNothing);
    await flight.advance(tester, 13);
    expect(flight.instrument(tester).remaining.inSeconds, 17);
    await solveRenderedPuzzle(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next-stop-flight')), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(flight.game.stars, 3);
    // Waiting at the next stop must never consume the next launch window.
    await flight.advance(tester, 120);
    await _tap(tester, 'next-puzzle');
    expect(flight.game.puzzle.levelNumber, 2);
    expect(flight.instrument(tester).remaining.inSeconds, 30);
    expect(flight.game.stars, 3);
    expect(
      find.byType(PipeTile),
      findsNWidgets(flight.game.puzzle.tiles.length),
    );
    await flight.advance(tester, 1);
    expect(flight.instrument(tester).remaining.inSeconds, 29);
  });

  testWidgets('deadline rejects a late turn and Retry keeps the edited plan', (
    tester,
  ) async {
    final flight = await _launch(tester, level: 8);
    final budget = flight.instrument(tester).total.inSeconds;
    expect(budget, 27);
    await _tap(tester, 'tile-0');
    final edited = flight.game.puzzle.tiles.map((t) => t.rotation).toList();
    final moves = flight.game.moves;
    // Cross the deadline before the periodic display update: input itself
    // must reconcile time so a late tap cannot win a race with the timer.
    flight.now += Duration(seconds: budget);
    await tester.tap(find.byKey(const ValueKey('tile-1')));
    await tester.pumpAndSettle();
    expect(flight.game.moves, moves);
    expect(flight.instrument(tester).expired, isTrue);
    expect(find.text('Signal lost'), findsOneWidget);
    expect(flight.game.stars, 0);
    await _tap(tester, 'retry-flight');
    expect(flight.instrument(tester).remaining.inSeconds, budget);
    expect(flight.instrument(tester).expired, isFalse);
    expect(
      flight.game.puzzle.tiles.map((t) => t.rotation),
      orderedEquals(edited),
    );
    expect(flight.game.moves, moves);
    await flight.advance(tester, 1);
    expect(flight.instrument(tester).remaining.inSeconds, budget - 1);
  });

  testWidgets('help, nested restart dialog and background pause active time', (
    tester,
  ) async {
    final flight = await _launch(tester, level: 8);
    await flight.advance(tester, 7);
    const left = 20;
    await _tap(tester, 'open-help');
    await flight.advance(tester, 200);
    await _tap(tester, 'close-sheet');
    expect(flight.instrument(tester).remaining.inSeconds, left);
    await _tap(tester, 'tile-0');
    await _tap(tester, 'open-settings');
    await _tap(tester, 'restart');
    await flight.advance(tester, 200);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(flight.instrument(tester).remaining.inSeconds, left);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await flight.advance(tester, 1000);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(flight.instrument(tester).remaining.inSeconds, left);
    await flight.advance(tester, 1);
    expect(flight.instrument(tester).remaining.inSeconds, left - 1);
  });

  testWidgets(
    'timeout covers the app with one Retry and preserves the edited route',
    (tester) async {
      final flight = await _launch(tester, level: 8);
      await _tap(tester, 'tile-0');
      final edited = flight.game.puzzle.tiles
          .map((tile) => tile.rotation)
          .toList();
      await flight.advance(tester, 27);
      expect(flight.instrument(tester).expired, isTrue);
      expect(
        tester.getRect(find.byKey(const ValueKey('flight-failure-cover'))),
        const Rect.fromLTWH(0, 0, 390, 844),
      );
      for (final key in [
        'open-settings',
        'open-help',
        'mode-daily',
        'hint',
        'tile-0',
      ]) {
        expect(find.byKey(ValueKey(key)).hitTestable(), findsNothing);
      }
      expect(find.text('Signal lost'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('retry-flight')).hitTestable(),
        findsNothing,
        reason: 'The intact flight and breakup play before Retry appears.',
      );
      await tester.pump(const Duration(milliseconds: 4800));
      expect(
        find.byKey(const ValueKey('retry-flight')).hitTestable(),
        findsNothing,
        reason: 'The first invisible fade frame must not accept a tap.',
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        find.byKey(const ValueKey('retry-flight')).hitTestable(),
        findsOneWidget,
      );
      await _tap(tester, 'retry-flight');
      expect(find.byKey(const ValueKey('flight-failure-cover')), findsNothing);
      expect(flight.game.moves, 1);
      expect(
        flight.game.puzzle.tiles.map((tile) => tile.rotation),
        orderedEquals(edited),
      );
      expect(flight.instrument(tester).remaining.inSeconds, 27);
      expect(flight.instrument(tester).expired, isFalse);
    },
  );
}

class _Flight {
  _Flight(this.game);
  final GameController game;
  Duration now = Duration.zero;
  LaunchCountdown instrument(WidgetTester tester) =>
      tester.widget(find.byType(LaunchCountdown));
  Future<void> advance(WidgetTester tester, int seconds) async {
    now += Duration(seconds: seconds);
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<_Flight> _launch(WidgetTester tester, {int level = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'journeyLevel': level});
  final game = (await tester.runAsync(() async {
    final game = GameController(
      preferences: await SharedPreferences.getInstance(),
      snapshotWriter: (_) async => true,
    );
    await game.load();
    return game;
  }))!;
  final flight = _Flight(game);
  addTearDown(game.dispose);
  await tester.pumpWidget(
    GlowpathApp(
      showBriefings: false,
      controller: game,
      ambientMotion: false,
      clockNow: () => flight.now,
    ),
  );
  await tester.pumpAndSettle();
  return flight;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
