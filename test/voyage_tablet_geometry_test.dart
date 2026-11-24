import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const portraits = [
    Size(744, 1133),
    Size(820, 1180),
    Size(1024, 1366),
    Size(800, 1280),
  ];

  test(
    'landscape scene scale respects height while phone/map scale is unchanged',
    () {
      expect(VoyageDepthPainter.sceneSpan(const Size(390, 844)), 390);
      expect(VoyageDepthPainter.sceneSpan(const Size(342, 350)), 342);
      final phonePosition = VoyageDepthPainter.project(
        const Size(390, 844),
        -.72,
        .72,
        1.92,
      );
      expect(phonePosition.dx, closeTo(109.2, .00001));
      expect(phonePosition.dy, closeTo(370.2, .00001));
      expect(
        VoyageDepthPainter.sceneSpan(const Size(1366, 1024)),
        closeTo(921.6, .001),
      );
      expect(VoyageDepthPainter.sceneSpan(const Size(1280, 800)), 720);
    },
  );

  for (final portrait in portraits) {
    for (final size in [portrait, Size(portrait.height, portrait.width)]) {
      test(
        'destination core, route target and full rocket fit $size during arrival',
        () {
          final screen = Offset.zero & size;
          final focus = size.width > size.height ? .22 : .38;
          for (var destination = 0; destination < 5; destination++) {
            for (var route = 0; route < 5; route++) {
              for (var frame = 0; frame <= 20; frame++) {
                final progress = frame / 20;
                final painter = VoyageDepthPainter(
                  current: VoyageWorld.forLevel(destination * 15 + 1),
                  approach: progress,
                  routesAtDestination: route,
                  showCourier: true,
                  verticalFocus: focus,
                );
                final body = painter.currentPlanetBounds(size);
                final target = painter.courierPosition(size, progress: 1);
                final rocket = painter.courierPosition(size);
                // 2.2 units enclose the nose, fins and longest exhaust in any
                // bank angle. These units also drive the actual painter scale.
                final rocketEnvelope = Rect.fromCircle(
                  center: rocket,
                  radius: painter.courierUnit(size) * 2.2,
                );
                final context =
                    'world$destination route$route at$progress on$size';
                expect(screen.contains(body.topLeft), isTrue, reason: context);
                expect(
                  screen.contains(body.bottomRight),
                  isTrue,
                  reason: context,
                );
                expect(
                  screen.deflate(6).contains(target),
                  isTrue,
                  reason: context,
                );
                expect(
                  screen.contains(rocketEnvelope.topLeft),
                  isTrue,
                  reason: context,
                );
                expect(
                  screen.contains(rocketEnvelope.bottomRight),
                  isTrue,
                  reason: context,
                );
              }
            }
          }
        },
      );
    }
  }
}
