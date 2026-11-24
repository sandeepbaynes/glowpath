// Render the shipped widget, rather than a separate animation mock-up.
// flutter test tools/render_failure_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_failure.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, path) in [
      ('Manrope', 'assets/fonts/Manrope-VariableFont_wght.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });

  testWidgets('capture the complete signal-lost sequence', (tester) async {
    const capture = ValueKey('failure-film');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    final output = Directory('build/review/failure-0.7.3-frames');
    await tester.runAsync(() => output.create(recursive: true));
    for (var frame = 0; frame <= 225; frame++) {
      if (frame > 0) {
        await tester.pump(const Duration(microseconds: 33333));
      }
      expect(tester.takeException(), isNull, reason: 'Frame $frame');
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/${frame.toString().padLeft(4, '0')}.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
}
