import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const anchors = [
    Offset(-1.2, 1.2),
    Offset(-.72, .72),
    Offset(1.35, .24),
    Offset(-.98, -.56),
    Offset(1.88, -1.92),
  ];
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    Offset projected(double distance) {
      // Inspect the renderer's actual bounds. The next body keeps the far
      // anchor reachable without exceeding the allowed backward excursion.
      final ahead = distance > 2.8 ? 1 : 0;
      final current = VoyageWorld.forLevel(76);
      final painter = VoyageDepthPainter(
        current: current,
        approach: 0,
        routesAtDestination: 0,
        cameraExcursion:
            (ahead - distance) * VoyageDepthPainter.destinationSpacing,
      );
      return ahead == 0
          ? painter.currentPlanetBounds(size).center
          : painter
                .visiblePlanetBounds(size)[current.planetIndex + ahead]!
                .center;
    }

    Offset lane(double distance) {
      final focus = Offset(size.width * .58, size.height * .30);
      final depth = math.max(
        .05,
        2.4 + distance * VoyageDepthPainter.destinationSpacing,
      );
      return (projected(distance) - focus) *
          (depth / (VoyageDepthPainter.sceneSpan(size) * .8));
    }

    test('camera rail retains anchors and never overshoots at $size', () {
      for (var index = 0; index < anchors.length; index++) {
        expect((lane(index - 1.0) - anchors[index]).distance, lessThan(1e-8));
      }
      for (var segment = 0; segment < anchors.length - 1; segment++) {
        final a = anchors[segment], b = anchors[segment + 1];
        for (var sample = 0; sample <= 80; sample++) {
          final point = lane(segment - 1 + sample / 80);
          expect(
            point.dx,
            inInclusiveRange(
              math.min(a.dx, b.dx) - 1e-8,
              math.max(a.dx, b.dx) + 1e-8,
            ),
          );
          expect(
            point.dy,
            inInclusiveRange(
              math.min(a.dy, b.dy) - 1e-8,
              math.max(a.dy, b.dy) + 1e-8,
            ),
          );
        }
      }
      expect((lane(-1.1) - anchors.first).distance, lessThan(1e-8));
      expect((lane(3.1) - anchors.last).distance, lessThan(1e-8));
    });

    test(
      'projected velocity stays continuous across camera rail turns at $size',
      () {
        const epsilon = 1e-5;
        for (final distance in [0.0, 1.0, 2.0, 3.0]) {
          final center = projected(distance);
          final before = (center - projected(distance - epsilon)) / epsilon;
          final after = (projected(distance + epsilon) - center) / epsilon;
          expect(
            (after - before).distance,
            lessThan(.03),
            reason: 'No direction or speed jump at lane anchor $distance.',
          );
        }
      },
    );
  }
}
