import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/launch_splash.dart';
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

  testWidgets('cold load restores a completed Voyage directly from splash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'journeyLevel': 14});
    final saved = (await tester.runAsync(() async {
      String? snapshot;
      final original = GameController(
        preferences: await SharedPreferences.getInstance(),
        snapshotWriter: (value) async {
          snapshot = value;
          return true;
        },
      );
      await original.load();
      for (var turn = 0; turn < 30 && !original.status.solved; turn++) {
        expect(original.hint(), isTrue);
      }
      expect(original.status.solved, isTrue);
      await original.flush();
      expect(snapshot, isNotNull);
      final level = original.puzzle.levelNumber;
      final moves = original.moves;
      final stars = original.stars;
      original.dispose();
      SharedPreferences.setMockInitialValues({
        GameController.storageKey: snapshot!,
      });
      return (
        preferences: await SharedPreferences.getInstance(),
        level: level,
        moves: moves,
        stars: stars,
      );
    }))!;
    final restored = GameController(
      preferences: saved.preferences,
      snapshotWriter: (_) async => true,
    );
    addTearDown(restored.dispose);
    expect(restored.ready, isFalse);
    await tester.pumpWidget(
      GlowpathApp(
        showBriefings: false,
        controller: restored,
        ambientMotion: false,
        clockNow: () => Duration.zero,
      ),
    );
    expect(find.byType(LaunchSplash), findsOneWidget);
    expect(find.byType(PuzzleBoard), findsNothing);
    expect(find.byKey(const ValueKey('tile-0')).hitTestable(), findsNothing);

    // One frame processes the completed load notification. No timed delay or
    // solve animation is needed to reach the saved destination.
    await tester.pump();
    expect(restored.ready, isTrue);
    expect(restored.status.solved, isTrue);
    expect(restored.puzzle.levelNumber, saved.level);
    expect(restored.moves, saved.moves);
    expect(restored.stars, saved.stars);
    expect(find.byType(PuzzleBoard), findsNothing);
    expect(find.byKey(const ValueKey('next-stop-summary')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('next-puzzle')).hitTestable(),
      findsOneWidget,
    );
    final scene = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('next-stop-flight')),
    );
    expect((scene.painter as VoyageDepthPainter).approach, 1);
    final nextLevel = saved.level + 1;
    expect(
      find.text(
        'Planet ${VoyageWorld.forLevel(nextLevel).planetIndex + 1} · ${VoyageWorld.forLevel(nextLevel).name}\nRoute ${VoyageWorld.forLevel(nextLevel).routeWithin(nextLevel)} / 15',
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.byType(LaunchSplash), findsNothing);
    expect(find.byType(PuzzleBoard), findsNothing);
    expect(
      restored.stars,
      saved.stars,
      reason: 'Restoration cannot award twice',
    );
    expect(tester.takeException(), isNull);
  });

  const cases = [
    (size: Size(390, 844), scale: 1.0, insets: EdgeInsets.zero),
    (
      size: Size(390, 844),
      scale: 1.0,
      insets: EdgeInsets.only(top: 47, bottom: 34),
    ),
    (
      size: Size(844, 390),
      scale: 1.0,
      insets: EdgeInsets.only(left: 44, right: 44, bottom: 21),
    ),
    (size: Size(820, 1180), scale: 1.0, insets: EdgeInsets.zero),
    (size: Size(1366, 1024), scale: 1.0, insets: EdgeInsets.zero),
    (size: Size(320, 568), scale: 3.0, insets: EdgeInsets.zero),
  ];
  for (final entry in cases) {
    testWidgets(
      'bottom navigation remains reachable through arrival, Play and rapid '
      'mode changes at ${entry.size} / ${entry.scale}x / ${entry.insets}',
      (tester) async {
        tester.view.physicalSize = entry.size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(
          left: entry.insets.left,
          top: entry.insets.top,
          right: entry.insets.right,
          bottom: entry.insets.bottom,
        );
        tester.view.viewPadding = tester.view.padding;
        tester.platformDispatcher.textScaleFactorTestValue = entry.scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final game = (await tester.runAsync(() async {
          final controller = GameController(
            preferences: await SharedPreferences.getInstance(),
            snapshotWriter: (_) async => true,
          );
          await controller.load();
          return controller;
        }))!;
        addTearDown(game.dispose);
        await tester.pumpWidget(
          GlowpathApp(
            showBriefings: false,
            controller: game,
            ambientMotion: false,
            clockNow: () => Duration.zero,
          ),
        );
        await tester.pumpAndSettle();
        final header = _captureHeader(tester);
        final safeViewport = Rect.fromLTRB(
          entry.insets.left,
          entry.insets.top,
          entry.size.width - entry.insets.right,
          entry.size.height - entry.insets.bottom,
        );
        void expectNavigation() => _expectHeader(tester, header, safeViewport);
        expectNavigation();

        // Solve without scrolling navigation or altering the viewport. The
        // same controls must survive both the payoff and the crossfade.
        for (var turn = 0; turn < 30 && !game.status.solved; turn++) {
          expect(game.hint(), isTrue);
        }
        expect(game.status.solved, isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expectNavigation();
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const ValueKey('next-stop-summary')), findsOneWidget);
        expectNavigation();
        await tester.pumpAndSettle();
        expectNavigation();

        // Returning to an already completed Voyage restores its arrival screen
        // directly. The outgoing Daily board may fade, but it cannot accept
        // input, and the completed board must not replay its payoff first.
        await tester.tap(find.byKey(const ValueKey('mode-daily')));
        await tester.pumpAndSettle();
        expect(game.isDaily, isTrue);
        expect(game.status.solved, isFalse);
        expectNavigation();
        await tester.tap(find.byKey(const ValueKey('mode-journey')));
        await tester.pump();
        expect(game.isDaily, isFalse);
        expect(game.status.solved, isTrue);
        expect(find.byKey(const ValueKey('next-stop-summary')), findsOneWidget);
        expect(find.byKey(const ValueKey('next-puzzle')), findsOneWidget);
        final restoredScene = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('next-stop-flight')),
        );
        expect(
          (restoredScene.painter as VoyageDepthPainter).approach,
          1,
          reason:
              'A restored destination is already reached on its first frame',
        );
        expect(find.byType(PipeTile).hitTestable(), findsNothing);
        expectNavigation();
        final arrival = tester.element(
          find.byKey(const ValueKey('next-stop-flight')),
        );
        for (var tap = 0; tap < 3; tap++) {
          await tester.tap(find.byKey(const ValueKey('mode-journey')));
          await tester.pump(const Duration(milliseconds: 80));
          expect(
            tester.element(find.byKey(const ValueKey('next-stop-flight'))),
            same(arrival),
            reason: 'Selecting the active mode cannot restart its arrival',
          );
          expect(
            find.byKey(const ValueKey('next-stop-summary')),
            findsOneWidget,
          );
          expectNavigation();
        }
        await tester.pumpAndSettle();

        final play = find.byKey(const ValueKey('next-puzzle'));
        await tester.ensureVisible(play);
        await tester.pumpAndSettle();
        expectNavigation();
        await tester.tap(play);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(game.puzzle.levelNumber, 2);
        expectNavigation();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('hint')));
        await tester.pumpAndSettle();
        expectNavigation();

        // Reverse the switch before its fade completes. Navigation must remain
        // in one place and have only one interactive instance throughout.
        for (final daily in [true, false, true, false]) {
          await tester.tap(
            find.byKey(ValueKey(daily ? 'mode-daily' : 'mode-journey')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          expect(game.isDaily, daily);
          expectNavigation();
        }
        await tester.pumpAndSettle();
        expectNavigation();
        expect(game.isDaily, isFalse);
        expect(game.puzzle.levelNumber, 2);
      },
    );
  }
}

const _headerKeys = [
  'mode-journey',
  'mode-daily',
  'mode-weekly',
  'open-help',
  'open-settings',
];

Map<String, ({Rect rect, Element element})> _captureHeader(
  WidgetTester tester,
) => {
  for (final key in _headerKeys)
    key: (
      rect: tester.getRect(find.byKey(ValueKey(key))),
      element: tester.element(find.byKey(ValueKey(key))),
    ),
};

void _expectHeader(
  WidgetTester tester,
  Map<String, ({Rect rect, Element element})> initial,
  Rect safeViewport,
) {
  expect(tester.takeException(), isNull);
  final dock = find.byKey(const ValueKey('shared-navigation'));
  expect(dock, findsOneWidget);
  final dockRect = tester.getRect(dock);
  expect(dockRect.top, greaterThanOrEqualTo(safeViewport.top));
  expect(
    safeViewport.bottom - dockRect.bottom,
    inInclusiveRange(-.001, 16),
    reason: 'Navigation stays at the reachable bottom edge above safe insets',
  );
  final controls = <Rect>[];
  for (final key in _headerKeys) {
    final finder = find.byKey(ValueKey(key));
    expect(finder, findsOneWidget, reason: '$key must never be duplicated');
    expect(finder.hitTestable(), findsOneWidget);
    expect(
      tester.element(finder),
      same(initial[key]!.element),
      reason: '$key belongs to the persistent navigation, not a fading page',
    );
    final rect = tester.getRect(finder);
    expect(
      rect,
      initial[key]!.rect,
      reason: '$key must not shift between pages',
    );
    final isMode = key.startsWith('mode-');
    expect(
      rect.width,
      greaterThanOrEqualTo(isMode || safeViewport.width < 360 ? 48 : 56),
    );
    expect(rect.height, greaterThanOrEqualTo(isMode ? 64 : 56));
    expect(rect.left, greaterThanOrEqualTo(safeViewport.left));
    expect(rect.top, greaterThanOrEqualTo(dockRect.top));
    expect(rect.right, lessThanOrEqualTo(safeViewport.right));
    expect(rect.bottom, lessThanOrEqualTo(safeViewport.bottom));
    expect(rect.bottom, lessThanOrEqualTo(dockRect.bottom));
    for (final other in controls) {
      expect(
        rect.overlaps(other),
        isFalse,
        reason: 'Dock actions cannot overlap',
      );
    }
    controls.add(rect);
  }
}
