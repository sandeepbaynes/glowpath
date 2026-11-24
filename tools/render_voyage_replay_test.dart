// Internal screenshots of the shipped Voyage widgets. Never bundled.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/voyage_records.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
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
  for (final entry in [
    (name: 'phone', size: const Size(393, 852), scale: 1.0),
    (name: 'tablet', size: const Size(1024, 1366), scale: 1.0),
    (name: 'large-text-landscape', size: const Size(844, 390), scale: 3.0),
  ]) {
    testWidgets('capture sparse Voyage and replay log on ${entry.name}', (
      tester,
    ) async {
      tester.view.physicalSize = entry.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: MediaQueryData(
              size: entry.size,
              textScaler: TextScaler.linear(entry.scale),
            ),
            child: RepaintBoundary(
              key: const ValueKey('capture'),
              child: Scaffold(
                body: SpaceBackdrop(
                  level: 61,
                  reduceMotion: true,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: math.min(600, entry.size.width),
                      height: math.min(820, entry.size.height * .92),
                      child: OrbitSheet(
                        title: 'YOUR VOYAGE',
                        fit: true,
                        onClose: () {},
                        child: VoyageMap(
                          completedRoutes: 60,
                          frontierLevel: 61,
                          currentLevel: 61,
                          records: const {
                            1: RouteRecord(
                              level: 1,
                              bestScore: 860,
                              bestTime: Duration(milliseconds: 6200),
                            ),
                            2: RouteRecord(
                              level: 2,
                              bestScore: 735,
                              bestTime: Duration(milliseconds: 9700),
                            ),
                            3: RouteRecord(
                              level: 3,
                              bestScore: 680,
                              bestTime: Duration(milliseconds: 12400),
                            ),
                          },
                          reduceMotion: true,
                          onReplay: (_) {},
                          onContinue: () {},
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
      Future<void> capture(String scene) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/screenshots/voyage-$scene-${entry.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('sparse');
      await tester.tap(find.byKey(const ValueKey('voyage-first-planet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('voyage-route-log')));
      await tester.pumpAndSettle();
      await capture('replay');
      expect(tester.takeException(), isNull);
    });
  }
}
