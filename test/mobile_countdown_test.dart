import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
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
    const Size(375, 667),
    const Size(393, 852),
  ]) {
    testWidgets('prominent mobile timer stays directly above stars at $size', (
      tester,
    ) async {
      final game = await _game(tester);
      var now = Duration.zero;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GlowpathApp(showBriefings: false,
          controller: game,
          ambientMotion: false,
          clockNow: () => now,
        ),
      );
      await tester.pumpAndSettle();
      final clock = find.byType(LaunchCountdown);
      expect(tester.widget<LaunchCountdown>(clock).prominent, isTrue);
      final legend = find.byType(PuzzleLegend);
      final clockBounds = tester.getRect(clock);
      final legendBounds = tester.getRect(legend);
      expect(clockBounds.bottom, lessThanOrEqualTo(legendBounds.top + .01));
      expect(legendBounds.top - clockBounds.bottom, lessThanOrEqualTo(12));
      final cells = [
        for (var i = 0; i < game.puzzle.tiles.length; i++)
          tester.getRect(find.byKey(ValueKey('tile-$i'))),
      ];
      for (final rect in cells) {
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      now = Duration(
        seconds: tester.widget<LaunchCountdown>(clock).total.inSeconds - 4,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 240));
      expect(tester.getRect(clock), clockBounds);
      expect(tester.getRect(legend), legendBounds);
      for (var i = 0; i < cells.length; i++) {
        expect(tester.getRect(find.byKey(ValueKey('tile-$i'))), cells[i]);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'countdown pulses once per boundary and respects pause, preference and failure',
    (tester) async {
      final game = await _game(tester);
      var now = Duration.zero;
      final impacts = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            impacts.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        GlowpathApp(showBriefings: false,
          controller: game,
          ambientMotion: false,
          clockNow: () => now,
        ),
      );
      await tester.pumpAndSettle();
      final total = tester
          .widget<LaunchCountdown>(find.byType(LaunchCountdown))
          .total
          .inSeconds;
      Future<void> remaining(int seconds) async {
        now = Duration(seconds: total - seconds);
        await tester.pump(const Duration(milliseconds: 200));
      }

      await remaining(10);
      expect(impacts, ['HapticFeedbackType.lightImpact']);
      await tester.pump(const Duration(milliseconds: 600));
      expect(impacts.length, 1);
      await remaining(9);
      expect(impacts.length, 1);
      await remaining(8);
      await remaining(5);
      await remaining(2);
      expect(impacts, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
      await tester.tap(find.byKey(const ValueKey('open-help')));
      await tester.pumpAndSettle();
      final before = impacts.length;
      now += const Duration(seconds: 30);
      await tester.pump(const Duration(seconds: 1));
      expect(impacts.length, before);
      await tester.tap(find.byKey(const ValueKey('close-sheet')));
      await tester.pumpAndSettle();
      game.setHaptics(false);
      now += const Duration(seconds: 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(impacts.length, before);
      now += const Duration(seconds: 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('failed-flight')), findsOneWidget);
      expect(impacts.length, before);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<GameController> _game(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'journeyLevel': 20});
  final preferences = (await tester.runAsync(SharedPreferences.getInstance))!;
  final game = GameController(
    preferences: preferences,
    snapshotWriter: (_) async => true,
  );
  await game.load();
  addTearDown(game.dispose);
  return game;
}
