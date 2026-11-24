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

// Local Xcode evidence, not assumed device specifications:
// /Library/Developer/CoreSimulator/Profiles/DeviceTypes/
// iPhone Duo.simdevicetype/Contents/Resources/capabilities.plist
// primary: 1398×2034 @3; primary-1: 2007×2853 @3, native rotation 270.
// Exercise both orientations. This profile does not publish safe-area insets.
const _duoViewports = [
  Size(466, 678),
  Size(678, 466),
  Size(669, 951),
  Size(951, 669),
];

// Synthetic active divisions exercise the public geometry contract. These
// gaps are test inputs, not a claim about the device's physical hinge width.
const _tabletopCases = [
  (
    size: Size(951, 669),
    hinge: Rect.fromLTWH(0, 326.5, 951, 16),
    horizontal: true,
  ),
  (
    size: Size(669, 951),
    hinge: Rect.fromLTWH(0, 467.5, 669, 16),
    horizontal: true,
  ),
  (
    size: Size(951, 669),
    hinge: Rect.fromLTWH(467.5, 0, 16, 669),
    horizontal: false,
  ),
  (
    size: Size(669, 951),
    hinge: Rect.fromLTWH(326.5, 0, 16, 951),
    horizontal: false,
  ),
];

// Observed from the running iPhone Duo simulator's native root view on
// 2026-11-24. Unlike the synthetic cases, these include its actual safe areas,
// reserved division margin and camera occlusion.
const _observedTabletop = (
  size: Size(669, 951),
  hinge: Rect.fromLTWH(0, 455.5, 669, 40),
  horizontal: true,
);
const _observedTabletopInsets = EdgeInsets.only(top: 82, bottom: 34);
const _observedTabletopOcclusion = Rect.fromLTWH(525, 0, 144, 82);
const _observedBook = (
  size: Size(951, 669),
  hinge: Rect.fromLTWH(455.5, 0, 40, 669),
  horizontal: false,
);
const _observedBookInsets = EdgeInsets.only(right: 84, bottom: 34);
const _observedBookOcclusion = Rect.fromLTWH(827, 585, 124, 84);

void main() {
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final size in _duoViewports) {
    for (final textScale in [1.0, 1.5]) {
      testWidgets('Duo $size at ${textScale}x fits map and every play mode', (
        tester,
      ) async {
        _configureView(tester, size, textScale: textScale);
        final game = await _loadGame(tester);
        await tester.pumpWidget(_app(game));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-atlas')));
        await tester.pumpAndSettle();
        final mapDock = _navigation(tester, size);
        final mapContent = Rect.fromLTRB(0, 0, size.width, mapDock.top);
        for (final key in ['next-puzzle', 'voyage-route-log', 'open-rewards']) {
          _inside(tester, find.byKey(ValueKey(key)), mapContent, touch: true);
        }
        expect(
          tester.getRect(find.byKey(const ValueKey('next-stop-flight'))),
          Offset.zero & size,
        );
        _noScroll(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('next-puzzle')));
        await tester.pumpAndSettle();

        for (final mode in GameMode.values) {
          if (mode != GameMode.voyage) {
            await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
            await tester.pumpAndSettle();
          }
          expect(game.mode, mode);
          _playFits(tester, game, size);
        }
      });
    }
  }

  for (final mode in GameMode.values) {
    testWidgets('Duo fold and rotation preserve the saved ${mode.name} route', (
      tester,
    ) async {
      _configureView(tester, _duoViewports.first);
      String? savedSnapshot;
      final game = await _loadGame(
        tester,
        snapshotWriter: (snapshot) {
          savedSnapshot = snapshot;
          return SynchronousFuture(true);
        },
      );
      await tester.pumpWidget(_app(game));
      await tester.pumpAndSettle();
      if (mode != GameMode.voyage) {
        await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
        await tester.pumpAndSettle();
      }
      final movable = game.puzzle.tiles.indexWhere((tile) => !tile.isLocked);
      await tester.tap(find.byKey(ValueKey('tile-$movable')));
      await tester.pumpAndSettle();
      expect(game.moves, 1);
      expect(game.canUndo, isTrue);
      final puzzle = game.puzzle;
      final rotations = puzzle.tiles.map((tile) => tile.rotation).toList();
      final countdown = tester
          .widget<LaunchCountdown>(find.byType(LaunchCountdown))
          .remaining;
      await game.flush();
      final saved = savedSnapshot;
      expect(saved, isNotNull);

      // Resize the same mounted app/controller. Recreating the app per size
      // would miss state loss while unfolding or rotating an active puzzle.
      for (final size in [
        _duoViewports[3],
        _duoViewports[2],
        _duoViewports[1],
        _duoViewports[0],
      ]) {
        tester.view.physicalSize = size * 3;
        await tester.pumpAndSettle();
        _playFits(tester, game, size);
        expect(game.puzzle, same(puzzle));
        expect(game.mode, mode);
        expect(game.moves, 1);
        expect(game.canUndo, isTrue);
        expect(
          tester
              .widget<PuzzleBoard>(find.byType(PuzzleBoard))
              .puzzle
              .tiles
              .map((tile) => tile.rotation),
          orderedEquals(rotations),
        );
        expect(
          tester
              .widget<LaunchCountdown>(find.byType(LaunchCountdown))
              .remaining,
          countdown,
        );
      }
      await game.flush();
      expect(savedSnapshot, saved);
      SharedPreferences.setMockInitialValues({
        GameController.storageKey: saved!,
      });
      final restored = GameController(
        preferences: await SharedPreferences.getInstance(),
        now: () => DateTime.utc(2026, 11, 24, 12),
        snapshotWriter: (_) => SynchronousFuture(true),
      );
      addTearDown(restored.dispose);
      await restored.load();
      await restored.flush();
      expect(restored.mode, mode);
      expect(restored.moves, 1);
      expect(restored.puzzle.seed, puzzle.seed);
      expect(
        restored.puzzle.tiles.map((tile) => tile.rotation),
        orderedEquals(rotations),
      );
    });
  }

  for (final entry in _tabletopCases) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'active ${entry.horizontal ? 'horizontal' : 'vertical'} fold at '
        '${entry.size} and ${scale}x separates mission and playable board',
        (tester) async {
          _configureView(tester, entry.size, textScale: scale);
          final geometry = ValueNotifier(_fold(entry.size, entry.hinge));
          addTearDown(geometry.dispose);
          final game = await _loadGame(tester);
          await tester.pumpWidget(_app(game, foldGeometry: geometry));
          await tester.pumpAndSettle();
          for (final mode in GameMode.values) {
            if (mode != GameMode.voyage) {
              await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
              await tester.pumpAndSettle();
            }
            expect(game.mode, mode);
            _foldFits(tester, game, entry);
          }
        },
      );
    }
  }

  for (final observed in [
    (
      label: 'tabletop',
      entry: _observedTabletop,
      insets: _observedTabletopInsets,
      occlusion: _observedTabletopOcclusion,
    ),
    (
      label: 'book',
      entry: _observedBook,
      insets: _observedBookInsets,
      occlusion: _observedBookOcclusion,
    ),
  ]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'observed Duo ${observed.label} safe areas fit level92 and all modes at ${scale}x',
        (tester) async {
          _configureView(
            tester,
            observed.entry.size,
            textScale: scale,
            insets: observed.insets,
          );
          final geometry = ValueNotifier(
            FoldGeometry(
              viewport: observed.entry.size,
              divisions: [observed.entry.hinge],
              occlusions: [observed.occlusion],
              status: HingePosture.partiallyOpen,
              supported: true,
            ),
          );
          addTearDown(geometry.dispose);
          final game = await _loadGame(tester, journeyLevel: 92);
          await tester.pumpWidget(_app(game, foldGeometry: geometry));
          await tester.pumpAndSettle();
          expect(game.puzzle.levelNumber, 92);
          expect(game.puzzle.size, 5);
          for (final mode in GameMode.values) {
            if (mode != GameMode.voyage) {
              await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
              await tester.pumpAndSettle();
            }
            _foldFits(
              tester,
              game,
              observed.entry,
              insets: observed.insets,
              occlusions: [observed.occlusion],
            );
          }
        },
      );
    }
  }

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'observed expanded portrait safe areas fit level92 at ${scale}x',
      (tester) async {
        _configureView(
          tester,
          _observedTabletop.size,
          textScale: scale,
          insets: _observedTabletopInsets,
        );
        final geometry = ValueNotifier(
          FoldGeometry(
            viewport: _observedTabletop.size,
            status: HingePosture.fullyOpen,
            supported: true,
          ),
        );
        addTearDown(geometry.dispose);
        final game = await _loadGame(tester, journeyLevel: 92);
        await tester.pumpWidget(_app(game, foldGeometry: geometry));
        await tester.pumpAndSettle();
        for (final mode in GameMode.values) {
          if (mode != GameMode.voyage) {
            await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
            await tester.pumpAndSettle();
          }
          _playFits(
            tester,
            game,
            _observedTabletop.size,
            insets: _observedTabletopInsets,
          );
        }
      },
    );
  }

  testWidgets('posture alone never invents an active hinge or split layout', (
    tester,
  ) async {
    const size = Size(951, 669);
    _configureView(tester, size);
    final geometry = ValueNotifier(const FoldGeometry());
    addTearDown(geometry.dispose);
    final game = await _loadGame(tester);
    await tester.pumpWidget(_app(game, foldGeometry: geometry));
    await tester.pumpAndSettle();
    for (final status in HingePosture.values) {
      geometry.value = FoldGeometry(
        viewport: size,
        status: status,
        supported: true,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('fold-mission-top')), findsNothing);
      expect(find.byKey(const ValueKey('fold-mission-side')), findsNothing);
      _playFits(tester, game, size);
    }
  });

  for (final mode in GameMode.values) {
    testWidgets(
      'active posture changes preserve the edited ${mode.name} route',
      (tester) async {
        final horizontal = _tabletopCases[0];
        final vertical = _tabletopCases[3];
        _configureView(tester, horizontal.size);
        final geometry = ValueNotifier(const FoldGeometry());
        addTearDown(geometry.dispose);
        String? snapshot;
        final game = await _loadGame(
          tester,
          snapshotWriter: (value) {
            snapshot = value;
            return SynchronousFuture(true);
          },
        );
        await tester.pumpWidget(_app(game, foldGeometry: geometry));
        await tester.pumpAndSettle();
        if (mode != GameMode.voyage) {
          await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
          await tester.pumpAndSettle();
        }
        final movable = game.puzzle.tiles.indexWhere((tile) => !tile.isLocked);
        await tester.tap(find.byKey(ValueKey('tile-$movable')));
        await tester.pumpAndSettle();
        final puzzle = game.puzzle;
        final moves = game.moves;
        final remaining = tester
            .widget<LaunchCountdown>(find.byType(LaunchCountdown))
            .remaining;
        await game.flush();
        final before = snapshot;

        geometry.value = _fold(horizontal.size, horizontal.hinge);
        await tester.pumpAndSettle();
        _foldFits(tester, game, horizontal);
        geometry.value = _fold(vertical.size, vertical.hinge);
        await tester.pumpAndSettle();
        // A native orientation update may precede the Flutter metrics update.
        // Stale coordinates must not split the current screen in the wrong place.
        expect(find.byKey(const ValueKey('fold-mission-top')), findsNothing);
        expect(find.byKey(const ValueKey('fold-mission-side')), findsNothing);
        tester.view.physicalSize = vertical.size * 3;
        await tester.pumpAndSettle();
        _foldFits(tester, game, vertical);
        geometry.value = FoldGeometry(
          viewport: vertical.size,
          status: HingePosture.fullyOpen,
          supported: true,
        );
        await tester.pumpAndSettle();
        _playFits(tester, game, vertical.size);
        expect(game.puzzle, same(puzzle));
        expect(game.mode, mode);
        expect(game.moves, moves);
        expect(game.canUndo, isTrue);
        expect(
          tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).puzzle,
          same(puzzle),
        );
        expect(
          tester
              .widget<LaunchCountdown>(find.byType(LaunchCountdown))
              .remaining,
          remaining,
        );
        await game.flush();
        expect(snapshot, before);
      },
    );
  }
}

void _configureView(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
  EdgeInsets insets = EdgeInsets.zero,
}) {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  tester.view.padding = FakeViewPadding(
    left: insets.left * 3,
    top: insets.top * 3,
    right: insets.right * 3,
    bottom: insets.bottom * 3,
  );
  tester.view.viewPadding = tester.view.padding;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<GameController> _loadGame(
  WidgetTester tester, {
  Future<bool> Function(String)? snapshotWriter,
  int journeyLevel = 31,
}) async {
  SharedPreferences.setMockInitialValues({'journeyLevel': journeyLevel});
  final game = GameController(
    preferences: await SharedPreferences.getInstance(),
    now: () => DateTime.utc(2026, 11, 24, 12),
    snapshotWriter: snapshotWriter ?? (_) => SynchronousFuture(true),
  );
  await game.load();
  await game.flush();
  addTearDown(game.dispose);
  return game;
}

Widget _app(
  GameController game, {
  ValueListenable<FoldGeometry>? foldGeometry,
}) => GlowpathApp(
  controller: game,
  showBriefings: false,
  ambientMotion: false,
  clockNow: () => Duration.zero,
  foldGeometry: foldGeometry,
);

FoldGeometry _fold(Size viewport, Rect hinge) => FoldGeometry(
  viewport: viewport,
  divisions: [hinge],
  status: HingePosture.partiallyOpen,
  supported: true,
);

void _foldFits(
  WidgetTester tester,
  GameController game,
  ({Size size, Rect hinge, bool horizontal}) entry, {
  EdgeInsets insets = EdgeInsets.zero,
  List<Rect> occlusions = const [],
}) {
  final mission = find.byKey(
    ValueKey(entry.horizontal ? 'fold-mission-top' : 'fold-mission-side'),
  );
  final play = find.byKey(
    ValueKey(entry.horizontal ? 'fold-play-bottom' : 'fold-play-side'),
  );
  final safe = insets.deflateRect(Offset.zero & entry.size);
  final missionBounds = entry.horizontal
      ? Rect.fromLTRB(safe.left, safe.top, safe.right, entry.hinge.top)
      : Rect.fromLTRB(safe.left, safe.top, entry.hinge.left, safe.bottom);
  final playBounds = entry.horizontal
      ? Rect.fromLTRB(safe.left, entry.hinge.bottom, safe.right, safe.bottom)
      : Rect.fromLTRB(entry.hinge.right, safe.top, safe.right, safe.bottom);
  _inside(tester, mission, missionBounds);
  _inside(tester, play, playBounds);
  expect(find.byKey(const ValueKey('fold-hinge-gap')), findsOneWidget);
  expect(
    find.descendant(of: mission, matching: find.byType(VoyageExplorer)),
    findsOneWidget,
  );
  _inside(tester, find.byType(LaunchCountdown), missionBounds);
  _inside(tester, find.byType(PuzzleBoard), playBounds);
  for (final occlusion in occlusions) {
    expect(
      tester.getRect(find.byType(PuzzleBoard)).overlaps(occlusion),
      isFalse,
    );
    expect(
      tester.getRect(find.byType(LaunchCountdown)).overlaps(occlusion),
      isFalse,
    );
  }
  _navigation(tester, entry.size, insets: insets);
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
    expect(
      tester.getRect(control).overlaps(entry.hinge),
      isFalse,
      reason: '$key must avoid the hinge',
    );
    for (final occlusion in occlusions) {
      expect(
        tester.getRect(control).overlaps(occlusion),
        isFalse,
        reason: '$key must avoid camera occlusion',
      );
    }
    expect(
      tester.getSize(control).shortestSide,
      greaterThanOrEqualTo(48 - .001),
    );
  }
  for (var index = 0; index < game.puzzle.tiles.length; index++) {
    final tile = find.byKey(ValueKey('tile-$index'));
    _inside(tester, tile, playBounds, touch: true);
    expect(tester.getSize(tile).shortestSide, greaterThanOrEqualTo(48 - .001));
  }
  _noScroll(tester);
  expect(tester.takeException(), isNull);
}

Rect _navigation(
  WidgetTester tester,
  Size size, {
  EdgeInsets insets = EdgeInsets.zero,
}) {
  final viewport = insets.deflateRect(Offset.zero & size);
  final dock = find.byKey(const ValueKey('shared-navigation'));
  _inside(tester, dock, viewport);
  final dockBounds = tester.getRect(dock);
  for (final key in [
    'mode-journey',
    'mode-daily',
    'mode-weekly',
    'open-help',
    'open-settings',
  ]) {
    _inside(tester, find.byKey(ValueKey(key)), dockBounds, touch: true);
  }
  return dockBounds;
}

void _playFits(
  WidgetTester tester,
  GameController game,
  Size size, {
  EdgeInsets insets = EdgeInsets.zero,
}) {
  expect(find.byKey(const ValueKey('desktop-play-frame')), findsNothing);
  final dock = _navigation(tester, size, insets: insets);
  final content = Rect.fromLTRB(
    insets.left,
    insets.top,
    size.width - insets.right,
    dock.top,
  );
  _inside(tester, find.byType(PuzzleBoard), content);
  _inside(tester, find.byType(LaunchCountdown), content);
  for (final key in ['open-atlas', 'hint', 'undo']) {
    _inside(tester, find.byKey(ValueKey(key)), content, touch: true);
  }
  for (var index = 0; index < game.puzzle.tiles.length; index++) {
    final tile = find.byKey(ValueKey('tile-$index'));
    _inside(tester, tile, content, touch: true);
    expect(tester.getSize(tile).shortestSide, greaterThanOrEqualTo(48 - .001));
  }
  _noScroll(tester);
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
  expect(bounds.inflate(.01).contains(rect.topLeft), isTrue, reason: '$finder');
  expect(
    bounds.inflate(.01).contains(rect.bottomRight),
    isTrue,
    reason: '$finder',
  );
  if (touch) expect(finder.hitTestable(), findsOneWidget);
}

void _noScroll(WidgetTester tester) {
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = (element as StatefulElement).state as ScrollableState;
    expect(state.position.maxScrollExtent, lessThanOrEqualTo(.01));
    expect(state.position.minScrollExtent, greaterThanOrEqualTo(-.01));
  }
}
