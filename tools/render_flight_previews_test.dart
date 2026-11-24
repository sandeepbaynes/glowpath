// Artifact renderer, run explicitly from the project root:
// flutter test tools/render_flight_previews_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/mission.dart';
import 'package:glowpath/ui/cockpit_flight.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/rocket_effects.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('Atkinson')..addFont(
          rootBundle.load(
            'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
          ),
        ))
        .load();
  });

  testWidgets('render actual flight and launch widgets for visual review', (
    tester,
  ) async {
    const viewport = Size(390, 844);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final safe = Mission.campaign(4).solvedCopy();
    final safeFlight = safe.launch();
    expect(safeFlight.success, isTrue);
    await _render(
      tester,
      'docs/screenshots/cockpit-flight-0.4.png',
      SizedBox.expand(
        child: CockpitFlight(mission: safe, result: safeFlight, progress: .40),
      ),
    );

    final broken = Mission.campaign(2);
    final failedFlight = broken.launch();
    expect(failedFlight.success, isFalse);
    expect(failedFlight.steps, isNotEmpty);
    await _render(
      tester,
      'docs/screenshots/cockpit-lost-0.4.png',
      SizedBox.expand(
        child: CockpitFlight(
          mission: broken,
          result: failedFlight,
          progress: .96,
        ),
      ),
    );

    await _render(
      tester,
      'docs/screenshots/rocket-launch-0.4.png',
      const Center(
        child: RocketLaunchScene(launchProgress: .3, height: 844 * .7),
      ),
    );
  });
}

Future<void> _render(WidgetTester tester, String output, Widget scene) async {
  const capture = ValueKey('flight-preview-capture');
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: gameTheme(),
      home: RepaintBoundary(
        key: capture,
        child: Scaffold(body: scene),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(capture),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      expect(image.width, 390);
      expect(image.height, 844);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(png, isNotNull);
      final data = png!;
      final file = File(output);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}
