import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [
    const Size(668, 862),
    const Size(832, 1194),
    const Size(1280, 720),
    const Size(1440, 900),
    const Size(1728, 1117),
    const Size(1920, 1080),
  ]) {
    testWidgets('desktop play stays proportionate at $size', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'journeyLevel': 31});
      final game = GameController(
        preferences: await SharedPreferences.getInstance(),
      );
      await game.load();
      addTearDown(game.dispose);
      await tester.pumpWidget(
        GlowpathApp(
          controller: game,
          showBriefings: false,
          ambientMotion: false,
          clockNow: () => Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
      for (final mode in GameMode.values) {
        await tester.tap(
          find.byKey(
            ValueKey(
              mode == GameMode.voyage ? 'mode-journey' : 'mode-${mode.name}',
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (mode == GameMode.voyage) {
          await tester.tap(find.byKey(const ValueKey('next-puzzle')));
          await tester.pumpAndSettle();
        }
        final frame = tester.getRect(
          find.byKey(const ValueKey('desktop-play-frame')),
        );
        final board = tester.getRect(find.byType(PuzzleBoard));
        expect(frame.height, lessThanOrEqualTo(840));
        expect(frame.width, lessThanOrEqualTo(1100));
        expect(frame.center.dx, closeTo(size.width / 2, 1));
        expect(frame.center.dy, closeTo(size.height / 2, 1));
        expect(board.width, inInclusiveRange(360, 540));
        final panelFinder = find.byKey(const ValueKey('wide-flight-panel'));
        if (panelFinder.evaluate().isNotEmpty) {
          final panel = tester.getRect(panelFinder);
          final hint = tester.getRect(find.byKey(const ValueKey('hint')));
          final undo = tester.getRect(find.byKey(const ValueKey('undo')));
          final legend = tester.getRect(find.byType(PuzzleLegend));
          expect(hint.width, closeTo(panel.width, .01));
          expect(undo.top - hint.bottom, closeTo(8, .01));
          expect(legend.center.dx, closeTo(board.center.dx, .01));
          expect(legend.right, lessThan(panel.left));
          expect(hint.height, greaterThanOrEqualTo(48));
          if (mode == GameMode.voyage) {
            final skip = tester.getRect(
              find.byKey(const ValueKey('support-shortcut')),
            );
            expect(skip.top, closeTo(undo.top, .01));
            expect(skip.width, closeTo(undo.width, .01));
          }
        }
        for (final key in ['shared-navigation', 'hint', 'undo', 'open-atlas']) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(frame.inflate(.01).contains(rect.topLeft), isTrue);
          expect(frame.inflate(.01).contains(rect.bottomRight), isTrue);
        }
        for (var index = 0; index < game.puzzle.tiles.length; index++) {
          expect(
            tester.getSize(find.byKey(ValueKey('tile-$index'))).shortestSide,
            greaterThanOrEqualTo(48),
          );
        }
        for (final element in find.byType(Scrollable).evaluate()) {
          final state = (element as StatefulElement).state as ScrollableState;
          expect(state.position.maxScrollExtent, 0);
          expect(state.position.minScrollExtent, 0);
          expect(
            state.position.physics.shouldAcceptUserOffset(state.position),
            isFalse,
          );
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('portrait iPad keeps its larger touch board', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'journeyLevel': 31});
    final game = GameController(
      preferences: await SharedPreferences.getInstance(),
    );
    await game.load();
    addTearDown(game.dispose);
    await tester.pumpWidget(
      GlowpathApp(
        controller: game,
        showBriefings: false,
        ambientMotion: false,
        clockNow: () => Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-play-frame')), findsNothing);
    expect(tester.getSize(find.byType(PuzzleBoard)).width, greaterThan(700));
    expect(tester.takeException(), isNull);
  });
}
