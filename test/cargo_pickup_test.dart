import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/launch_clock.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/cargo_pickup.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('extra fuel and expired retries never erase active solving time', () {
    var now = Duration.zero;
    final clock = LaunchClock(
      now: () => now,
      total: const Duration(seconds: 30),
    );
    clock.resume();
    now += const Duration(seconds: 12);
    clock.pause();
    now += const Duration(hours: 3);
    clock.extend(const Duration(seconds: 8));
    expect(clock.elapsed, const Duration(seconds: 12));
    expect(clock.remaining, const Duration(seconds: 26));
    clock.resume();
    now += const Duration(seconds: 26);
    expect(clock.expired, isTrue);
    expect(clock.elapsed, const Duration(seconds: 38));
    clock.extend(const Duration(seconds: 30));
    clock.resume();
    now += const Duration(seconds: 3);
    expect(clock.elapsed, const Duration(seconds: 41));
    expect(clock.remaining, const Duration(seconds: 27));
    clock.reset(const Duration(seconds: 68), elapsed: clock.elapsed);
    expect(clock.remaining, const Duration(seconds: 27));
    expect(clock.isRunning, isFalse);
  });

  test(
    'pickup meets the courier then enlarges and lands in the cargo hold',
    () {
      const size = Size(350, 350);
      final flight = RouteFlightGeometry.forBoard(
        [0, 1, 2, 7, 12, 13, 14],
        5,
        61,
        15,
        size,
      );
      final fraction = flight.distanceToCell(7) / flight.length;
      final start = cargoPickupStart(fraction);
      expect(routeFlightEase(start / .56), closeTo(fraction, .000001));
      final origin = flight.centers[7]!;
      final initial = CargoPickupFrame.at(start - .01, start, origin, size, 61);
      expect(initial.position, origin);
      final hero = CargoPickupFrame.at(
        start + (.96 - start) * .43,
        start,
        origin,
        size,
        61,
      );
      expect(hero.radius, greaterThan(initial.radius * 3));
      expect(hero.position.dx, closeTo(175, .01));
      final docked = CargoPickupFrame.at(.98, start, origin, size, 61);
      expect(docked.position, const Offset(319, 321));
      expect(docked.opacity, 0);
      expect(docked.docked, isTrue);
    },
  );

  for (final size in [const Size(375, 667), const Size(1024, 1366)]) {
    testWidgets(
      'optional cargo is collected by real board turns and reaches receipt on $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({'journeyLevel': 31});
        final game = GameController(
          preferences: await SharedPreferences.getInstance(),
          now: () => DateTime(2026, 11, 23, 12),
        );
        await game.load();
        var now = Duration.zero;
        await tester.pumpWidget(
          GlowpathApp(
            controller: game,
            ambientMotion: false,
            showBriefings: false,
            clockNow: () => now,
          ),
        );
        await tester.pumpAndSettle();
        expect(game.puzzle.cargoCell, isNotNull);
        final kind = game.currentCargo!.kind;
        now = const Duration(seconds: 9);
        await tester.pump(const Duration(milliseconds: 200));
        for (final action in game.puzzle.solutionActions) {
          if (game.status.solved) break;
          await tester.tap(find.byKey(ValueKey('tile-$action')));
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(game.status.solved, isTrue);
        expect(game.lastReward!.cargoId, kind.name);
        expect(game.cargoCollection[kind], 1);
        expect(game.lastReward!.elapsedMilliseconds, 9000);
        final before = game.coinBalance;
        await tester.pump(const Duration(milliseconds: 1000));
        final board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
        expect(board.collectCargo, isTrue);
        expect(board.completionProgress, inExclusiveRange(.2, .5));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('next-puzzle')), findsOneWidget);
        expect(find.textContaining('9.0s'), findsOneWidget);
        expect(
          game.coinBalance,
          before,
          reason: 'The animation must never award again.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await game.flush();
        game.dispose();
      },
    );
  }

  testWidgets(
    'Voyage home pauses solving time and Play resumes the current route',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final game = GameController(
        preferences: await SharedPreferences.getInstance(),
      );
      await game.load();
      var now = Duration.zero;
      await tester.pumpWidget(
        GlowpathApp(
          controller: game,
          ambientMotion: false,
          showBriefings: false,
          clockNow: () => now,
        ),
      );
      await tester.pumpAndSettle();
      now = const Duration(seconds: 4);
      await tester.pump(const Duration(milliseconds: 200));
      // Map returns home and pauses the same clock that supplies route records.
      await tester.tap(find.byKey(const ValueKey('open-atlas')));
      await tester.pumpAndSettle();
      now += const Duration(minutes: 4);
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.attemptElapsed, const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('voyage-home-heading')), findsOneWidget);
      expect(find.byType(LaunchCountdown), findsNothing);
      await tester.tap(find.byKey(const ValueKey('next-puzzle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LaunchCountdown>(find.byType(LaunchCountdown))
            .remaining
            .inSeconds,
        26,
      );
      await tester.pumpWidget(const SizedBox());
      await game.flush();
      game.dispose();
    },
  );
}
