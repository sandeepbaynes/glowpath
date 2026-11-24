import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/ui/challenge_result.dart';
import 'package:glowpath/ui/daily_reset.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/puzzle_board.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  const cases = [
    (size: Size(390, 844), insets: EdgeInsets.zero),
    (size: Size(320, 568), insets: EdgeInsets.zero),
    (size: Size(360, 640), insets: EdgeInsets.zero),
    (size: Size(430, 932), insets: EdgeInsets.zero),
    (size: Size(740, 360), insets: EdgeInsets.zero),
    (size: Size(844, 390), insets: EdgeInsets.zero),
    (size: Size(744, 1133), insets: EdgeInsets.zero),
    (size: Size(820, 1180), insets: EdgeInsets.zero),
    (size: Size(1180, 820), insets: EdgeInsets.zero),
    (size: Size(1366, 1024), insets: EdgeInsets.zero),
    (size: Size(1024, 768), insets: EdgeInsets.zero),
    (size: Size(1440, 900), insets: EdgeInsets.zero),
    (size: Size(1920, 1080), insets: EdgeInsets.zero),
    (size: Size(390, 844), insets: EdgeInsets.only(top: 47, bottom: 34)),
  ];

  for (final entry in cases) {
    testWidgets('Voyage, Daily, Weekly and arrival fit without scrolling at '
        '${entry.size} / ${entry.insets}', (tester) async {
      tester.view.physicalSize = entry.size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(
        left: entry.insets.left,
        top: entry.insets.top,
        right: entry.insets.right,
        bottom: entry.insets.bottom,
      );
      tester.view.viewPadding = tester.view.padding;
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({'journeyLevel': 20});
      final game = (await tester.runAsync(() async {
        final controller = GameController(
          preferences: await SharedPreferences.getInstance(),
          now: () => DateTime.utc(2026, 11, 22, 12),
          snapshotWriter: (_) async => true,
        );
        await controller.load();
        return controller;
      }))!;
      addTearDown(game.dispose);
      await tester.pumpWidget(
        GlowpathApp(
          showBriefings: false,
          controller: game,
          ambientMotion: false,
          clockNow: () => Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
      final safeBounds = Rect.fromLTRB(
        entry.insets.left,
        entry.insets.top,
        entry.size.width - entry.insets.right,
        entry.size.height - entry.insets.bottom,
      );

      await tester.tap(find.byKey(const ValueKey('open-atlas')));
      await tester.pumpAndSettle();
      final homeDock = _expectNavigation(tester, safeBounds);
      final homeBounds = Rect.fromLTRB(
        safeBounds.left,
        safeBounds.top,
        safeBounds.right,
        homeDock.top,
      );
      _expectInside(
        tester,
        find.byKey(const ValueKey('voyage-home-heading')),
        homeBounds,
      );
      for (final key in ['next-puzzle', 'voyage-route-log', 'open-rewards']) {
        _expectInside(
          tester,
          find.byKey(ValueKey(key)),
          homeBounds,
          interactive: true,
        );
      }
      expect(
        tester.getRect(find.byKey(const ValueKey('next-stop-flight'))),
        Offset.zero & entry.size,
      );
      _expectNoScrolling(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('next-puzzle')));
      await tester.pumpAndSettle();

      for (final mode in GameMode.values) {
        if (mode != GameMode.voyage) {
          await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
          await tester.pumpAndSettle();
        }
        expect(game.mode, mode);
        final movable = game.puzzle.tiles.indexWhere((tile) => !tile.isLocked);
        expect(game.rotate(movable), isTrue);
        await tester.pumpAndSettle();
        expect(game.status.solved, isFalse);
        expect(game.canUndo, isTrue);
        expect(tester.takeException(), isNull);
        final dockBounds = _expectNavigation(tester, safeBounds);
        final contentBounds = Rect.fromLTRB(
          safeBounds.left,
          safeBounds.top,
          safeBounds.right,
          dockBounds.top,
        );

        // No ensureVisible or scroll gesture precedes these assertions. The
        // complete playing surface and its tools must be present at once.
        final board = find.byType(PuzzleBoard);
        _expectInside(tester, board, contentBounds);
        if (entry.size.width >= 700 && entry.size.height >= 700) {
          expect(
            tester.getSize(board).width,
            greaterThanOrEqualTo(
              math.min(entry.size.width * .50, entry.size.height * .60),
            ),
            reason:
                'Tablet boards should use the available space, not remain '
                'a small phone-sized island',
          );
        }
        for (var index = 0; index < game.puzzle.tiles.length; index++) {
          final tile = find.byKey(ValueKey('tile-$index'));
          _expectInside(tester, tile, contentBounds, interactive: true);
          final target = tester.getSize(tile);
          expect(target.width, greaterThanOrEqualTo(48 - .001));
          expect(target.height, greaterThanOrEqualTo(48 - .001));
        }
        for (final key in ['open-atlas', 'hint', 'undo']) {
          _expectInside(
            tester,
            find.byKey(ValueKey(key)),
            contentBounds,
            interactive: true,
          );
        }
        _expectInside(tester, find.byType(LaunchCountdown), contentBounds);
        _expectInside(
          tester,
          find.byKey(const ValueKey('launch-seconds')),
          contentBounds,
        );
        if (mode == GameMode.voyage) {
          _expectInside(
            tester,
            find.byKey(const ValueKey('move-count')),
            contentBounds,
          );
          _expectInside(tester, find.textContaining('Target '), contentBounds);
        } else {
          _expectInside(
            tester,
            find.byKey(const ValueKey('challenge-live-stats')),
            contentBounds,
          );
          expect(find.byType(DailyReset), findsNothing);
        }
        _expectNoScrolling(tester);

        final stages = mode == GameMode.voyage
            ? 1
            : mode == GameMode.daily
            ? 3
            : 5;
        for (var stage = 0; stage < stages; stage++) {
          for (var turn = 0; turn < 30 && !game.status.solved; turn++) {
            expect(game.hint(), isTrue);
          }
          expect(game.status.solved, isTrue);
          await tester.pumpAndSettle();
          if (mode != GameMode.voyage) {
            // Arrival hands directly to the next board after its brief pause;
            // the player never has to seek a per-stage Play control.
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(_expectNavigation(tester, safeBounds), dockBounds);
          if (mode == GameMode.voyage) {
            _expectInside(
              tester,
              find.byKey(const ValueKey('next-stop-summary')),
              contentBounds,
            );
            _expectInside(
              tester,
              find.byKey(const ValueKey('next-puzzle')),
              contentBounds,
              interactive: true,
            );
          } else if (stage < stages - 1) {
            expect(game.mode, mode);
            expect(game.status.solved, isFalse);
            expect(
              (mode == GameMode.daily
                      ? game.dailyCompleted
                      : game.weeklyCompleted)
                  .length,
              stage + 1,
            );
            _expectInside(tester, find.byType(PuzzleBoard), contentBounds);
            _expectInside(tester, find.byType(LaunchCountdown), contentBounds);
            _expectInside(
              tester,
              find.byKey(const ValueKey('challenge-live-stats')),
              contentBounds,
            );
            expect(find.byType(DailyReset), findsNothing);
            expect(find.byKey(const ValueKey('next-puzzle')), findsNothing);
          } else {
            _expectInside(tester, find.byType(ChallengeResult), contentBounds);
            for (final key in [
              'challenge-result-title',
              'challenge-result-score',
              'challenge-result-rewards',
            ]) {
              _expectInside(tester, find.byKey(ValueKey(key)), contentBounds);
            }
            for (final key in [
              'challenge-return-voyage',
              'challenge-open-collection',
            ]) {
              _expectInside(
                tester,
                find.byKey(ValueKey(key)),
                contentBounds,
                interactive: true,
              );
            }
            expect(find.byKey(const ValueKey('next-puzzle')), findsNothing);
          }
          _expectNoScrolling(tester);
        }
      }
    });
  }
}

Rect _expectNavigation(WidgetTester tester, Rect safeBounds) {
  final dock = find.byKey(const ValueKey('shared-navigation'));
  _expectInside(tester, dock, safeBounds);
  final dockBounds = tester.getRect(dock);
  for (final key in [
    'mode-journey',
    'mode-daily',
    'mode-weekly',
    'open-help',
    'open-settings',
  ]) {
    _expectInside(
      tester,
      find.byKey(ValueKey(key)),
      dockBounds,
      interactive: true,
    );
  }
  return dockBounds;
}

void _expectInside(
  WidgetTester tester,
  Finder finder,
  Rect bounds, {
  bool interactive = false,
}) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.width, greaterThan(0), reason: '$finder must have visible width');
  expect(
    rect.height,
    greaterThan(0),
    reason: '$finder must have visible height',
  );
  expect(rect.left, greaterThanOrEqualTo(bounds.left - .01), reason: '$finder');
  expect(rect.top, greaterThanOrEqualTo(bounds.top - .01), reason: '$finder');
  expect(rect.right, lessThanOrEqualTo(bounds.right + .01), reason: '$finder');
  expect(
    rect.bottom,
    lessThanOrEqualTo(bounds.bottom + .01),
    reason: '$finder',
  );
  if (interactive) {
    expect(
      finder.hitTestable(),
      findsOneWidget,
      reason: '$finder must accept touch before any scrolling',
    );
  }
}

void _expectNoScrolling(WidgetTester tester) {
  for (final element in find.byType(Scrollable).evaluate()) {
    final scrollable = (element as StatefulElement).state as ScrollableState;
    expect(
      scrollable.position.maxScrollExtent,
      lessThanOrEqualTo(.01),
      reason: 'The active gameplay/arrival HUD must fit its allocated viewport',
    );
  }
}
