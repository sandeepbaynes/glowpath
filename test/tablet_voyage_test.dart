import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/space_scenery.dart';
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
  const cases = [
    (size: Size(744, 1133), scale: 1.0, level: 5),
    (size: Size(1133, 744), scale: 1.0, level: 10),
    (size: Size(820, 1180), scale: 2.0, level: 15),
    (size: Size(1180, 820), scale: 1.0, level: 20),
    (size: Size(1024, 1366), scale: 1.0, level: 25),
    (size: Size(1366, 1024), scale: 2.0, level: 10),
    (size: Size(800, 1280), scale: 1.0, level: 8),
    (size: Size(1280, 800), scale: 2.0, level: 18),
  ];
  for (final entry in cases) {
    testWidgets(
      'tablet ${entry.size} at ${entry.scale}x supports play and full-screen voyage',
      (tester) async {
        tester.view.physicalSize = entry.size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = entry.scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({'journeyLevel': entry.level});
        final game = (await tester.runAsync(() async {
          final value = GameController(
            preferences: await SharedPreferences.getInstance(),
            snapshotWriter: (_) async => true,
          );
          await value.load();
          return value;
        }))!;
        addTearDown(game.dispose);
        await tester.pumpWidget(
          GlowpathApp(showBriefings: false,
            controller: game,
            ambientMotion: false,
            clockNow: () => Duration.zero,
          ),
        );
        await tester.pumpAndSettle();
        for (final tile in tester.widgetList<PipeTile>(find.byType(PipeTile))) {
          final size = tester.getSize(
            find.byKey(ValueKey('tile-${tile.index}')),
          );
          expect(size.shortestSide, greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
        for (var step = 0; step < 30 && !game.status.solved; step++) {
          expect(game.hint(), isTrue);
        }
        expect(game.status.solved, isTrue);
        await tester.pumpAndSettle();
        final scene = find.byKey(const ValueKey('next-stop-flight'));
        expect(tester.getRect(scene), Offset.zero & entry.size);
        final painter =
            tester.widget<CustomPaint>(scene).painter! as VoyageDepthPainter;
        expect(painter.approach, 1);
        final oldLevel = game.puzzle.levelNumber;
        final oldStars = game.stars;
        if (entry.scale == 1) {
          final touch = Offset(entry.size.width * .52, entry.size.height * .46);
          final drag = await tester.startGesture(touch);
          await drag.moveBy(Offset(0, entry.size.height * .18));
          await tester.pump();
          final moved =
              tester.widget<CustomPaint>(scene).painter! as VoyageDepthPainter;
          expect(moved.cameraExcursion, greaterThan(0));
          await drag.up();
          await tester.pumpAndSettle();
          final home =
              tester.widget<CustomPaint>(scene).painter! as VoyageDepthPainter;
          expect(home.cameraExcursion, 0);
        }
        expect(game.puzzle.levelNumber, oldLevel);
        expect(game.stars, oldStars);
        final play = find.byKey(const ValueKey('next-puzzle'));
        await tester.ensureVisible(play);
        await tester.pumpAndSettle();
        expect(play.hitTestable(), findsOneWidget);
        expect(tester.getSize(play).height, greaterThanOrEqualTo(48));
        await tester.tap(play);
        await tester.pumpAndSettle();
        expect(game.puzzle.levelNumber, oldLevel + 1);
        expect(game.stars, oldStars);
        expect(
          tester
              .widget<LaunchCountdown>(find.byType(LaunchCountdown))
              .remaining
              .inSeconds,
          inInclusiveRange(20, 60),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
