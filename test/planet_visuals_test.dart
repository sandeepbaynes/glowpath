import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/mission_briefing.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

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
    const Size(820, 1180),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('first-flight conversation fits $size at $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var starts = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: MissionBriefing(
                        onStart: () => starts++,
                        reduceMotion: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        final action = find.byKey(const ValueKey('briefing-start'));
        expect(action.hitTestable(), findsOneWidget);
        if (scale == 1) {
          expect(tester.widget<SpaceAction>(action).label, "Let's fly");
          await tester.tap(action);
        } else {
          final chunks = <String>[];
          for (var page = 0; page < 50 && starts == 0; page++) {
            final copy = find.byKey(const ValueKey('briefing-copy'));
            chunks.add(tester.widget<Text>(copy).data!);
            final paragraph = tester.renderObject<RenderParagraph>(copy);
            expect(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width),
              lessThanOrEqualTo(paragraph.size.height + .01),
            );
            final actionBounds = tester.getRect(action);
            expect(action.hitTestable(), findsOneWidget);
            expect(actionBounds.top, greaterThanOrEqualTo(0));
            expect(actionBounds.bottom, lessThanOrEqualTo(size.height));
            expect(actionBounds.height, greaterThanOrEqualTo(48));
            final finalPage =
                tester.widget<SpaceAction>(action).label == "Let's fly";
            expect(
              tester.widget<SpaceAction>(action).label,
              finalPage ? "Let's fly" : 'Next',
            );
            await tester.tap(action);
            await tester.pump();
            expect(starts, finalPage ? 1 : 0);
            expect(tester.takeException(), isNull);
          }
          expect(
            chunks.join('').replaceAll(RegExp(r'\s'), ''),
            firstFlightBriefing
                .map((beat) => beat.text)
                .join('')
                .replaceAll(RegExp(r'\s'), ''),
          );
        }
        expect(starts, 1);
        expect(find.byType(Scrollable), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [
    const Size(288, 320),
    const Size(343, 540),
    const Size(552, 900),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('bounded planet map stays scroll-free at $size / $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VoyageMap(
                      completedRoutes: 8249,
                      reduceMotion: true,
                      onContinue: _noop,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        expect(find.byType(SpaceAction).hitTestable(), findsOneWidget);
        final current = VoyageWorld.forLevel(8250);
        expect(
          find.bySemanticsLabel(
            '${current.name}. Current destination. 14 of 15 routes charted.${current.isBlackHole ? ' Black hole.' : ''}',
          ),
          findsOneWidget,
        );
        semantics.dispose();
      });
    }
  }

  testWidgets(
    'actual start and finish tiles are clearly marked on a small board',
    (tester) async {
      final puzzle = Puzzle.generate(seed: 92);
      await tester.pumpWidget(_board(puzzle));
      expect(find.byKey(const ValueKey('launch-marker')), findsOneWidget);
      expect(find.byKey(const ValueKey('dock-marker')), findsOneWidget);
      final start = find.byKey(
        ValueKey('tile-${puzzle.startRow * puzzle.size}'),
      );
      final end = find.byKey(
        ValueKey('tile-${puzzle.endRow * puzzle.size + puzzle.size - 1}'),
      );
      expect(
        find.descendant(of: start, matching: find.text('START')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: end, matching: find.text('FINISH')),
        findsOneWidget,
      );
      for (var index = 0; index < puzzle.tiles.length; index++) {
        expect(
          tester.getSize(find.byKey(ValueKey('tile-$index'))).width,
          greaterThanOrEqualTo(48),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'every obstacle has a named accessible rule and fits a 48px tile',
    (tester) async {
      final base = Puzzle.generate(seed: 92);
      final tiles = base.tiles.toList();
      for (var index = 0; index < TileKind.values.length; index++) {
        final kind = TileKind.values[index];
        tiles[index] = Tile(
          baseMask: kind == TileKind.bridge || kind == TileKind.crossway
              ? 15
              : north | east,
          kind: kind,
          couplingGroup: index < 2 ? 1 : 0,
          portalPeer: kind == TileKind.wormhole ? 20 : null,
          gravityPeer: kind == TileKind.fork ? 5 : null,
          circuit: 1,
        );
      }
      final puzzle = base.copyWithTiles(tiles);
      await tester.pumpWidget(_board(puzzle));
      for (var index = 0; index < TileKind.values.length; index++) {
        final tile = find.byKey(ValueKey('tile-$index'));
        expect(
          tester.getSemantics(tile).getSemanticsData().label,
          contains(tiles[index].mechanicLabel),
        );
      }
      expect(
        missionRulesFor(puzzle).map((rule) => rule.title),
        containsAll([
          'Overpass bridges',
          'Crossways',
          'Paired wormholes',
          'Defense circuits',
        ]),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('touching a tile does not leave a keyboard focus highlight', (
    tester,
  ) async {
    final before = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    addTearDown(() => FocusManager.instance.highlightStrategy = before);
    final puzzle = Puzzle.generate(seed: 92);
    await tester.pumpWidget(_board(puzzle));
    final first = find.byKey(const ValueKey('tile-0'));
    await tester.tap(first);
    await tester.pumpAndSettle();
    final boxes = tester.widgetList<DecoratedBox>(
      find.descendant(of: first, matching: find.byType(DecoratedBox)),
    );
    final tileBox = boxes.firstWhere(
      (box) =>
          box.decoration is BoxDecoration &&
          (box.decoration as BoxDecoration).gradient != null,
    );
    expect(
      ((tileBox.decoration as BoxDecoration).border! as Border).top.width,
      1,
    );
  });

  testWidgets('coupled gravity marks do not overlap on a 48px tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 48,
              child: PipeTile(
                tile: const Tile(
                  baseMask: north | east | south,
                  kind: TileKind.blackHole,
                  couplingGroup: 2,
                ),
                index: 18,
                lit: false,
                couplingSize: 3,
                star: false,
                entrance: false,
                exit: false,
                teach: false,
                enabled: true,
                reduceMotion: true,
                highContrast: false,
                onTurn: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .getRect(find.text('3B'))
          .overlaps(tester.getRect(find.text('G19'))),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected and focused orbital tabs keep their background clear', (
    tester,
  ) async {
    const key = ValueKey('tab-capture');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: const ColoredBox(
                color: Palette.paper,
                child: SizedBox(
                  width: 160,
                  height: 64,
                  child: OrbitMode(
                    label: 'Voyage',
                    selected: true,
                    onPressed: _noop,
                    reduceMotion: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> checkBackground() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final offset = (10 * image.width + 10) * 4;
      expect(
        [
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        ],
        [
          (Palette.paper.toARGB32() >> 16) & 255,
          (Palette.paper.toARGB32() >> 8) & 255,
          Palette.paper.toARGB32() & 255,
        ],
      );
      image.dispose();
    }

    await tester.runAsync(checkBackground);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.runAsync(checkBackground);
  });
}

void _noop() {}

Widget _board(Puzzle puzzle) => MaterialApp(
  theme: gameTheme(),
  home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(3)),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 276,
          child: PuzzleBoard(
            puzzle: puzzle,
            status: puzzle.evaluate(),
            onTurn: (_) {},
            reduceMotion: true,
            highContrast: false,
            compact: true,
          ),
        ),
      ),
    ),
  ),
);
