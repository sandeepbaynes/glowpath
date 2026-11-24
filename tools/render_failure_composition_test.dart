// Capture fixed moments from the actual loss widget, not a separate mock-up.
// flutter test tools/render_failure_composition_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_failure.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    for (final (family, path) in [
      ('Manrope', 'assets/fonts/Manrope-VariableFont_wght.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });

  for (final (name, size) in [
    ('desktop', const Size(1440, 900)),
    ('tablet', const Size(1180, 820)),
    ('phone', const Size(393, 852)),
  ]) {
    testWidgets('capture loss composition on $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = ValueKey('loss-composition');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: gameTheme(),
          home: RepaintBoundary(
            key: capture,
            child: Scaffold(body: FlightFailureOverlay(onRetry: () {})),
          ),
        ),
      );
      await tester.pump();
      final output = Directory('docs/screenshots/0.10.3-loss');
      await tester.runAsync(() => output.create(recursive: true));
      var previous = 0;
      for (final time in [0, 1000, 2000, 2800, 4000, 5500, 6000]) {
        await tester.pump(Duration(milliseconds: time - previous));
        previous = time;
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${output.path}/$name-$time.png')
              .writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
