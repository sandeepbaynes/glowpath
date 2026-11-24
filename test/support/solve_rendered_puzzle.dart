import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:material_ui/material_ui.dart';

/// Solve using the real hit targets and current legal action plan. Leave the
/// final frame at the beginning of its arrival animation for motion assertions.
Future<void> solveRenderedPuzzle(WidgetTester tester) async {
  final board = tester.widget<PuzzleBoard>(find.byType(PuzzleBoard));
  final actions = board.puzzle.solutionActions;
  for (final action in actions) {
    final tile = find.byKey(ValueKey('tile-$action'));
    expect(tile.hitTestable(), findsOneWidget);
    await tester.tap(tile);
    await tester.pump();
    if (tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).status.solved) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 280));
  }
  expect(
    tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).status.solved,
    isTrue,
  );
}
