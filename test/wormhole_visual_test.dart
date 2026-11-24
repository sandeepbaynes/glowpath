import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/wormhole_transfer.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'only a source-connected ordered teleport activates its paired exit',
    () {
      final board = _portalBoard();
      final status = board.evaluate();
      expect(status.route, [3, 4, 0, 1]);
      final hop = activeWormholeHops(board, status).single;
      expect(
        (hop.entrance, hop.exit, hop.inlet, hop.outlet),
        (4, 0, west, east),
      );
      expect(
        activeWormholeHops(board.rotateAt(3), board.rotateAt(3).evaluate()),
        isEmpty,
      );
      expect(
        activeWormholeHops(
          board,
          PuzzleStatus(
            solved: false,
            litCells: {0, 4},
            collectedStars: {},
            route: [4, 0],
          ),
        ),
        isEmpty,
      );
      final invalid = board.copyWithTiles([
        for (var i = 0; i < board.tiles.length; i++)
          i == 0 ? board.tiles[i].copyWith(portalPeer: 8) : board.tiles[i],
      ]);
      expect(activeWormholeHops(invalid, invalid.evaluate()), isEmpty);
    },
  );

  test(
    'a portal arrival is not mistaken for an immediate reverse teleport',
    () {
      final board = _portalBoard();
      final status = PuzzleStatus(
        solved: false,
        litCells: {3, 4, 0},
        collectedStars: {},
        route: [3, 4, 0, 4],
      );
      expect(activeWormholeHops(board, status).map((hop) => hop.identity), [
        '4>0',
      ]);
    },
  );

  for (final extent in [48.0, 96.0, 180.0]) {
    test('wormhole channels stop outside the hole at $extent pixels', () {
      final painter = PipePainter(
        mask: east | west,
        light: 1,
        highContrast: false,
        kind: TileKind.wormhole,
        oneWayEntry: west,
        wormholePorts: west,
      );
      final paths = painter.wormholeChannels(Size.square(extent));
      expect(paths.keys, [west]);
      final metric = paths[west]!.computeMetrics().single;
      final end = metric.getTangentForOffset(metric.length)!.position;
      final center = Offset(extent / 2, extent / 2);
      expect(
        (end - center).distance,
        greaterThan((extent * .14).clamp(8, 20) + 4),
      );
      expect(end.dx, lessThan(center.dx));
    });
  }

  test(
    'active portal drawings have a real absent half, not a pipe under an icon',
    () async {
      final entry = await _pipePixels(west);
      final exit = await _pipePixels(east);
      int rgb(ByteData bytes, int x, int y) {
        final offset = (y * 96 + x) * 4;
        return bytes.getUint8(offset) << 16 |
            bytes.getUint8(offset + 1) << 8 |
            bytes.getUint8(offset + 2);
      }

      expect(rgb(entry, 84, 48), 0x122439);
      expect(rgb(entry, 12, 48), isNot(0x122439));
      expect(rgb(exit, 12, 48), 0x122439);
      expect(rgb(exit, 84, 48), isNot(0x122439));
    },
  );

  testWidgets(
    'transfer plays once per activation, extinguishes, and can reactivate',
    (tester) async {
      final active = _portalBoard();
      final broken = active.rotateAt(3);
      await tester.pumpWidget(_board(broken));
      WormholeTransferPainter transfer() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('wormhole-transfer')),
                  )
                  .painter!
              as WormholeTransferPainter;
      PipePainter pipe(int index) => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byKey(ValueKey('tile-$index')),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((widget) => widget.painter)
          .whereType<PipePainter>()
          .single;
      expect(transfer().flights, isEmpty);
      await tester.pumpWidget(_board(active));
      final first = transfer().flights['4>0']!;
      expect(first.value, 0);
      expect(pipe(4).wormholePorts, west);
      expect(pipe(0).wormholePorts, east);
      await tester.pump(const Duration(milliseconds: 300));
      final inFlight = first.value;
      expect(inFlight, inExclusiveRange(0, 1));
      final semantics = tester
          .getSemantics(find.byKey(const ValueKey('tile-0')))
          .getSemanticsData();
      expect(
        semantics.value,
        contains('Light emerges here from the paired hole'),
      );
      // Another tile changes while the connection itself remains intact.
      await tester.pumpWidget(_board(active.rotateAt(8)));
      expect(transfer().flights['4>0'], same(first));
      expect(first.value, inFlight);
      await tester.pumpAndSettle();
      expect(first.value, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(_board(active));
      expect(transfer().flights['4>0'], same(first));
      expect(
        first.value,
        1,
        reason: 'Ordinary rebuilds cannot replay the cue.',
      );
      await tester.pumpWidget(_board(broken));
      expect(transfer().flights, isEmpty);
      await tester.pumpAndSettle();
      expect(pipe(0).light, 0);
      expect(pipe(4).light, 0);
      await tester.pumpWidget(_board(active));
      final second = transfer().flights['4>0']!;
      expect(second, isNot(same(first)));
      expect(second.value, 0);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(_board(broken));
      expect(
        transfer().flights,
        isEmpty,
        reason: 'Breaks cancel even an in-flight cue.',
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion shows the lit exit without a travelling light', (
    tester,
  ) async {
    await tester.pumpWidget(_board(_portalBoard(), reduceMotion: true));
    await tester.pumpAndSettle();
    final transfer =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('wormhole-transfer')),
                )
                .painter!
            as WormholeTransferPainter;
    expect(transfer.hops, hasLength(1));
    expect(transfer.flights, isEmpty);
    final exit = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byKey(const ValueKey('tile-0')),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((widget) => widget.painter)
        .whereType<PipePainter>()
        .single;
    expect(exit.light, 1);
    expect(exit.wormholePorts, east);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}

Puzzle _portalBoard() => Puzzle.authored(
  size: 3,
  startRow: 1,
  endRow: 0,
  tiles: List.generate(
    9,
    (i) => switch (i) {
      0 => const Tile(
        baseMask: north | east,
        oneWayEntry: north,
        kind: TileKind.wormhole,
        portalPeer: 4,
      ),
      4 => const Tile(
        baseMask: east | west,
        oneWayEntry: west,
        kind: TileKind.wormhole,
        portalPeer: 0,
      ),
      1 || 3 => const Tile(baseMask: east | west),
      _ => const Tile(baseMask: north | south),
    },
  ),
  starIndices: {1, 3, 2},
);

Widget _board(Puzzle puzzle, {bool reduceMotion = false}) => MaterialApp(
  theme: gameTheme(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        child: PuzzleBoard(
          puzzle: puzzle,
          status: puzzle.evaluate(),
          onTurn: (_) {},
          reduceMotion: reduceMotion,
          highContrast: false,
        ),
      ),
    ),
  ),
);

Future<ByteData> _pipePixels(int ports) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 96, 96),
    Paint()..color = Palette.tile,
  );
  PipePainter(
    mask: east | west,
    light: 1,
    highContrast: false,
    kind: TileKind.wormhole,
    oneWayEntry: west,
    wormholePorts: ports,
  ).paint(canvas, const Size.square(96));
  final picture = recorder.endRecording();
  final image = await picture.toImage(96, 96);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return data!;
}
