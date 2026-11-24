import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/services/fold_posture.dart';
import 'package:glowpath/ui/fold_layout.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = bool.fromEnvironment('CAPTURE_FOLD_SURFACES');
const _boundary = ValueKey('fold-surfaces-capture');
const _cases = [
  (name: 'book', size: Size(951, 669), crease: Rect.fromLTWH(475.5, 0, 0, 669)),
  (
    name: 'tabletop',
    size: Size(669, 951),
    crease: Rect.fromLTWH(0, 475.5, 669, 0),
  ),
  (name: 'flip', size: Size(393, 852), crease: Rect.fromLTWH(0, 426, 393, 0)),
];

void main() {
  setUpAll(() async {
    for (final font in {
      'Manrope': 'assets/fonts/Manrope-VariableFont_wght.ttf',
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final entry in _cases) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        '${entry.name} ${scale}x home, panels and restart respect both halves',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = entry.size;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.view.viewPadding = tester.view.padding;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          SharedPreferences.setMockInitialValues({'journeyLevel': 92});
          final game = GameController(
            preferences: await SharedPreferences.getInstance(),
            now: () => DateTime.utc(2026, 11, 24, 12),
            snapshotWriter: (_) => SynchronousFuture(true),
          );
          await game.load();
          await game.flush();
          addTearDown(game.dispose);
          final geometry = ValueNotifier(
            FoldGeometry(
              viewport: entry.size,
              divisions: [entry.crease],
              layoutDivisions: [entry.crease],
              status: HingePosture.partiallyOpen,
              supported: true,
            ),
          );
          addTearDown(geometry.dispose);
          final media = MediaQueryData(
            size: entry.size,
            padding: const EdgeInsets.symmetric(vertical: 24),
          );
          final panes = FoldPaneLayout.resolve(media, geometry.value)!;
          await tester.pumpWidget(
            RepaintBoundary(
              key: _boundary,
              child: GlowpathApp(
                controller: game,
                ambientMotion: false,
                showBriefings: false,
                startOnVoyage: true,
                clockNow: () => Duration.zero,
                foldGeometry: geometry,
              ),
            ),
          );
          await tester.pumpAndSettle();
          _inside(
            tester,
            find.byKey(const ValueKey('fold-home-map')),
            panes.missionRect,
          );
          for (final key in [
            'next-puzzle',
            'open-rewards',
            'voyage-route-log',
            'open-settings',
            'open-help',
          ]) {
            _inside(tester, find.byKey(ValueKey(key)), panes.actionRect);
          }
          expect(find.byType(VoyageExplorer), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _snapshot(tester, '${entry.name}-$scale-home');
          await tester.tap(find.byKey(const ValueKey('open-settings')));
          await tester.pumpAndSettle();
          _panel(tester, panes);
          await _snapshot(tester, '${entry.name}-$scale-settings');
          // A panel already on screen must respond to a posture change without
          // being reopened, or briefly retaining a hinge-crossing sheet.
          geometry.value = FoldGeometry(
            viewport: entry.size,
            layoutDivisions: [entry.crease],
            status: HingePosture.fullyOpen,
            supported: true,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('fold-panel-action')), findsNothing);
          geometry.value = FoldGeometry(
            viewport: entry.size,
            divisions: [entry.crease],
            layoutDivisions: [entry.crease],
            status: HingePosture.partiallyOpen,
            supported: true,
          );
          await tester.pumpAndSettle();
          _panel(tester, panes);
          await _close(tester);
          for (final key in ['open-help', 'open-rewards', 'voyage-route-log']) {
            await tester.tap(find.byKey(ValueKey(key)));
            await tester.pumpAndSettle();
            _panel(tester, panes);
            await _snapshot(tester, '${entry.name}-$scale-$key');
            await _close(tester);
          }
          await tester.tap(find.byKey(const ValueKey('next-puzzle')));
          await tester.pumpAndSettle();
          _inside(tester, find.byType(PuzzleBoard), panes.actionRect);
          await tester.tap(
            find.byKey(
              ValueKey(
                'tile-${game.puzzle.tiles.indexWhere((tile) => !tile.isLocked)}',
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('open-settings')));
          await tester.pumpAndSettle();
          final puzzle = game.puzzle;
          await tester.tap(find.byKey(const ValueKey('restart')));
          await tester.pumpAndSettle();
          _inside(
            tester,
            find.byKey(const ValueKey('confirm-restart')),
            panes.actionRect,
          );
          _inside(
            tester,
            find.byKey(const ValueKey('cancel-restart')),
            panes.actionRect,
          );
          await _snapshot(tester, '${entry.name}-$scale-restart');
          await tester.tap(find.byKey(const ValueKey('cancel-restart')));
          await tester.pumpAndSettle();
          expect(identical(game.puzzle, puzzle), isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

void _panel(WidgetTester tester, FoldPaneLayout panes) {
  _inside(
    tester,
    find.byKey(const ValueKey('fold-panel-action')),
    panes.actionRect,
  );
  _inside(
    tester,
    find.byKey(const ValueKey('fold-panel-companion')),
    panes.missionRect,
  );
  expect(tester.takeException(), isNull);
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Close').last);
  await tester.pumpAndSettle();
}

void _inside(WidgetTester tester, Finder finder, Rect pane) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(
    pane.inflate(.1).contains(rect.topLeft),
    isTrue,
    reason: '$finder $rect outside $pane',
  );
  expect(
    pane.inflate(.1).contains(rect.bottomRight),
    isTrue,
    reason: '$finder $rect outside $pane',
  );
}

Future<void> _snapshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final output = Directory('build/review/fold-surfaces');
    await output.create(recursive: true);
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${output.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
