import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a short touch still rotates exactly one relay', (tester) async {
    final flight = await _launch(tester);
    final original = _rotations(flight.game.puzzle);
    final cell = flight.game.puzzle.startRow * flight.game.puzzle.size;
    final finger = await tester.startGesture(_center(tester, cell));
    await finger.moveBy(const Offset(2, 2));
    await finger.up();
    await tester.pumpAndSettle();
    expect(flight.game.moves, 1);
    final after = _rotations(flight.game.puzzle);
    expect(after[cell], (original[cell] + 1) % 4);
    for (var index = 0; index < after.length; index++) {
      if (index != cell) expect(after[index], original[index]);
    }
    expect(flight.game.tracePreview, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(393, 852), const Size(1024, 1366)]) {
    testWidgets('drawing START to FINISH previews then commits at $size', (
      tester,
    ) async {
      final flight = await _launch(tester, size: size);
      final initial = _rotations(flight.game.puzzle);
      final route = flight.game.puzzle.solvedCopy().evaluate().route;
      expect(route.length, greaterThan(3));
      final finger = await tester.startGesture(_center(tester, route.first));
      for (final cell in route.skip(1)) {
        await finger.moveTo(_center(tester, cell));
        await tester.pump();
      }
      final board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
      expect(board.status.collectedStars.length, 3);
      expect(
        board.status.solved,
        isTrue,
        reason: 'The visible route connects every star to FINISH.',
      );
      expect(
        flight.game.status.solved,
        isFalse,
        reason: 'A held finger is a preview, not a completed mission.',
      );
      expect(_rotations(flight.game.puzzle), initial);
      expect(flight.game.moves, 0);
      await finger.up();
      await tester.pumpAndSettle();
      expect(flight.game.status.solved, isTrue);
      expect(flight.game.moves, greaterThan(0));
      expect(flight.game.assisted, isFalse);
      expect(flight.game.hasVerifiedReplay, isTrue);
      expect(flight.game.tracePreview, isNull);
      expect(find.byKey(const ValueKey('next-puzzle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('one fast straight swipe aligns the intervening relay', (
    tester,
  ) async {
    final flight = await _launch(tester);
    final route = flight.game.puzzle.solvedCopy().evaluate().route;
    final triple = List.generate(
      route.length - 2,
      (i) => route.sublist(i, i + 3),
    ).firstWhere((cells) => cells[1] - cells[0] == cells[2] - cells[1]);
    final horizontal = (triple[1] - triple[0]).abs() == 1;
    final expectedPorts = horizontal ? east | west : north | south;
    if (flight.game.puzzle.tiles[triple[1]].connections == expectedPorts) {
      flight.game.rotate(triple[1]);
      await tester.pumpAndSettle();
    }
    expect(
      flight.game.puzzle.tiles[triple[1]].connections,
      isNot(expectedPorts),
    );
    final finger = await tester.startGesture(_center(tester, triple.first));
    // A single pointer update traverses two tiles. Sampling must follow the
    // visible straight segment instead of jumping past its middle cell.
    await finger.moveTo(_center(tester, triple.last));
    await tester.pump();
    expect(
      tester
          .widget<PuzzleBoard>(find.byType(PuzzleBoard))
          .puzzle
          .tiles[triple[1]]
          .connections,
      expectedPorts,
    );
    await finger.up();
    await tester.pumpAndSettle();
    expect(flight.game.puzzle.tiles[triple[1]].connections, expectedPorts);
    expect(tester.takeException(), isNull);
  });

  for (final haptics in [true, false]) {
    testWidgets(
      'a blocked fixed relay rejects the drag with haptics=$haptics',
      (tester) async {
        final vibrations = <dynamic>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              vibrations.add(call.arguments);
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
        final flight = await _launch(tester, level: 16);
        flight.game.setHaptics(haptics);
        final puzzle = flight.game.puzzle;
        final fixed = puzzle.tiles.indexWhere((tile) => tile.isLocked);
        expect(fixed, greaterThanOrEqualTo(0));
        final neighbor = _neighbors(fixed, puzzle.size)
            .firstWhere(
              (entry) => puzzle.tiles[fixed].connections & entry.port == 0,
            )
            .cell;
        final original = _rotations(puzzle);
        vibrations.clear();
        final finger = await tester.startGesture(_center(tester, fixed));
        await finger.moveTo(_center(tester, neighbor));
        await tester.pump();
        expect(
          _rotations(
            tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).puzzle,
          ),
          original,
        );
        await finger.up();
        await tester.pumpAndSettle();
        expect(_rotations(flight.game.puzzle), original);
        expect(flight.game.moves, 0);
        expect(flight.game.canUndo, isFalse);
        if (haptics) {
          expect(
            vibrations,
            isNotEmpty,
            reason:
                'A blocked drag should provide the enabled tactile feedback.',
          );
        } else {
          expect(vibrations, isEmpty);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('dragging one twin turns its partner and Undo restores both', (
    tester,
  ) async {
    final flight = await _launch(tester, level: 46);
    final puzzle = flight.game.puzzle;
    final member = puzzle.tiles.indexWhere((tile) => tile.couplingGroup > 0);
    expect(member, greaterThanOrEqualTo(0));
    final group = puzzle.tiles[member].couplingGroup;
    final partner = puzzle.tiles.indexWhere(
      (tile) =>
          tile.couplingGroup == group && !identical(tile, puzzle.tiles[member]),
    );
    final neighbor = _neighbors(member, puzzle.size)
        .firstWhere(
          (entry) =>
              puzzle.tiles[member].connections & entry.port == 0 &&
              !puzzle.tiles[entry.cell].isLocked &&
              puzzle.tiles[entry.cell].couplingGroup == 0,
        )
        .cell;
    final original = _rotations(puzzle);
    final finger = await tester.startGesture(_center(tester, member));
    await finger.moveTo(_center(tester, neighbor));
    await tester.pump();
    final visible = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).puzzle;
    final turn = (visible.tiles[member].rotation - original[member]) % 4;
    expect(turn, isNot(0));
    expect((visible.tiles[partner].rotation - original[partner]) % 4, turn);
    expect(_rotations(flight.game.puzzle), original);
    await finger.up();
    await tester.pumpAndSettle();
    expect(_rotations(flight.game.puzzle), _rotations(visible));
    expect(flight.game.assisted, isFalse);
    await tester.tap(find.byKey(const ValueKey('undo')));
    await tester.pumpAndSettle();
    expect(_rotations(flight.game.puzzle), original);
    expect(flight.game.moves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding a route spends time and timeout discards the preview', (
    tester,
  ) async {
    final flight = await _launch(tester);
    final original = _rotations(flight.game.puzzle);
    final route = flight.game.puzzle.solvedCopy().evaluate().route;
    final total = flight.instrument(tester).remaining.inSeconds;
    final finger = await tester.startGesture(_center(tester, route.first));
    await finger.moveTo(_center(tester, route[1]));
    await tester.pump();
    flight.now += const Duration(seconds: 5);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      flight.instrument(tester).remaining.inSeconds,
      total - 5,
      reason: 'Tracing is play, not a pause panel.',
    );
    final laterPoint = _center(tester, route[2]);
    // Cross the deadline before the periodic timer tick. Pointer input must
    // reconcile time rather than commit a late route between display updates.
    flight.now += Duration(seconds: total);
    await finger.moveTo(laterPoint);
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(_rotations(flight.game.puzzle), original);
    expect(flight.game.moves, 0);
    expect(flight.game.tracePreview, isNull);
    expect(find.byKey(const ValueKey('retry-flight')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'backgrounding cancels a held preview without changing progress',
    (tester) async {
      final flight = await _launch(tester);
      final original = _rotations(flight.game.puzzle);
      final route = flight.game.puzzle.solvedCopy().evaluate().route;
      final finger = await tester.startGesture(_center(tester, route.first));
      await finger.moveTo(_center(tester, route[1]));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(flight.game.tracePreview, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await finger.up();
      await tester.pumpAndSettle();
      expect(_rotations(flight.game.puzzle), original);
      expect(flight.game.moves, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('retracing to the first tile erases the whole held edit', (
    tester,
  ) async {
    final flight = await _launch(tester);
    final original = _rotations(flight.game.puzzle);
    final route = flight.game.puzzle.solvedCopy().evaluate().route;
    final finger = await tester.startGesture(_center(tester, route[0]));
    await finger.moveTo(_center(tester, route[1]));
    await tester.pump();
    await finger.moveTo(_center(tester, route[2]));
    await tester.pump();
    await finger.moveTo(_center(tester, route[1]));
    await tester.pump();
    await finger.moveTo(_center(tester, route[0]));
    await tester.pump();
    expect(
      _rotations(tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).puzzle),
      original,
    );
    await finger.up();
    await tester.pumpAndSettle();
    expect(_rotations(flight.game.puzzle), original);
    expect(flight.game.moves, 0);
    expect(flight.game.canUndo, isFalse);
  });

  testWidgets('a diagonal stroke cannot invent an untraced corner', (
    tester,
  ) async {
    final flight = await _launch(tester);
    final original = _rotations(flight.game.puzzle);
    final finger = await tester.startGesture(_center(tester, 0));
    await finger.moveTo(_center(tester, flight.game.puzzle.size + 1));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(_rotations(flight.game.puzzle), original);
    expect(flight.game.moves, 0);
  });

  testWidgets(
    'a second finger cancels rather than committing a partial route',
    (tester) async {
      final flight = await _launch(tester);
      final original = _rotations(flight.game.puzzle);
      final route = flight.game.puzzle.solvedCopy().evaluate().route;
      final finger = await tester.startGesture(
        _center(tester, route[0]),
        pointer: 1,
      );
      await finger.moveTo(_center(tester, route[1]));
      await tester.pump();
      expect(flight.game.isTracing, isTrue);
      final second = await tester.startGesture(
        _center(tester, route[2]),
        pointer: 2,
      );
      await tester.pump();
      expect(flight.game.isTracing, isFalse);
      await second.up();
      await finger.up();
      await tester.pumpAndSettle();
      expect(_rotations(flight.game.puzzle), original);
      expect(flight.game.moves, 0);
    },
  );
}

List<int> _rotations(Puzzle puzzle) =>
    puzzle.tiles.map((tile) => tile.rotation).toList();
Offset _center(WidgetTester tester, int cell) =>
    tester.getCenter(find.byKey(ValueKey('tile-$cell')));
List<({int cell, int port})> _neighbors(int cell, int size) => [
  if (cell % size > 0) (cell: cell - 1, port: west),
  if (cell % size < size - 1) (cell: cell + 1, port: east),
  if (cell >= size) (cell: cell - size, port: north),
  if (cell < size * (size - 1)) (cell: cell + size, port: south),
];

class _Flight {
  _Flight(this.game);
  final GameController game;
  Duration now = Duration.zero;
  LaunchCountdown instrument(WidgetTester tester) =>
      tester.widget(find.byType(LaunchCountdown));
}

Future<_Flight> _launch(
  WidgetTester tester, {
  int level = 2,
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'journeyLevel': level});
  final game = (await tester.runAsync(() async {
    final value = GameController(
      preferences: await SharedPreferences.getInstance(),
      now: () => DateTime.utc(2026, 11, 23, 15),
      snapshotWriter: (_) async => true,
    );
    await value.load();
    return value;
  }))!;
  addTearDown(game.dispose);
  final flight = _Flight(game);
  await tester.pumpWidget(
    GlowpathApp(
      controller: game,
      showBriefings: false,
      ambientMotion: false,
      clockNow: () => flight.now,
    ),
  );
  await tester.pumpAndSettle();
  return flight;
}
