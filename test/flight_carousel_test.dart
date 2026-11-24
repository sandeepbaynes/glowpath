import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_manual.dart';
import 'package:glowpath/ui/flight_page_surface.dart';
import 'package:glowpath/ui/flight_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'notes support swipe, arrows and cancellation with reduced motion $reduced',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(393, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var returned = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: FlightManual(
                  puzzle: Puzzle.planet(seed: 12, levelNumber: 1),
                  onClose: () => returned = true,
                  reduceMotion: reduced,
                ),
              ),
            ),
          ),
        );
        final carousel = find.byKey(const ValueKey('manual-carousel'));
        String copy() => tester
            .widget<Text>(find.byKey(const ValueKey('manual-body-copy')))
            .data!;
        final first = copy();
        await tester.drag(carousel, const Offset(-140, 0));
        await tester.pumpAndSettle();
        expect(copy(), contains('gold FINISH'));
        Focus.of(tester.element(find.byType(FlightLessonArt))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(copy(), first);
        final gesture = await tester.startGesture(tester.getCenter(carousel));
        await gesture.moveBy(const Offset(-70, 0));
        await gesture.moveBy(const Offset(-70, 0));
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(
          copy(),
          first,
          reason: 'An interrupted drag must not advance a lesson.',
        );
        await tester.tap(find.byKey(const ValueKey('manual-close')));
        expect(returned, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('control carousel retains settings and reward action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final game = (await tester.runAsync(() async {
      final value = GameController(
        preferences: await SharedPreferences.getInstance(),
        snapshotWriter: (_) async => true,
      );
      await value.load();
      return value;
    }))!;
    addTearDown(game.dispose);
    var rewardsOpened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: FlightSettings(
              game: game,
              onRestart: () {},
              onSupport: () {},
              onLeague: () {},
              onRewards: () => rewardsOpened++,
              onLicenses: () {},
            ),
          ),
        ),
      ),
    );
    final carousel = find.byKey(const ValueKey('settings-carousel'));
    final moves = game.moves;
    final stars = game.stars;
    await tester.drag(carousel, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('high-contrast')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('high-contrast')));
    await tester.pumpAndSettle();
    expect(game.highContrast, isTrue);
    expect(
      tester.widget<FlightLessonArt>(find.byType(FlightLessonArt)).highContrast,
      isTrue,
    );
    await tester.drag(carousel, const Offset(-150, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-rewards')));
    expect(rewardsOpened, 1);
    await tester.drag(carousel, const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(game.highContrast, isTrue);
    await tester.tap(find.byKey(const ValueKey('haptics')));
    await tester.pumpAndSettle();
    expect(game.haptics, isFalse);
    expect(
      tester.widget<FlightLessonArt>(find.byType(FlightLessonArt)).haptics,
      isFalse,
    );
    expect(game.moves, moves);
    expect(game.stars, stars);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
