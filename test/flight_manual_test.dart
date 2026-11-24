import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_manual.dart';
import 'package:glowpath/ui/mission_briefing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('shields and gravity-linked lanes have distinct first-time rules', () {
    Set<String> titles(int planet) => missionRulesFor(
      Puzzle.planet(seed: 55, levelNumber: (planet - 1) * 15 + 1),
    ).map((rule) => rule.title).toSet();

    final defense = titles(12);
    expect(defense, contains('Defense circuits'));
    expect(defense, isNot(contains('Shield charges')));
    expect(titles(13).difference(defense), contains('Shield charges'));
    expect(titles(14).difference(titles(13)), contains('Gravity-linked lanes'));
    final fixed = missionRulesFor(Puzzle.planet(seed: 55, levelNumber: 16))
        .singleWhere((rule) => rule.title == 'Fixed relays');
    expect(fixed.text, contains('connect through it'));
  });

  for (final size in const [
    Size(320, 568),
    Size(375, 667),
    Size(393, 852),
    Size(667, 375),
    Size(844, 390),
    Size(1024, 1366),
    Size(1366, 1024),
    Size(1440, 900),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('all flight notes fit $size at $scale× text', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final puzzle = Puzzle.planet(seed: 819, levelNumber: 196);
        var closed = false;
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
                  child: SizedBox(
                    // Account for the real sheet's width cap, header, padding
                    // and safe area instead of testing a full-screen manual.
                    width: math.min(600, size.width) - 40,
                    height: size.height * .92 - 120,
                    child: FlightManual(
                      puzzle: puzzle,
                      onClose: () => closed = true,
                      reduceMotion: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final visibleChunks = <String>[];
        var pageCount = 0;
        while (true) {
          expect(tester.takeException(), isNull);
          expect(find.byType(Scrollable), findsNothing);
          final copy = find.byKey(const ValueKey('manual-body-copy'));
          final text = tester.widget<Text>(copy);
          visibleChunks.add(text.data!);
          expect(text.style!.fontSize, 16);
          final paragraph = tester.renderObject<RenderParagraph>(copy);
          expect(
            paragraph.getMaxIntrinsicHeight(paragraph.size.width),
            lessThanOrEqualTo(paragraph.size.height + .01),
            reason: 'Unclipped text on page $pageCount: ${text.data}',
          );
          for (final name in [
            'manual-previous',
            'manual-close',
            'manual-next',
          ]) {
            final control = find.byKey(ValueKey(name));
            final bounds = tester.getRect(control);
            expect(bounds.width, greaterThanOrEqualTo(48));
            expect(bounds.height, greaterThanOrEqualTo(48));
            expect(bounds.left, greaterThanOrEqualTo(0));
            expect(bounds.right, lessThanOrEqualTo(size.width));
            expect(bounds.bottom, lessThanOrEqualTo(size.height));
          }
          final next = tester.widget<Semantics>(
            find.byKey(const ValueKey('manual-next')),
          );
          pageCount++;
          expect(pageCount, lessThan(120), reason: 'Pagination must terminate');
          if (next.properties.enabled != true) break;
          await tester.tap(find.byKey(const ValueKey('manual-next')));
          await tester.pump();
        }
        final visibleInstructions = visibleChunks.join(' ');
        for (final rule in missionRulesFor(puzzle)) {
          expect(visibleInstructions, contains(rule.text));
        }
        for (final beat in firstFlightBriefing) {
          expect(visibleInstructions, contains(beat.text));
        }
        expect(visibleInstructions, contains('30, 27, then 24 seconds'));
        expect(visibleInstructions, contains('Skipping advances the Voyage'));
        expect(visibleInstructions, contains('tap the hint action again'));
        await tester.tap(find.byKey(const ValueKey('manual-previous')));
        await tester.pump();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('manual-body-copy')))
              .data,
          visibleChunks[visibleChunks.length - 2],
        );
        await tester.tap(find.byKey(const ValueKey('manual-close')));
        expect(closed, isTrue);
      });
    }
  }
}
