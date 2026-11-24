import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:glowpath/ui/space_controls.dart';
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

  for (final separateLegend in [false, true]) {
    testWidgets(
      'compact board preserves 25 full targets with separate legend $separateLegend',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final puzzle = Puzzle.introduction(levelNumber: 1);
          await tester.pumpWidget(
            MaterialApp(
              theme: gameTheme(),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(3)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 276,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (separateLegend)
                            PuzzleLegend(
                              status: puzzle.evaluate(),
                              compact: true,
                            ),
                          PuzzleBoard(
                            puzzle: puzzle,
                            status: puzzle.evaluate(),
                            onTurn: (_) {},
                            reduceMotion: true,
                            highContrast: false,
                            compact: true,
                            showLabels: !separateLegend,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final board = tester.getRect(
            find.byKey(const ValueKey('puzzle-board')),
          );
          final legend = tester.getRect(find.byType(PuzzleLegend));
          expect(board.size, const Size(276, 276));
          expect(legend.height, 24);
          expect(legend.bottom, board.top);
          expect(find.byKey(const ValueKey('star-status')), findsOneWidget);
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
          final rects = <Rect>[];
          for (var i = 0; i < 25; i++) {
            final tile = find.byKey(ValueKey('tile-$i'));
            expect(tile.hitTestable(), findsOneWidget);
            final rect = tester.getRect(tile);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(board.contains(rect.topLeft), isTrue);
            expect(board.contains(rect.bottomRight), isTrue);
            for (final previous in rects) {
              expect(rect.overlaps(previous), isFalse);
            }
            rects.add(rect);
          }
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('compact countdown keeps every state in its slot at large text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final scale in [1.25, 3.0]) {
        for (final font in ['Atkinson', 'Ahem']) {
          for (final state in ['active', 'paused', 'expired', 'complete']) {
            final expired = state == 'expired';
            final complete = state == 'complete';
            final paused = state == 'paused';
            await tester.pumpWidget(
              MaterialApp(
                theme: gameTheme().copyWith(
                  textTheme: gameTheme().textTheme.apply(fontFamily: font),
                ),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: 120,
                        child: LaunchCountdown(
                          remaining: Duration(seconds: expired ? 0 : 60),
                          total: const Duration(seconds: 60),
                          reducedMotion: true,
                          expired: expired,
                          complete: complete,
                          paused: paused,
                          compact: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final bounds = tester.getRect(
              find.byKey(const ValueKey('launch-countdown')),
            );
            expect(bounds.size, const Size(120, 48));
            final value = tester.semantics
                .find(find.byKey(const ValueKey('launch-countdown')))
                .getSemanticsData()
                .value;
            expect(value, switch (state) {
              'expired' => 'Launch time reached. Route incomplete.',
              'complete' => 'Rocket launched. Route complete.',
              'paused' => '60 seconds remaining. Countdown paused.',
              _ => '60 seconds remaining. Rocket warming up. Launches automatically.',
            });
            for (final key in [
              'launch-seconds',
              'countdown-rocket',
              'launch-time-rail',
            ]) {
              final rect = tester.getRect(find.byKey(ValueKey(key)));
              expect(rect.left, greaterThanOrEqualTo(bounds.left));
              expect(rect.right, lessThanOrEqualTo(bounds.right));
              expect(rect.top, greaterThanOrEqualTo(bounds.top));
              expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$state / $scale / $font',
            );
          }
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('compact action retains a 48px target and activates once', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 168,
              child: SpaceAction(
                compact: true,
                reduceMotion: true,
                label: 'Turn this relay',
                icon: Icons.lightbulb_outline_rounded,
                onPressed: () => calls++,
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(SpaceAction);
    expect(tester.getRect(button).height, 48);
    expect(find.text('Turn this relay'), findsOneWidget);
    await tester.tap(button);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
