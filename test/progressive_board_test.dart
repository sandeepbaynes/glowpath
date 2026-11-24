import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final level in [1, 6, 20]) {
    _testWidgets('route $level fits every tile in the smallest phone board', (
      tester,
    ) async {
      final puzzle = Puzzle.voyage(seed: 102, levelNumber: level);
      await tester.pumpWidget(_board(puzzle));
      final board = tester.getRect(find.byKey(const ValueKey('puzzle-board')));
      final tileRects = <Rect>[];
      for (var index = 0; index < puzzle.tiles.length; index++) {
        final tile = find.byKey(ValueKey('tile-$index'));
        final rect = tester.getRect(tile);
        expect(tile.hitTestable(), findsOneWidget);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(board.contains(rect.topLeft), isTrue);
        expect(board.contains(rect.bottomRight), isTrue);
        for (final previous in tileRects) {
          expect(rect.overlaps(previous), isFalse);
        }
        tileRects.add(rect);
        final data = tester.getSemantics(tile).getSemanticsData();
        expect(
          data.label,
          startsWith(
            'Tile ${index ~/ puzzle.size + 1}, ${index % puzzle.size + 1}',
          ),
        );
      }
      expect(
        tester
            .getSemantics(
              find.byKey(ValueKey('tile-${puzzle.startRow * puzzle.size}')),
            )
            .getSemanticsData()
            .label,
        contains('entrance'),
      );
      expect(
        tester
            .getSemantics(
              find.byKey(
                ValueKey(
                  'tile-${puzzle.endRow * puzzle.size + puzzle.size - 1}',
                ),
              ),
            )
            .getSemanticsData()
            .label,
        contains('exit'),
      );
      expect(tester.takeException(), isNull);
    });

    _testWidgets('route $level paints a complete flight on its own grid size', (
      tester,
    ) async {
      final puzzle = Puzzle.voyage(seed: 102, levelNumber: level).solvedCopy();
      for (final progress in [.05, .45, .9]) {
        await tester.pumpWidget(
          _board(puzzle, reduceMotion: false, completionProgress: progress),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(PipeTile), findsNWidgets(puzzle.size * puzzle.size));
        expect(tester.takeException(), isNull);
      }
    });
  }

  _testWidgets('fixed relays are named and cannot be turned', (tester) async {
    final puzzle = Puzzle.voyage(seed: 812, levelNumber: 20);
    final turned = <int>[];
    await tester.pumpWidget(_board(puzzle, onTurn: turned.add));
    final locked = puzzle.tiles.indexWhere((tile) => tile.isLocked);
    final tile = find.byKey(ValueKey('tile-$locked'));
    final data = tester.getSemantics(tile).getSemanticsData();
    expect(data.label, contains('fixed relay'));
    expect(data.hint, contains('Plan the route'));
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.lock_rounded)),
      findsOneWidget,
    );
    await tester.tap(tile);
    expect(turned, isEmpty);
    final movable = puzzle.tiles.indexWhere((tile) => !tile.isLocked);
    await tester.tap(find.byKey(ValueKey('tile-$movable')));
    expect(turned, [movable]);
    expect(tester.takeException(), isNull);
  });

  _testWidgets(
    'one-way relays announce their current inlet and render an arrow',
    (tester) async {
      final puzzle = Puzzle.voyage(seed: 812, levelNumber: 20);
      await tester.pumpWidget(_board(puzzle));
      final index = puzzle.tiles.indexWhere((tile) => tile.isOneWay);
      final tile = find.byKey(ValueKey('tile-$index'));
      final data = tester.getSemantics(tile).getSemanticsData();
      expect(data.label, contains('one-way relay'));
      final direction = switch (puzzle.tiles[index].entryDirection) {
        north => 'above',
        east => 'the right',
        south => 'below',
        west => 'the left',
        _ => throw StateError('Expected a directional inlet'),
      };
      expect(data.value, contains('Light must enter from $direction.'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(of: tile, matching: find.byType(CustomPaint)),
          )
          .map((paint) => paint.painter)
          .whereType<PipePainter>()
          .single;
      expect(painter.oneWayEntry, puzzle.tiles[index].oneWayEntry);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _board(
  Puzzle puzzle, {
  ValueChanged<int>? onTurn,
  bool reduceMotion = true,
  double completionProgress = 0,
}) => MaterialApp(
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
            onTurn: onTurn ?? (_) {},
            reduceMotion: reduceMotion,
            highContrast: false,
            compact: true,
            completionProgress: completionProgress,
            trailColor: Colors.purple,
          ),
        ),
      ),
    ),
  ),
);

void _testWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await callback(tester);
    } finally {
      semantics.dispose();
    }
  });
}
