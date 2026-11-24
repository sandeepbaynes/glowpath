import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/services/fold_posture.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Root-view geometry measured from the closed iPhone Duo simulator. The
// status strip includes the time and Wi-Fi UI below the separate camera hole.
const _outerSize = Size(466, 678);
const _outerInsets = EdgeInsets.only(right: 84, bottom: 34);
const _camera = Rect.fromLTWH(399.6666667, 29.3333333, 37, 37);
const _statusArea = Rect.fromLTWH(382, 0, 84, 174);
const _expandedSize = Size(669, 951);
const _expandedInsets = EdgeInsets.only(top: 82, bottom: 34);

void main() {
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final level in [1, 92]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'closed outer display fits level $level and every mode at ${scale}x',
        (tester) async {
          _configure(tester, _outerSize, _outerInsets, scale: scale);
          final geometry = ValueNotifier(_closed());
          addTearDown(geometry.dispose);
          final game = await _game(level);
          await tester.pumpWidget(_app(game, geometry));
          await tester.pumpAndSettle();
          expect(game.puzzle.size, level == 1 ? 4 : 5);
          for (final mode in GameMode.values) {
            if (mode != GameMode.voyage) {
              await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
              await tester.pumpAndSettle();
            }
            expect(game.mode, mode);
            _closedFits(tester, game);
          }
        },
      );
    }
  }

  testWidgets('a growing status region moves only the launch rail below it', (
    tester,
  ) async {
    _configure(tester, _outerSize, _outerInsets);
    final geometry = ValueNotifier(_closed());
    addTearDown(geometry.dispose);
    final game = await _game(92);
    await tester.pumpWidget(_app(game, geometry));
    await tester.pumpAndSettle();
    final board = tester.getRect(find.byKey(const ValueKey('puzzle-board')));
    final dock = tester.getRect(
      find.byKey(const ValueKey('shared-navigation')),
    );
    const tallerStatus = Rect.fromLTWH(382, 0, 84, 210);
    geometry.value = _closed(statusArea: tallerStatus);
    await tester.pumpAndSettle();
    _closedFits(tester, game, statusArea: tallerStatus);
    expect(tester.getRect(find.byKey(const ValueKey('puzzle-board'))), board);
    expect(
      tester.getRect(find.byKey(const ValueKey('shared-navigation'))),
      dock,
    );
  });

  testWidgets('posture alone and stale geometry do not create an outer rail', (
    tester,
  ) async {
    _configure(tester, _outerSize, _outerInsets);
    final geometry = ValueNotifier(const FoldGeometry());
    addTearDown(geometry.dispose);
    final game = await _game(1);
    await tester.pumpWidget(_app(game, geometry));
    for (final value in [
      const FoldGeometry(),
      const FoldGeometry(
        viewport: _outerSize,
        status: HingePosture.closed,
        supported: true,
      ),
      const FoldGeometry(
        viewport: _outerSize,
        status: HingePosture.fullyOpen,
        supported: true,
        occlusions: [_camera, _statusArea],
      ),
      const FoldGeometry(
        viewport: _expandedSize,
        status: HingePosture.closed,
        supported: true,
        occlusions: [_camera, _statusArea],
      ),
      const FoldGeometry(
        viewport: _outerSize,
        status: HingePosture.unavailable,
        supported: false,
        occlusions: [_camera, _statusArea],
      ),
    ]) {
      geometry.value = value;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('closed-fold-flight')), findsNothing);
      expect(find.byKey(const ValueKey('cutout-beacon')), findsNothing);
      expect(
        tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).vertical,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final mode in GameMode.values) {
    testWidgets(
      'closing and unfolding preserve the edited ${mode.name} route',
      (tester) async {
        _configure(tester, _expandedSize, _expandedInsets);
        final geometry = ValueNotifier(
          const FoldGeometry(
            viewport: _expandedSize,
            supported: true,
            status: HingePosture.fullyOpen,
            occlusions: [Rect.fromLTWH(525, 0, 144, 82)],
          ),
        );
        addTearDown(geometry.dispose);
        String? saved;
        final game = await _game(
          92,
          writer: (value) {
            saved = value;
            return SynchronousFuture(true);
          },
        );
        await tester.pumpWidget(_app(game, geometry));
        await tester.pumpAndSettle();
        if (mode != GameMode.voyage) {
          await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
          await tester.pumpAndSettle();
        }
        final movable = game.puzzle.tiles.indexWhere((tile) => !tile.isLocked);
        await tester.tap(find.byKey(ValueKey('tile-$movable')));
        await tester.pumpAndSettle();
        final puzzle = game.puzzle;
        final rotations = puzzle.tiles.map((tile) => tile.rotation).toList();
        final moves = game.moves;
        final remaining = tester
            .widget<LaunchCountdown>(find.byType(LaunchCountdown))
            .remaining;
        await game.flush();
        final before = saved;

        // Native geometry can arrive before Flutter viewport metrics during a
        // fold. Never apply the old coordinates to the new display.
        geometry.value = _closed();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('closed-fold-flight')), findsNothing);
        _setMetrics(tester, _outerSize, _outerInsets);
        await tester.pumpAndSettle();
        _closedFits(tester, game);
        expect(
          tester
              .widget<LaunchCountdown>(find.byType(LaunchCountdown))
              .remaining,
          remaining,
        );

        _setMetrics(tester, _expandedSize, _expandedInsets);
        geometry.value = const FoldGeometry(
          viewport: _expandedSize,
          supported: true,
          status: HingePosture.fullyOpen,
          occlusions: [Rect.fromLTWH(525, 0, 144, 82)],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('closed-fold-flight')), findsNothing);
        expect(
          tester.widget<LaunchCountdown>(find.byType(LaunchCountdown)).vertical,
          isFalse,
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
        expect(saved, before);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

FoldGeometry _closed({Rect statusArea = _statusArea}) => FoldGeometry(
  viewport: _outerSize,
  supported: true,
  status: HingePosture.closed,
  occlusions: [_camera, statusArea],
);

void _configure(
  WidgetTester tester,
  Size size,
  EdgeInsets insets, {
  double scale = 1,
}) {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  tester.view.devicePixelRatio = 3;
  _setMetrics(tester, size, insets);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void _setMetrics(WidgetTester tester, Size size, EdgeInsets insets) {
  tester.view.physicalSize = size * 3;
  tester.view.padding = FakeViewPadding(
    left: insets.left * 3,
    top: insets.top * 3,
    right: insets.right * 3,
    bottom: insets.bottom * 3,
  );
  tester.view.viewPadding = tester.view.padding;
}

Future<GameController> _game(
  int level, {
  Future<bool> Function(String)? writer,
}) async {
  SharedPreferences.setMockInitialValues({'journeyLevel': level});
  final game = GameController(
    preferences: await SharedPreferences.getInstance(),
    now: () => DateTime.utc(2026, 11, 24, 12),
    snapshotWriter: writer ?? (_) => SynchronousFuture(true),
  );
  await game.load();
  await game.flush();
  addTearDown(game.dispose);
  return game;
}

Widget _app(GameController game, ValueListenable<FoldGeometry> geometry) =>
    GlowpathApp(
      controller: game,
      showBriefings: false,
      ambientMotion: false,
      clockNow: () => Duration.zero,
      foldGeometry: geometry,
    );

void _closedFits(
  WidgetTester tester,
  GameController game, {
  Rect statusArea = _statusArea,
}) {
  final frame = find.byKey(const ValueKey('closed-fold-flight'));
  final main = find.byKey(const ValueKey('closed-fold-main'));
  final rail = find.byKey(const ValueKey('closed-fold-launch-rail'));
  final clock = find.byType(LaunchCountdown);
  final board = find.byKey(const ValueKey('puzzle-board'));
  final legend = find.byType(PuzzleLegend);
  expect(frame, findsOneWidget);
  expect(main, findsOneWidget);
  expect(rail, findsOneWidget);
  expect(clock, findsOneWidget);
  expect(tester.widget<LaunchCountdown>(clock).vertical, isTrue);
  final viewport = const Rect.fromLTWH(0, 0, 466, 644);
  _inside(tester, main, viewport);
  _inside(tester, rail, viewport);
  final railRect = tester.getRect(rail);
  expect(railRect.left, greaterThanOrEqualTo(statusArea.left - .01));
  expect(railRect.top, greaterThanOrEqualTo(statusArea.bottom - .01));
  final readout = tester.getRect(find.byKey(const ValueKey('launch-seconds')));
  expect(readout.top, greaterThanOrEqualTo(statusArea.bottom - .01));
  expect(readout.top - statusArea.bottom, lessThanOrEqualTo(60));
  _inside(tester, board, tester.getRect(main));
  _inside(tester, legend, tester.getRect(main));
  expect(
    tester.getRect(legend).bottom,
    lessThanOrEqualTo(tester.getRect(board).top + .01),
  );
  expect(tester.getRect(board).right, lessThanOrEqualTo(statusArea.left + .01));

  for (final key in [
    'open-atlas',
    'hint',
    'undo',
    'mode-journey',
    'mode-daily',
    'mode-weekly',
    'open-help',
    'open-settings',
  ]) {
    final control = find.byKey(ValueKey(key));
    _inside(tester, control, viewport, touch: true);
    final rect = tester.getRect(control);
    expect(rect.shortestSide, greaterThanOrEqualTo(48 - .001), reason: key);
    expect(rect.overlaps(statusArea), isFalse, reason: key);
    expect(rect.overlaps(_camera), isFalse, reason: key);
    expect(rect.overlaps(railRect), isFalse, reason: key);
  }
  for (var index = 0; index < game.puzzle.tiles.length; index++) {
    final tile = find.byKey(ValueKey('tile-$index'));
    _inside(tester, tile, tester.getRect(board), touch: true);
    expect(tester.getSize(tile).shortestSide, greaterThanOrEqualTo(48 - .001));
  }
  final beacon = find.byKey(const ValueKey('cutout-beacon'));
  expect(beacon, findsOneWidget);
  // The decoration must not absorb the touch stream from the board or controls.
  expect(
    find
            .ancestor(of: beacon, matching: find.byType(IgnorePointer))
            .evaluate()
            .isNotEmpty ||
        tester.widget(beacon) is IgnorePointer ||
        find
            .descendant(of: beacon, matching: find.byType(IgnorePointer))
            .evaluate()
            .isNotEmpty,
    isTrue,
  );
  expect(
    find.descendant(of: beacon, matching: find.byType(ExcludeSemantics)),
    findsOneWidget,
  );
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
  expect(bounds.inflate(.01).contains(rect.topLeft), isTrue, reason: '$finder');
  expect(
    bounds.inflate(.01).contains(rect.bottomRight),
    isTrue,
    reason: '$finder',
  );
  if (touch) expect(finder.hitTestable(), findsOneWidget);
}
