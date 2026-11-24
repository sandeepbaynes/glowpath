import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/challenge_result.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/space_controls.dart';
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
  testWidgets('capture challenge results and retry at review sizes', (
    tester,
  ) async {
    const boundaryKey = ValueKey('challenge-review');
    for (final (name, size, scale, retry) in [
      ('challenge-phone', const Size(393, 852), 1.0, false),
      ('challenge-tablet', const Size(1024, 1366), 1.0, false),
      ('challenge-large-type', const Size(844, 390), 3.0, false),
      ('challenge-retry-phone', const Size(320, 568), 3.0, true),
      ('challenge-retry-landscape', const Size(844, 390), 3.0, true),
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
                body: retry
                    ? ChallengeRetryOverlay(
                        stage: 2,
                        stageCount: 3,
                        onRetry: () {},
                        reduceMotion: true,
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: ChallengeResult(
                                weekly: false,
                                stageCount: 3,
                                points: 2785,
                                activeElapsed: const Duration(
                                  milliseconds: 42600,
                                ),
                                cleanStreak: 3,
                                medalEarned: true,
                                starsEarned: 9,
                                coinsEarned: 45,
                                periodDate: '2026-11-23',
                                onVoyage: () {},
                                onCollection: () {},
                                now: () => DateTime.utc(2026, 11, 23, 20, 15),
                                reduceMotion: true,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                            child: SizedBox(
                              height: 64,
                              child: OrbitDock(
                                child: Row(
                                  children: [
                                    for (final label in [
                                      'Voyage',
                                      'Daily',
                                      'Weekly',
                                    ])
                                      Expanded(
                                        child: OrbitMode(
                                          label: label,
                                          selected: label == 'Daily',
                                          onPressed: () {},
                                          reduceMotion: true,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/screenshots/0.8.0-$name.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
