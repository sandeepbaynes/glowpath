// Capture real gallery widgets and original award artwork for visual review.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/rewards.dart';
import 'package:glowpath/ui/achievement_art.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:glowpath/ui/rewards_panel.dart';
import 'package:glowpath/ui/space_scenery.dart';
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
  testWidgets('capture achievement artwork and responsive gallery', (
    tester,
  ) async {
    const capture = ValueKey('achievement-capture');
    for (final (name, size, scale) in [
      ('achievement-catalog', const Size(1200, 930), 1.0),
      ('achievements-phone', const Size(393, 852), 1.0),
      ('achievements-tablet', const Size(1024, 1366), 1.0),
      ('achievements-large-type', const Size(844, 390), 3.0),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final catalog = name == 'achievement-catalog';
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
              key: capture,
              child: Scaffold(
                backgroundColor: Palette.paper,
                body: catalog
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            for (var row = 0; row < 3; row++)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (var column = 0; column < 4; column++)
                                      Expanded(
                                        child: Column(
                                          children: [
                                            AchievementArtwork(
                                              id:
                                                  achievementCatalog[row * 4 +
                                                          column]
                                                      .id,
                                              size: 240,
                                            ),
                                            Text(
                                              achievementCatalog[row * 4 +
                                                      column]
                                                  .label,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: Palette.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )
                    : SpaceBackdrop(
                        level: 31,
                        reduceMotion: true,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: math.min(size.width, 600),
                            height: math.min(820, size.height * .92),
                            child: OrbitSheet(
                              title: 'YOUR COLLECTION',
                              fit: true,
                              onClose: () {},
                              child: RewardsPanel(
                                stars: 24,
                                equippedTrail: ShipTrail.ember,
                                earnedAchievementIds: const {
                                  'first_signal',
                                  'navigator_5',
                                },
                                dailyMedals: 1,
                                weeklyMedals: 0,
                                onEquip: (_) {},
                                reduceMotion: true,
                                initialAchievements: true,
                                cargoCollection: const {},
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        final image = await boundary.toImage(pixelRatio: 1.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/screenshots/0.8.0-$name.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
