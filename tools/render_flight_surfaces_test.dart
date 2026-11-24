import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_manual.dart';
import 'package:glowpath/ui/flight_settings.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  testWidgets('review flight reference and controls at responsive sizes', (
    tester,
  ) async {
    const boundaryKey = ValueKey('flight-surface-review');
    // This file is a Flutter test capture harness, outside the test directory.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final game = (await tester.runAsync(() async {
      final value = GameController(
        preferences: await SharedPreferences.getInstance(),
        snapshotWriter: (_) async => true,
      );
      await value.load();
      return value;
    }))!;
    addTearDown(game.dispose);
    final puzzle = Puzzle.planet(seed: 819, levelNumber: 196);
    for (final (name, size, scale, section) in [
      ('manual-phone', const Size(393, 852), 1.0, -1),
      ('manual-tablet', const Size(1024, 1366), 1.0, -1),
      ('manual-large-type', const Size(320, 568), 3.0, -1),
      ('flight-phone', const Size(393, 852), 1.0, 0),
      ('feel-phone', const Size(375, 667), 1.0, 1),
      ('about-phone', const Size(393, 852), 1.0, 2),
      ('feel-desktop', const Size(1440, 900), 1.0, 1),
      ('feel-landscape-large-type', const Size(844, 390), 3.0, 1),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(
              key: boundaryKey,
              child: Scaffold(
                body: OrbitPanelFrame(
                  title: section < 0 ? 'FLIGHT NOTES' : 'FLIGHT CONTROLS',
                  fit: true,
                  onClose: () {},
                  child: section < 0
                      ? FlightManual(
                          puzzle: puzzle,
                          onClose: () {},
                          reduceMotion: true,
                        )
                      : FlightSettings(
                          game: game,
                          demo: true,
                          onRestart: () {},
                          onSupport: () {},
                          onLeague: () {},
                          onRewards: () {},
                          onLicenses: () {},
                        ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (section >= 0) {
        await tester.tap(find.byKey(ValueKey('settings-section-$section')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/screenshots/review-$name.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
