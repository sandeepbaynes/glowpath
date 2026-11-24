import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/mission_briefing.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/planet_flight.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Atkinson')..addFont(
          rootBundle.load(
            'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
          ),
        ))
        .load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(844, 390),
    const Size(1024, 1366),
    const Size(1366, 1024),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('first flight pauses countdown and fits $size at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final game = GameController(
          preferences: await SharedPreferences.getInstance(),
        );
        await game.load();
        addTearDown(game.dispose);
        var now = Duration.zero;
        await tester.pumpWidget(
          GlowpathApp(
            controller: game,
            clockNow: () => now,
            ambientMotion: false,
          ),
        );
        await tester.pump();
        expect(find.byType(MissionBriefing), findsOneWidget);
        expect(tester.takeException(), isNull);
        final start = find.byKey(const ValueKey('briefing-start'));
        expect(tester.getRect(start).bottom, lessThanOrEqualTo(size.height));
        now = const Duration(seconds: 40);
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester
              .widget<LaunchCountdown>(find.byType(LaunchCountdown))
              .remaining,
          const Duration(seconds: 30),
        );
        expect(game.moves, 0);
        if (scale == 1) {
          // The normal-size briefing remains a single action.
          expect(tester.widget<SpaceAction>(start).label, "Let's fly");
          await tester.tap(start);
          await tester.pump();
        } else {
          final chunks = <String>[];
          for (var page = 0; page < 50 && !game.onboardingSeen; page++) {
            final copy = find.byKey(const ValueKey('briefing-copy'));
            chunks.add(tester.widget<Text>(copy).data!);
            final paragraph = tester.renderObject<RenderParagraph>(copy);
            expect(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width),
              lessThanOrEqualTo(paragraph.size.height + .01),
            );
            final actionBounds = tester.getRect(start);
            expect(start.hitTestable(), findsOneWidget);
            expect(actionBounds.top, greaterThanOrEqualTo(0));
            expect(actionBounds.bottom, lessThanOrEqualTo(size.height));
            expect(actionBounds.height, greaterThanOrEqualTo(48));
            final finalPage =
                tester.widget<SpaceAction>(start).label == "Let's fly";
            expect(
              tester.widget<SpaceAction>(start).label,
              finalPage ? "Let's fly" : 'Next',
            );
            now += const Duration(seconds: 10);
            await tester.pump(const Duration(milliseconds: 250));
            expect(
              tester
                  .widget<LaunchCountdown>(find.byType(LaunchCountdown))
                  .remaining,
              const Duration(seconds: 30),
              reason:
                  'Reading every instruction keeps the launch clock paused.',
            );
            await tester.tap(start);
            await tester.pump();
            expect(game.onboardingSeen, finalPage);
            expect(
              find.byType(MissionBriefing),
              finalPage ? findsNothing : findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
          expect(
            chunks.join('').replaceAll(RegExp(r'\s'), ''),
            firstFlightBriefing
                .map((beat) => beat.text)
                .join('')
                .replaceAll(RegExp(r'\s'), ''),
            reason: 'Pagination must show every complete flight instruction.',
          );
        }
        expect(find.byType(MissionBriefing), findsNothing);
        expect(game.onboardingSeen, isTrue);
        expect(
          tester
              .widgetList<PipeTile>(find.byType(PipeTile))
              .every((tile) => !tile.teach),
          isTrue,
        );
        now += const Duration(seconds: 1);
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          tester
              .widget<LaunchCountdown>(find.byType(LaunchCountdown))
              .remaining,
          const Duration(seconds: 29),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'unseen weekly rules pause play, teach once, and survive reload',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final game = GameController(preferences: prefs);
      await game.load();
      game.markOnboardingSeen();
      game.setReduceMotion(true);
      addTearDown(game.dispose);
      var now = Duration.zero;
      await tester.pumpWidget(
        GlowpathApp(
          controller: game,
          ambientMotion: false,
          clockNow: () => now,
        ),
      );
      await tester.pump();
      game.setMode(GameMode.weekly);
      await tester.pump();
      final titles = missionRulesFor(game.puzzle).map((r) => r.title).toList();
      expect(titles.length, greaterThan(1));
      expect(find.byType(MissionBriefing), findsOneWidget);
      final remaining = tester
          .widget<LaunchCountdown>(find.byType(LaunchCountdown))
          .remaining;
      now += const Duration(seconds: 80);
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).remaining,
        remaining,
      );
      for (
        var page = 0;
        page < 10 && find.byType(MissionBriefing).evaluate().isNotEmpty;
        page++
      ) {
        await tester.tap(find.byKey(const ValueKey('briefing-start')));
        await tester.pump();
      }
      expect(find.byType(MissionBriefing), findsNothing);
      expect(titles.every(game.knowsRule), isTrue);
      game.setMode(GameMode.voyage);
      game.setMode(GameMode.weekly);
      await tester.pump();
      expect(find.byType(MissionBriefing), findsNothing);
      await game.flush();
      final restored = GameController(preferences: prefs);
      await restored.load();
      expect(titles.every(restored.knowsRule), isTrue);
      restored.dispose();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('new planet briefing pauses next route and skip earns no stars', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'journeyLevel': 12});
    final game = GameController(
      preferences: await SharedPreferences.getInstance(),
    );
    await game.load();
    // Earn the skip's currency through real clears before the boundary route.
    for (var level = 12; level < 15; level++) {
      game.updateAttemptTiming(
        const Duration(seconds: 8),
        const Duration(seconds: 30),
      );
      for (final action in game.puzzle.solutionActions) {
        if (game.status.solved) break;
        game.rotate(action);
      }
      expect(game.status.solved, isTrue);
      game.nextPuzzle();
    }
    game.markOnboardingSeen();
    game.setReduceMotion(true);
    addTearDown(game.dispose);
    var now = Duration.zero;
    await tester.pumpWidget(
      GlowpathApp(controller: game, ambientMotion: false, clockNow: () => now),
    );
    await tester.pump();
    for (final action in game.puzzle.solutionActions) {
      if (game.status.solved) break;
      game.rotate(action);
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('next-puzzle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.puzzle.levelNumber, 16);
    expect(find.byType(PlanetFlight), findsOneWidget);
    expect(find.byType(MissionBriefing), findsNothing);
    now = const Duration(seconds: 50);
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).remaining,
      const Duration(seconds: 30),
    );
    for (
      var page = 0;
      page < 12 && find.byType(PlanetFlight).evaluate().isNotEmpty;
      page++
    ) {
      await tester.tap(find.byKey(const ValueKey('flight-next')));
      await tester.pump();
    }
    expect(find.byType(PlanetFlight), findsNothing);
    expect(find.byType(MissionBriefing), findsNothing);
    expect(
      missionRulesFor(game.puzzle).every((rule) => game.knowsRule(rule.title)),
      isTrue,
    );
    final stars = game.stars;
    final coins = game.coinBalance;
    expect(coins, greaterThanOrEqualTo(75));
    await tester.tap(find.byKey(const ValueKey('support-shortcut')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('earned-supply-buy-1')));
    await tester.pump(const Duration(seconds: 1));
    expect(game.puzzle.levelNumber, 17);
    expect(game.stars, stars);
    expect(game.coinBalance, coins - 75);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
