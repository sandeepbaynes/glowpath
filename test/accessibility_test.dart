import 'support/solve_rendered_puzzle.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  // Pairwise coverage keeps the suite short while retaining the hardest cases.
  const cases = <(Size, double, int)>[
    (Size(320, 568), 1, 8),
    (Size(320, 568), 1.5, 8),
    (Size(320, 568), 2, 8),
    (Size(320, 568), 3, 8),
    (Size(390, 844), 1, 8),
    (Size(430, 932), 1.5, 8),
    (Size(844, 390), 1, 8),
    (Size(844, 390), 3, 8),
    (Size(768, 1024), 1, 8),
    (Size(768, 1024), 2, 8),
    (Size(1280, 900), 1, 8),
    (Size(1280, 900), 3, 8),
    (Size(320, 568), 3, 20),
    (Size(844, 390), 3, 20),
    (Size(768, 1024), 2, 20),
  ];
  for (final (viewport, scale, journeyLevel) in cases) {
    _semanticsTestWidgets(
      '$viewport at ${scale}x route $journeyLevel keeps play controls accessible',
      (tester) async {
        final controller = await _launch(
          tester,
          viewport: viewport,
          scale: scale,
          journeyLevel: journeyLevel,
        );
        await tester.pump();
        expect(
          MediaQuery.textScalerOf(tester.element(find.byType(GameScreen)))
              .scale(16),
          closeTo(16 * scale, .001),
        );
        expect(tester.takeException(), isNull);

        // Measure all cells directly: guideline traversal can skip scrolled edges.
        final tileRects = <Rect>[];
        for (var index = 0; index < controller.puzzle.tiles.length; index++) {
          final tile = find.byKey(ValueKey('tile-$index'));
          final rect = tester.getRect(tile);
          expect(rect.width, greaterThanOrEqualTo(48 - .001));
          expect(rect.height, greaterThanOrEqualTo(48 - .001));
          for (final previous in tileRects) {
            expect(rect.overlaps(previous), isFalse);
          }
          tileRects.add(rect);
        }
        for (final key in [
          'mode-journey',
          'tile-${controller.puzzle.tiles.length ~/ 2}',
          'hint',
          'open-help',
        ]) {
          await _reveal(tester, key);
          _expectVisibleTouchTarget(tester, key);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull);
        }
        await _reveal(tester, 'hint');
        await tester.tap(find.byKey(const ValueKey('hint')));
        await tester.pumpAndSettle();
        expect(controller.assisted, isTrue);
        expect(controller.moves, 0);
        await tester.tap(find.byKey(const ValueKey('hint')));
        await tester.pumpAndSettle();
        expect(controller.moves, greaterThan(0));
        await _reveal(tester, 'undo');
        _expectVisibleTouchTarget(tester, 'undo');

        // Restart moved into Settings, but must stay reachable at every scale.
        await _reveal(tester, 'open-settings');
        await tester.tap(find.byKey(const ValueKey('open-settings')));
        await tester.pumpAndSettle();
        await _reveal(tester, 'restart');
        _expectVisibleTouchTarget(tester, 'restart');
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await _reveal(tester, 'close-sheet');
        await tester.tap(find.byKey(const ValueKey('close-sheet')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  _semanticsTestWidgets(
    'unhighlighted opening relays remain accessible without requesting assistance',
    (tester) async {
      final controller = await _launch(tester, journeyLevel: 1);
      expect(
        find.byWidgetPredicate((widget) => widget is PipeTile && widget.teach),
        findsNothing,
      );
      final index = controller.puzzle.solutionActions.first;
      final tile = find.byKey(ValueKey('tile-$index'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      final description = tester.semantics.find(tile).getSemanticsData();
      expect(description.hint, 'Turn clockwise');
      expect(controller.assisted, isFalse);
      expect(controller.moves, 0);
      tester.semantics.tap(find.semantics.byLabel(description.label));
      await tester.pump(const Duration(milliseconds: 280));
      expect(controller.status.solved, isFalse);
      expect(controller.moves, 1);
      await solveRenderedPuzzle(tester);
      expect(controller.status.solved, isTrue);
      expect(controller.moves, greaterThanOrEqualTo(3));
      expect(controller.assisted, isFalse);
      expect(
        tester.semantics.find(tile).getSemanticsData().hint,
        'Route complete',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('next-stop-flight')), findsOneWidget);
      await _reveal(tester, 'next-puzzle');
      expect(
        tester.semantics.find(find.byKey(const ValueKey('next-puzzle'))),
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      expect(tester.takeException(), isNull);
    },
  );

  _semanticsTestWidgets(
    'destination announces mode progress and exposes its voyage-map action',
    (tester) async {
      final controller = await _launch(tester);
      final destination = find.byKey(const ValueKey('open-atlas'));
      await _reveal(tester, 'open-atlas');
      final voyage = tester.semantics.find(destination).getSemanticsData();
      expect(voyage.label, contains('Destination Luma'));
      expect(voyage.label, contains('Aster Reach'));
      expect(voyage.label, contains('Open voyage map'));
      expect(voyage.value, 'Route 8 of 15');

      await _reveal(tester, 'mode-daily');
      await tester.tap(find.byKey(const ValueKey('mode-daily')));
      await tester.pumpAndSettle();
      await _reveal(tester, 'open-atlas');
      final daily = tester.semantics.find(destination).getSemanticsData();
      expect(daily.label, 'Daily sprint. Open voyage map');
      expect(daily.value, '0 of 3 routes charted');
      expect(
        tester.semantics.find(destination),
        isSemantics(isButton: true, hasTapAction: true),
      );
      tester.semantics.tap(find.semantics.byLabel(daily.label));
      await tester.pumpAndSettle();
      expect(controller.mode, GameMode.voyage);
      expect(find.byKey(const ValueKey('voyage-home-heading')), findsOneWidget);
      await _reveal(tester, 'next-puzzle');
      expect(
        tester.semantics.find(find.byKey(const ValueKey('next-puzzle'))),
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      await _reveal(tester, 'mode-daily');
      await tester.tap(find.byKey(const ValueKey('mode-daily')));
      await tester.pumpAndSettle();
      expect(controller.isDaily, isTrue);

      for (var hint = 0; hint < 25 && !controller.status.solved; hint++) {
        expect(controller.hint(), isTrue);
      }
      await tester.pump();
      expect(controller.status.solved, isTrue);
      await _revealDuringArrival(tester, 'open-atlas');
      final completed = tester.semantics.find(destination).getSemanticsData();
      expect(completed.label, 'Daily sprint. Open voyage map');
      expect(completed.value, '1 of 3 routes charted');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('next-puzzle')), findsNothing);
      expect(controller.isDaily, isTrue);
      expect(controller.status.solved, isFalse);
      await _reveal(tester, 'open-atlas');
      expect(
        tester.semantics.find(destination).getSemanticsData().value,
        '1 of 3 routes charted',
      );
      expect(tester.takeException(), isNull);
    },
  );

  _semanticsTestWidgets(
    'Start and Portal explain the goal and hinted relays announce their purpose',
    (tester) async {
      final controller = await _launch(tester);
      await tester.ensureVisible(
        find.bySemanticsLabel('Start. Cyan START tile on the left edge.'),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Start. Cyan START tile on the left edge.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Finish. Gold FINISH beacon on the right edge after collecting all three stars.',
        ),
        findsOneWidget,
      );
      final startIndex = controller.puzzle.startRow * controller.puzzle.size;
      final endIndex =
          controller.puzzle.endRow * controller.puzzle.size +
          controller.puzzle.size -
          1;
      for (final (index, role) in [
        (startIndex, 'entrance'),
        (endIndex, 'exit'),
      ]) {
        await _reveal(tester, 'tile-$index');
        expect(
          tester.semantics
              .find(find.byKey(ValueKey('tile-$index')))
              .getSemanticsData()
              .label,
          contains(role),
        );
      }
      final candidate = controller.suggestedHintIndex!;
      await _reveal(tester, 'hint');
      await tester.tap(find.byKey(const ValueKey('hint')));
      await tester.pumpAndSettle();
      await _reveal(tester, 'tile-$candidate');
      expect(
        tester.semantics
            .find(find.byKey(ValueKey('tile-$candidate')))
            .getSemanticsData()
            .hint,
        contains('Suggested relay'),
      );
      expect(controller.moves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  _semanticsTestWidgets(
    'tile semantics describe position, connections and completion',
    (tester) async {
      final controller = await _launch(tester);
      await tester.pump();
      final tile = find.byKey(const ValueKey('tile-0'));
      await _reveal(tester, 'tile-0');
      final before = tester.semantics.find(tile).getSemanticsData();
      expect(before.label, contains('Tile 1, 1'));
      expect(before.value, contains('Connects'));
      expect(
        tester.semantics.find(tile),
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      tester.semantics.tap(
        find.semantics.byLabel(RegExp(r'^Tile 1, 1(?:,|$)')),
      );
      await tester.pumpAndSettle();
      expect(controller.moves, 1);
      expect(
        tester.semantics.find(tile).getSemanticsData().value,
        isNot(before.value),
      );
      for (var hint = 0; hint < 25 && !controller.status.solved; hint++) {
        controller.hint();
      }
      await tester.pump();
      expect(controller.status.solved, isTrue);
      await _revealDuringArrival(tester, 'tile-0');
      expect(
        tester.semantics.find(tile),
        isSemantics(isButton: true, isEnabled: false, hasTapAction: false),
      );
      final starIndex = controller.puzzle.starIndices.first;
      final star = find.byKey(ValueKey('tile-$starIndex'));
      await _revealDuringArrival(tester, 'tile-$starIndex');
      final collected = tester.semantics.find(star).getSemanticsData();
      expect(collected.label, contains('star'));
      expect(collected.value, contains('Star collected'));
      await tester.ensureVisible(find.byKey(const ValueKey('star-status')));
      await tester.pump();
      final aggregate = tester.semantics
          .find(find.byKey(const ValueKey('star-status')))
          .getSemanticsData();
      expect('${aggregate.label} ${aggregate.value}', contains('3'));
      expect(
        '${aggregate.label} ${aggregate.value}'.toLowerCase(),
        contains('star'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleBoard), findsNothing);
      expect(find.byKey(const ValueKey('next-stop-flight')), findsOneWidget);
      expect(find.text('Planet 1 · Luma\nRoute 9 / 15'), findsOneWidget);
      await _reveal(tester, 'next-puzzle');
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in [const Size(320, 568), const Size(844, 390)]) {
    _semanticsTestWidgets(
      'automatic next stop keeps its announcement and Play accessible at $viewport with 3x text',
      (tester) async {
        final controller = await _launch(
          tester,
          journeyLevel: 1,
          viewport: viewport,
          scale: 3,
        );
        await solveRenderedPuzzle(tester);
        await tester.pumpAndSettle();
        expect(controller.status.solved, isTrue);
        expect(find.byType(PuzzleBoard), findsNothing);
        final summary = find.byKey(const ValueKey('next-stop-summary'));
        expect(summary, findsOneWidget);
        final summaryBounds = tester.getRect(summary);
        expect(summaryBounds.top, greaterThanOrEqualTo(0));
        expect(
          summaryBounds.bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(const ValueKey('shared-navigation'))).top,
          ),
        );
        // The announcement is readable, not a button: empty space in its
        // wide alignment box need not participate in pointer hit testing.
        final announcement = tester.semantics
            .find(find.byKey(const ValueKey('next-stop-summary')))
            .getSemanticsData();
        expect(announcement.flagsCollection.isLiveRegion, isTrue);
        expect(
          announcement.label,
          'Signal delivered. Next: route 2, Luma. Press Play when ready.',
        );
        await _reveal(tester, 'next-puzzle');
        final play = find.byKey(const ValueKey('next-puzzle'));
        expect(find.text('Play'), findsOneWidget);
        expect(
          tester.semantics.find(play),
          isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        final stars = controller.stars;
        tester.semantics.tap(find.semantics.byLabel('Play'));
        await tester.pumpAndSettle();
        expect(controller.puzzle.levelNumber, 2);
        expect(controller.status.solved, isFalse);
        expect(controller.stars, stars);
        expect(find.byType(PuzzleBoard), findsOneWidget);
        expect(find.byKey(const ValueKey('next-stop-flight')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  _semanticsTestWidgets(
    'mode selection is announced and visible text meets contrast',
    (tester) async {
      await _launch(tester);
      await tester.pump();
      await _reveal(tester, 'mode-journey');
      expect(
        tester.semantics.find(find.byKey(const ValueKey('mode-journey'))),
        isSemantics(isSelected: true),
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.byKey(const ValueKey('mode-daily')));
      await tester.pumpAndSettle();
      expect(
        tester.semantics.find(find.byKey(const ValueKey('mode-daily'))),
        isSemantics(isSelected: true),
      );
      expect(
        tester.semantics.find(find.byKey(const ValueKey('mode-journey'))),
        isSemantics(isSelected: false),
      );
      await _reveal(tester, 'hint');
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      expect(tester.takeException(), isNull);
    },
  );

  _semanticsTestWidgets(
    'panels and Voyage home remain usable on a narrow phone at 3x text',
    (tester) async {
      final controller = await _launch(
        tester,
        viewport: const Size(320, 568),
        scale: 3,
      );
      await tester.pump();
      for (final key in ['open-settings', 'open-help', 'open-atlas']) {
        await _reveal(tester, key);
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (key == 'open-settings') {
          await tester.tap(find.byKey(const ValueKey('settings-section-1')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('settings-next')));
          await tester.pumpAndSettle();
          await _reveal(tester, 'high-contrast');
          await tester.tap(find.byKey(const ValueKey('high-contrast')));
          await tester.pumpAndSettle();
          expect(controller.highContrast, isTrue);
          await tester.tap(find.byKey(const ValueKey('settings-next')));
          await tester.pumpAndSettle();
          await _reveal(tester, 'haptics');
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        }
        final closeKey = key == 'open-atlas' ? 'next-puzzle' : 'close-sheet';
        await _reveal(tester, closeKey);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.tap(find.byKey(ValueKey(closeKey)));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(closeKey)), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final viewport in [const Size(320, 568), const Size(844, 390)]) {
    _semanticsTestWidgets(
      'restart confirmation is reachable without scrolling at $viewport and 3x text',
      (tester) async {
        final controller = await _launch(tester, viewport: viewport, scale: 3);
        await _reveal(tester, 'tile-0');
        await tester.tap(find.byKey(const ValueKey('tile-0')));
        await tester.pumpAndSettle();
        final level = controller.journeyLevel;
        final stars = controller.stars;
        for (final confirm in [false, true]) {
          await _reveal(tester, 'open-settings');
          await tester.tap(find.byKey(const ValueKey('open-settings')));
          await tester.pumpAndSettle();
          await _reveal(tester, 'restart');
          await tester.tap(find.byKey(const ValueKey('restart')));
          await tester.pumpAndSettle();
          expect(controller.moves, 1);
          expect(tester.takeException(), isNull);
          final dialog = find.byKey(const ValueKey('restart-dialog'));
          expect(dialog, findsOneWidget);
          expect(
            find.descendant(of: dialog, matching: find.byType(Scrollable)),
            findsNothing,
          );
          for (final key in ['confirm-restart', 'cancel-restart']) {
            _expectVisibleTouchTarget(tester, key);
            expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
          }
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await tester.tap(
            find.byKey(
              ValueKey(confirm ? 'confirm-restart' : 'cancel-restart'),
            ),
          );
          await tester.pumpAndSettle();
          expect(controller.moves, confirm ? 0 : 1);
          expect(controller.journeyLevel, level);
          expect(controller.stars, stars);
          expect(dialog, findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  for (final setting in ['iosReduceMotion', 'androidDisableAnimations']) {
    _semanticsTestWidgets(
      '$setting independently makes turns and arrival immediate',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(
              reduceMotion: setting == 'iosReduceMotion',
              disableAnimations: setting == 'androidDisableAnimations',
            );
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = await _launch(tester);
        expect(
          controller.reduceMotion,
          isFalse,
          reason: 'The OS setting must work without the in-game override.',
        );
        await _reveal(tester, 'tile-0');
        final tile = find.byKey(const ValueKey('tile-0'));
        await tester.tap(tile);
        await tester.pump();
        final rotation = tester.widget<AnimatedRotation>(
          find.descendant(of: tile, matching: find.byType(AnimatedRotation)),
        );
        final rendered = tester.widget<RotationTransition>(
          find.descendant(of: tile, matching: find.byType(RotationTransition)),
        );
        expect(controller.moves, 1);
        expect(
          rendered.turns.value,
          closeTo(rotation.turns, .0001),
          reason:
              'The actual rendered turn must already be at its final state.',
        );
        for (var hint = 0; hint < 25 && !controller.status.solved; hint++) {
          expect(controller.hint(), isTrue);
        }
        await tester.pump();
        expect(controller.status.solved, isTrue);
        expect(find.byType(PuzzleBoard), findsNothing);
        final flight = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('next-stop-flight')),
        );
        expect(
          (flight.painter as VoyageDepthPainter).approach,
          1,
          reason: 'The next stop must be reached on the first frame with reduced motion.',
        );
        expect(find.byKey(const ValueKey('next-puzzle')), findsOneWidget);
        expect(find.byKey(const ValueKey('next-stop-summary')), findsOneWidget);
        await _reveal(tester, 'next-puzzle');
        expect(
          tester.semantics.find(find.byKey(const ValueKey('next-puzzle'))),
          isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _revealDuringArrival(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: '$key must be reachable.',
  );
}

void _semanticsTestWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      // Flutter verifies outstanding handles before package:test tearDown runs.
      semantics.dispose();
    }
  });
}

Future<GameController> _launch(
  WidgetTester tester, {
  Size viewport = const Size(390, 844),
  double scale = 1,
  int journeyLevel = 8,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({'journeyLevel': journeyLevel});
  final controller = (await tester.runAsync(() async {
    final preferences = await SharedPreferences.getInstance();
    final value = GameController(
      preferences: preferences,
      now: () => DateTime.utc(2026, 11, 22, 12),
      snapshotWriter: (_) async => true,
    );
    await value.load();
    await value.flush();
    return value;
  }))!;
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    GlowpathApp(
      showBriefings: false,
      controller: controller,
      ambientMotion: false,
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _reveal(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: '$key must be reachable.',
  );
}

void _expectVisibleTouchTarget(WidgetTester tester, String key) {
  final target = find.byKey(ValueKey(key));
  final rect = tester.getRect(target);
  final render = tester.renderObject<RenderBox>(target);
  final ancestorViewport = RenderAbstractViewport.maybeOf(render);
  final viewportBox = ancestorViewport is RenderBox
      ? ancestorViewport as RenderBox
      : null;
  final viewport = viewportBox != null
      ? viewportBox.localToGlobal(Offset.zero) & viewportBox.size
      : Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);

  // A fixed header creates an interior scroll-viewport edge. A global tap
  // guideline sees unrelated, partly scrolled-out tiles there as truncated
  // targets. Check the revealed control's complete render AND semantic bounds
  // instead; all logical tile targets/non-overlap are checked above, and
  // the global label guideline still covers the whole visible interface.
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: '$key must accept touch',
  );
  expect(rect.width, greaterThanOrEqualTo(48 - .001));
  expect(rect.height, greaterThanOrEqualTo(48 - .001));
  expect(rect.left, greaterThanOrEqualTo(viewport.left - .001));
  expect(rect.top, greaterThanOrEqualTo(viewport.top - .001));
  expect(rect.right, lessThanOrEqualTo(viewport.right + .001));
  expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + .001));
  final semanticBounds = tester.semantics.find(target).rect;
  expect(semanticBounds.width, greaterThanOrEqualTo(48 - .001));
  expect(semanticBounds.height, greaterThanOrEqualTo(48 - .001));
}
