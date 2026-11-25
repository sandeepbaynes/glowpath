import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_failure.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final vertical in [false, true]) {
    testWidgets(
      '${vertical ? "vertical" : "horizontal"} countdown hands the exact visible craft to loss',
      (tester) async {
        final tracker = CountdownFlightTracker();
        final hostSize = vertical ? const Size(76, 390) : const Size(340, 76);
        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 80, right: 30),
                  child: SizedBox.fromSize(
                    size: hostSize,
                    child: LaunchCountdown(
                      tracker: tracker,
                      vertical: vertical,
                      prominent: !vertical,
                      remaining: const Duration(milliseconds: 200),
                      total: const Duration(seconds: 30),
                      reducedMotion: false,
                      expired: false,
                      complete: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final origin = tracker.capture()!;
        expect(origin.angle, closeTo(vertical ? 0 : math.pi / 2, .001));
        expect(origin.length, greaterThan(15));
        final initial = FlightFailureFrame.at(
          0,
          const Size(400, 300),
          launchOrigin: origin,
        );
        expect(
          (initial.rocketPosition - origin.position).distance,
          lessThan(.0001),
        );
        expect(initial.rocketLength, closeTo(origin.length, .0001));
        expect(initial.rocketAngle, closeTo(origin.angle, .0001));
        expect(initial.rocketOpacity, 1);
        final after = FlightFailureFrame.at(
          .001 / 6,
          const Size(400, 300),
          launchOrigin: origin,
        );
        expect(
          (after.rocketPosition - initial.rocketPosition).distance,
          lessThan(.1),
        );
        expect((after.rocketAngle - initial.rocketAngle).abs(), lessThan(.1));

        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: Scaffold(
              body: RepaintBoundary(
                key: const ValueKey('handoff-capture'),
                child: FlightFailureOverlay(
                  onRetry: () {},
                  launchOrigin: origin,
                ),
              ),
            ),
          ),
        );
        final art = find.byKey(const ValueKey('flight-failure-rocket'));
        final painter =
            tester.widget<CustomPaint>(art).painter! as LostRocketPainter;
        final scene = tester.getRect(art);
        final inherited = scene.topLeft + painter.rocketPosition(scene.size);
        expect((inherited - origin.position).distance, lessThan(.001));
        expect(painter.rocketLength(scene.size), closeTo(origin.length, .001));
        expect(painter.launchOrigin!.trailColor, origin.trailColor);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('handoff-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var bright = 0;
          for (
            var y = (origin.position.dy - 25).round();
            y < origin.position.dy + 25;
            y++
          ) {
            for (
              var x = (origin.position.dx - 25).round();
              x < origin.position.dx + 25;
              x++
            ) {
              if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
                continue;
              }
              final i = (y * image.width + x) * 4;
              if (rgba.getUint8(i) > 140 && rgba.getUint8(i + 1) > 140) {
                bright++;
              }
            }
          }
          expect(
            bright,
            greaterThan(20),
            reason: 'Inherited craft outside the centered stage must actually paint, not just report coordinates.',
          );
          final dir = Directory('build/review/countdown-handoff');
          await dir.create(recursive: true);
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await File(
            '${dir.path}/${vertical ? 'vertical' : 'horizontal'}-first-frame.png',
          ).writeAsBytes(png.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('retry-flight')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'handoff joins guided flight with continuous position, size and velocity',
    () {
      const size = Size(480, 400);
      for (final angle in [0.0, math.pi / 2]) {
        final origin = LaunchFlightOrigin(
          position: const Offset(450, -40),
          angle: angle,
          length: 28,
          heat: .99,
          urgent: true,
          trailColor: Palette.light,
        );
        FlightFailureFrame frame(double seconds) =>
            FlightFailureFrame.at(seconds / 6, size, launchOrigin: origin);
        final a = frame(1.19999), b = frame(1.20001);
        expect((b.rocketPosition - a.rocketPosition).distance, lessThan(.01));
        expect((b.rocketVelocity - a.rocketVelocity).distance, lessThan(.1));
        expect(b.rocketLength, closeTo(a.rocketLength, .01));
        expect(frame(1.999).routeBroken, isFalse);
        expect(frame(2).routeBroken, isTrue);
      }
    },
  );

  testWidgets(
    'prominent flight rail uses the full width and approaches the readout edge',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 340,
              child: LaunchCountdown(
                remaining: Duration.zero,
                total: const Duration(seconds: 30),
                prominent: true,
                reducedMotion: true,
                expired: false,
                complete: false,
              ),
            ),
          ),
        ),
      );
      final instrument = tester.getRect(
        find.byKey(const ValueKey('launch-countdown')),
      );
      final rail = tester.getRect(
        find.byKey(const ValueKey('launch-time-rail')),
      );
      final rocket = tester.getRect(
        find.byKey(const ValueKey('countdown-rocket')),
      );
      expect(rail.width, closeTo(instrument.width, .01));
      expect(rocket.right, greaterThan(instrument.right - 5));
      expect(tester.takeException(), isNull);
    },
  );
}
