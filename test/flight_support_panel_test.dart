import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glowpath/services/flight_support.dart';
import 'package:glowpath/ui/flight_support_panel.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:glowpath/ui/design.dart';

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
        'support fits without scroll at $size / $scale and preview actions work',
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
          expect(tester.takeException(), isNull);
          expect(find.byType(Scrollable), findsNothing);
          await tester.tap(find.byKey(const ValueKey('skip-level')));
          await tester.pump();
          expect(skips, 1);
          expect(support.skipCredits, 0);
          await tester.tap(find.byKey(const ValueKey('reward-skip')));
          await tester.pumpAndSettle();
          expect(support.skipCredits, 1);
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.byWidgetPredicate(
              (widget) => widget is OrbitMode && widget.label == 'Hints',
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('reward-hints')));
          await tester.pumpAndSettle();
          expect(support.hintCredits, 6);
          await tester.tap(
            find.byWidgetPredicate(
              (widget) => widget is OrbitMode && widget.label == 'Ad-free',
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('remove-ads')));
          await tester.pumpAndSettle();
          expect(support.adFree, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
