import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
  });

  for (final size in [
    const Size(393, 852),
    const Size(844, 390),
    const Size(600, 900),
    const Size(1024, 1366),
    const Size(1440, 900),
  ]) {
    testWidgets('secondary panel fits and returns to same puzzle at $size', (
      tester,
    ) async {
      final game = await _launch(tester, size);
      final seed = game.puzzle.seed;
      await tester.tap(find.byKey(const ValueKey('open-help')));
      await tester.pumpAndSettle();
      final sheet = find.byType(OrbitSheet);
      final layout = OrbitPanelLayout.fromSize(size);
      final bounds = tester.getRect(sheet);
      expect(tester.widget<OrbitSheet>(sheet).floating, layout.floating);
      expect(bounds.width, lessThanOrEqualTo(layout.maxWidth));
      expect(bounds.height, lessThanOrEqualTo(layout.maxHeight));
      expect(bounds.center.dx, closeTo(size.width / 2, .1));
      if (layout.floating) {
        expect(bounds.center.dy, closeTo(size.height / 2, .1));
        expect(find.byType(BottomSheet), findsNothing);
        final dialog = ModalRoute.of(tester.element(sheet));
        for (var i = 0; i < 12; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focusedContext = FocusManager.instance.primaryFocus?.context;
          expect(focusedContext, isNotNull);
          expect(ModalRoute.of(focusedContext!), same(dialog));
        }
      } else {
        expect(bounds.bottom, closeTo(size.height, .1));
        expect(find.byType(BottomSheet), findsOneWidget);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(OrbitSheet), findsNothing);
      expect(game.puzzle.seed, seed);
      expect(
        ModalRoute.of(tester.element(find.byType(PuzzleBoard)))!.isCurrent,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (platform, size, scale, expectedHeight) in [
    (TargetPlatform.macOS, const Size(832, 1194), 1.0, 620.0),
    (TargetPlatform.macOS, const Size(1728, 1117), 1.0, 620.0),
    (TargetPlatform.macOS, const Size(832, 1194), 3.0, 780.0),
    (TargetPlatform.iOS, const Size(1024, 1366), 1.0, 780.0),
  ]) {
    testWidgets(
      'settings panel has appropriate height for $platform $size at $scale text',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _launch(tester, size);
        await tester.tap(find.byKey(const ValueKey('open-settings')));
        await tester.pumpAndSettle();
        final sheet = find.byType(OrbitSheet);
        expect(tester.getSize(sheet).height, closeTo(expectedHeight, .1));
        for (var section = 0; section < 3; section++) {
          await tester.tap(find.byKey(ValueKey('settings-section-$section')));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'All sections retain their content area.',
          );
          expect(tester.getSize(sheet).height, closeTo(expectedHeight, .1));
          expect(
            find.descendant(of: sheet, matching: find.byType(Scrollable)),
            findsNothing,
          );
        }
        await tester.tap(find.byKey(const ValueKey('close-sheet')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'replacing a centered settings panel keeps clock paused until final close',
    (tester) async {
      var now = Duration.zero;
      await _launch(tester, const Size(1024, 1366), clockNow: () => now);
      now += const Duration(seconds: 3);
      await tester.pump(const Duration(milliseconds: 250));
      final before = tester
          .widget<LaunchCountdown>(find.byType(LaunchCountdown))
          .remaining;
      await tester.tap(find.byKey(const ValueKey('open-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-flight-support')));
      await tester.pumpAndSettle();
      expect(find.byType(OrbitSheet), findsOneWidget);
      now += const Duration(minutes: 2);
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).paused,
        isTrue,
      );
      expect(
        tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).remaining,
        before,
      );
      await tester.tap(find.byKey(const ValueKey('close-sheet')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).paused,
        isFalse,
      );
      now += const Duration(seconds: 1);
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).remaining,
        before - const Duration(seconds: 1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reduced motion changed in centered settings makes dismissal immediate',
    (tester) async {
      final game = await _launch(tester, const Size(1024, 1366));
      await tester.tap(find.byKey(const ValueKey('open-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-section-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reduce-motion')));
      await tester.pumpAndSettle();
      expect(game.reduceMotion, isTrue);
      await tester.tap(find.byKey(const ValueKey('close-sheet')));
      await tester.pump();
      expect(find.byType(OrbitSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<GameController> _launch(
  WidgetTester tester,
  Size size, {
  Duration Function()? clockNow,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'journeyLevel': 20});
  final game = GameController(
    preferences: (await tester.runAsync(SharedPreferences.getInstance))!,
    snapshotWriter: (_) async => true,
  );
  await game.load();
  addTearDown(game.dispose);
  await tester.pumpWidget(
    GlowpathApp(
      controller: game,
      ambientMotion: false,
      showBriefings: false,
      clockNow: clockNow ?? () => Duration.zero,
    ),
  );
  await tester.pumpAndSettle();
  return game;
}
