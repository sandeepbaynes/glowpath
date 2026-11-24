import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glowpath/services/flight_support.dart';
import 'package:glowpath/ui/flight_support_panel.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:glowpath/ui/design.dart';

void expectFreeSupportPage(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(Scrollable), findsNothing);
  expect(
    tester
        .widgetList<OrbitMode>(find.byType(OrbitMode))
        .map((mode) => mode.label),
    ['Hints', 'Skips'],
  );
  expect(find.byKey(const ValueKey('remove-ads')), findsNothing);
  expect(
    find.textContaining(
      RegExp(
        'ad-free|remove ads|purchase|unlock|restore',
        caseSensitive: false,
      ),
    ),
    findsNothing,
  );
  for (final element
      in find
          .byWidgetPredicate(
            (widget) => widget is OrbitMode || widget is SpaceAction,
          )
          .evaluate()) {
    final size = tester.getSize(find.byWidget(element.widget));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  }
}

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
    const Size(393, 852),
    const Size(844, 390),
    const Size(1024, 1366),
    const Size(1366, 1024),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'free support fits at $size / $scale and hint/skip rewards work',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          SharedPreferences.setMockInitialValues({});
          final support = FlightSupport(mock: true);
          await support.initialize();
          addTearDown(support.dispose);
          var skips = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: gameTheme(),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: math.min(560, size.width - 40),
                    height: size.height * .92 - 80,
                    child: FlightSupportPanel(
                      support: support,
                      onSkip: () => skips++,
                      canSkip: true,
                      reduceMotion: true,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expectFreeSupportPage(tester);
          await tester.tap(find.byKey(const ValueKey('skip-level')));
          await tester.pump();
          expect(skips, 1);
          expect(support.skipCredits, 0);
          expect(
            tester
                .widget<SpaceAction>(find.byKey(const ValueKey('skip-level')))
                .onPressed,
            isNull,
          );
          await tester.tap(find.byKey(const ValueKey('reward-skip')));
          await tester.pumpAndSettle();
          expect(support.skipCredits, 1);
          expectFreeSupportPage(tester);
          await tester.tap(
            find.byWidgetPredicate(
              (widget) => widget is OrbitMode && widget.label == 'Hints',
            ),
          );
          await tester.pumpAndSettle();
          expectFreeSupportPage(tester);
          await tester.tap(find.byKey(const ValueKey('reward-hints')));
          await tester.pumpAndSettle();
          expect(support.hintCredits, 6);
          expectFreeSupportPage(tester);
          await tester.tap(
            find.byWidgetPredicate(
              (widget) => widget is OrbitMode && widget.label == 'Skips',
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('skip-level')));
          await tester.pumpAndSettle();
          expect(skips, 2);
          expect(support.skipCredits, 0);
          expect(support.adFree, isFalse);
          expectFreeSupportPage(tester);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final initialPage in [-1, 2, 99]) {
    testWidgets('support clamps legacy page $initialPage to hints or skips', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final support = FlightSupport(mock: true);
      await support.initialize();
      addTearDown(support.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: Scaffold(
            body: FlightSupportPanel(
              support: support,
              onSkip: () {},
              initialPage: initialPage,
              reduceMotion: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expectFreeSupportPage(tester);
      expect(
        tester
            .widgetList<OrbitMode>(find.byType(OrbitMode))
            .singleWhere((mode) => mode.selected)
            .label,
        initialPage < 0 ? 'Hints' : 'Skips',
      );
      expect(
        find.byKey(ValueKey(initialPage < 0 ? 'reward-hints' : 'reward-skip')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
