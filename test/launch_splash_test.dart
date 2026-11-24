import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/launch_splash.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
  });

  for (final (viewport, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(820, 1180), 1.0),
    (const Size(1366, 1024), 1.0),
    (const Size(320, 568), 3.0),
    (const Size(740, 320), 3.0),
  ]) {
    testWidgets('splash is legible and motion-free at $viewport / ${scale}x', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(theme: gameTheme(), home: const LaunchSplash()),
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Glowpath. Loading your route.'),
          findsOneWidget,
        );
        expect(find.text('Glowpath'), findsOneWidget);
        final status = find.text('Loading your route');
        await tester.ensureVisible(status);
        await tester.pump();
        final statusBounds = tester.getRect(status);
        expect(statusBounds.left, greaterThanOrEqualTo(0));
        expect(statusBounds.right, lessThanOrEqualTo(viewport.width));
        expect(statusBounds.top, greaterThanOrEqualTo(0));
        expect(statusBounds.bottom, lessThanOrEqualTo(viewport.height));
        expect(tester.takeException(), isNull);
        expect(tester.binding.hasScheduledFrame, isFalse);
      } finally {
        semantics.dispose();
      }
    });
  }
}
