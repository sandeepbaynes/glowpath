import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/services/fold_posture.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Geometry, not model-name detection, selects the same playable pane in both
// postures. Android dimensions below are synthetic clamshell/book viewports.
const _cases = [
  _FoldCase(
    'iOS horizontal',
    Size(669, 951),
    Rect.fromLTWH(0, 475.5, 669, 0),
    horizontal: true,
    platform: TargetPlatform.iOS,
    insets: EdgeInsets.only(top: 82, bottom: 34),
    occlusions: [Rect.fromLTWH(525, 0, 144, 82)],
  ),
  _FoldCase(
    'iOS vertical',
    Size(951, 669),
    Rect.fromLTWH(475.5, 0, 0, 669),
    horizontal: false,
    platform: TargetPlatform.iOS,
    insets: EdgeInsets.only(right: 84, bottom: 34),
    occlusions: [Rect.fromLTWH(827, 585, 124, 84)],
  ),
  _FoldCase(
    'Android compact clamshell',
    Size(393, 852),
    Rect.fromLTWH(0, 426, 393, 0),
    horizontal: true,
    platform: TargetPlatform.android,
    insets: EdgeInsets.only(top: 24, bottom: 24),
  ),
  _FoldCase(
    'Android tall clamshell',
    Size(412, 915),
    Rect.fromLTWH(0, 457.5, 412, 0),
    horizontal: true,
    platform: TargetPlatform.android,
    insets: EdgeInsets.only(top: 24, bottom: 24),
  ),
  _FoldCase(
    'Android book',
    Size(951, 669),
    Rect.fromLTWH(475.5, 0, 0, 669),
    horizontal: false,
    platform: TargetPlatform.android,
    insets: EdgeInsets.only(top: 24, bottom: 24),
  ),
];

void main() {
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final scenario in _cases) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        '${scenario.label} at ${scale}x keeps its pane on cold-open and half↔flat',
        (tester) async {
          _configure(tester, scenario, scale);
          final geometry = ValueNotifier(const FoldGeometry());
          addTearDown(geometry.dispose);
          String? saved;
          SharedPreferences.setMockInitialValues({'journeyLevel': 92});
          final game = GameController(
            preferences: await SharedPreferences.getInstance(),
            now: () => DateTime.utc(2026, 11, 24, 12),
            snapshotWriter: (value) {
              saved = value;
              return SynchronousFuture(true);
            },
          );
          await game.load();
          await game.flush();
          addTearDown(game.dispose);

          // Open the app already flat: no prior half-open event or cached pane
          // may be required to honor an inactive but real display division.
          _setPosture(tester, geometry, scenario, halfOpen: false);
          await tester.pumpWidget(
            GlowpathApp(
              controller: game,
              showBriefings: false,
              ambientMotion: false,
              clockNow: () => Duration.zero,
              foldGeometry: geometry,
            ),
          );
          await tester.pumpAndSettle();
          expect(game.puzzle.size, 5);
          _fits(tester, game, scenario);

          for (final mode in GameMode.values) {
            if (mode != GameMode.voyage) {
              await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
              await tester.pumpAndSettle();
            }
            final movable = game.puzzle.tiles.indexWhere(
              (tile) => !tile.isLocked,
            );
            await tester.tap(find.byKey(ValueKey('tile-$movable')));
            await tester.pumpAndSettle();
            final puzzle = game.puzzle;
            final rotations = puzzle.tiles
                .map((tile) => tile.rotation)
                .toList();
            final moves = game.moves;
            final remaining = tester
                .widget<LaunchCountdown>(find.byType(LaunchCountdown))
                .remaining;
            final board = tester.getRect(
              find.byKey(const ValueKey('puzzle-board')),
            );
            final dock = tester.getRect(
              find.byKey(const ValueKey('shared-navigation')),
            );
            await game.flush();
            final snapshot = saved;
            expect(snapshot, isNotNull);

            for (final halfOpen in [true, false, true, false]) {
              _setPosture(tester, geometry, scenario, halfOpen: halfOpen);
              await tester.pump();
              expect(
                tester.getRect(find.byKey(const ValueKey('puzzle-board'))),
                board,
              );
              await tester.pump(const Duration(milliseconds: 16));
              expect(
                tester.getRect(find.byKey(const ValueKey('puzzle-board'))),
                board,
              );
              await tester.pumpAndSettle();
              _fits(tester, game, scenario);
              expect(
                tester.getRect(find.byKey(const ValueKey('puzzle-board'))),
                board,
              );
              expect(
                tester.getRect(find.byKey(const ValueKey('shared-navigation'))),
                dock,
              );
              expect(game.puzzle, same(puzzle));
              expect(game.mode, mode);
              expect(game.moves, moves);
              expect(game.canUndo, isTrue);
              expect(
                puzzle.tiles.map((tile) => tile.rotation),
                orderedEquals(rotations),
              );
              expect(
                tester
                    .widget<LaunchCountdown>(find.byType(LaunchCountdown))
                    .remaining,
                remaining,
              );
              await game.flush();
              expect(saved, snapshot);
            }
          }
        },
      );
    }
  }
}

class _FoldCase {
  const _FoldCase(
    this.label,
    this.size,
    this.crease, {
    required this.horizontal,
    required this.platform,
    this.insets = EdgeInsets.zero,
    this.occlusions = const [],
  });

  final String label;
  final Size size;
  final Rect crease;
  final bool horizontal;
  final TargetPlatform platform;
  final EdgeInsets insets;
  final List<Rect> occlusions;

  Rect get gutter => horizontal
      ? Rect.fromLTWH(0, crease.center.dy - 20, size.width, 40)
      : Rect.fromLTWH(crease.center.dx - 20, 0, 40, size.height);
}

void _configure(WidgetTester tester, _FoldCase scenario, double scale) {
  debugDefaultTargetPlatformOverride = scenario.platform;
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = scenario.size * 3;
  tester.view.padding = FakeViewPadding(
    top: scenario.insets.top * 3,
    bottom: scenario.insets.bottom * 3,
    left: scenario.insets.left * 3,
    right: scenario.insets.right * 3,
  );
  tester.view.viewPadding = tester.view.padding;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetDisplayFeatures);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void _setPosture(
  WidgetTester tester,
  ValueNotifier<FoldGeometry> geometry,
  _FoldCase scenario, {
  required bool halfOpen,
}) {
  if (scenario.platform == TargetPlatform.android) {
    tester.view.displayFeatures = [
      DisplayFeature(
        bounds: scenario.crease,
        type: DisplayFeatureType.fold,
        state: halfOpen
            ? DisplayFeatureState.postureHalfOpened
            : DisplayFeatureState.postureFlat,
      ),
    ];
    return;
  }
  geometry.value = FoldGeometry(
    viewport: scenario.size,
    divisions: halfOpen ? [scenario.gutter] : const [],
    layoutDivisions: [halfOpen ? scenario.gutter : scenario.crease],
    occlusions: scenario.occlusions,
    supported: true,
    status: halfOpen ? HingePosture.partiallyOpen : HingePosture.fullyOpen,
  );
}

void _fits(WidgetTester tester, GameController game, _FoldCase scenario) {
  final mission = find.byKey(
    ValueKey(scenario.horizontal ? 'fold-mission-top' : 'fold-mission-side'),
  );
  final play = find.byKey(
    ValueKey(scenario.horizontal ? 'fold-play-bottom' : 'fold-play-side'),
  );
  final safe = scenario.insets.deflateRect(Offset.zero & scenario.size);
  final missionBounds = scenario.horizontal
      ? Rect.fromLTRB(safe.left, safe.top, safe.right, scenario.gutter.top)
      : Rect.fromLTRB(safe.left, safe.top, scenario.gutter.left, safe.bottom);
  final playBounds = scenario.horizontal
      ? Rect.fromLTRB(
          safe.left,
          scenario.gutter.bottom,
          safe.right,
          safe.bottom,
        )
      : Rect.fromLTRB(scenario.gutter.right, safe.top, safe.right, safe.bottom);
  _inside(tester, mission, missionBounds);
  _inside(tester, play, playBounds);
  _inside(tester, find.byType(PuzzleBoard), playBounds);
  _inside(tester, find.byType(LaunchCountdown), missionBounds);
  expect(
    find.descendant(of: mission, matching: find.byType(VoyageExplorer)),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('fold-hinge-gap')), findsOneWidget);
  for (final key in [
    'hint',
    'undo',
    'mode-journey',
    'mode-daily',
    'mode-weekly',
    'open-help',
    'open-settings',
  ]) {
    final control = find.byKey(ValueKey(key));
    _inside(tester, control, safe, touch: true);
    final rect = tester.getRect(control);
    expect(rect.shortestSide, greaterThanOrEqualTo(48 - .001), reason: key);
    expect(rect.overlaps(scenario.gutter), isFalse, reason: key);
    for (final occlusion in scenario.occlusions) {
      expect(rect.overlaps(occlusion), isFalse, reason: key);
    }
  }
  for (var index = 0; index < game.puzzle.tiles.length; index++) {
    final tile = find.byKey(ValueKey('tile-$index'));
    _inside(tester, tile, playBounds, touch: true);
    expect(tester.getSize(tile).shortestSide, greaterThanOrEqualTo(48 - .001));
  }
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    expect(state.position.maxScrollExtent, lessThanOrEqualTo(.01));
  }
  expect(tester.takeException(), isNull);
}

void _inside(
  WidgetTester tester,
  Finder finder,
  Rect bounds, {
  bool touch = false,
}) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(
    bounds.inflate(.01).contains(rect.topLeft),
    isTrue,
    reason: '$finder $rect',
  );
  expect(
    bounds.inflate(.01).contains(rect.bottomRight),
    isTrue,
    reason: '$finder $rect',
  );
  if (touch) expect(finder.hitTestable(), findsOneWidget);
}
