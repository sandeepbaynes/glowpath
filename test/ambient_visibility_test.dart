import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('planet surfaces turn visibly in two seconds with fixed silhouettes', () async {
    const size = Size(390, 844);
    for (var world = 0; world < 5; world++) {
      VoyageDepthPainter painter(double phase) => VoyageDepthPainter(
        current: VoyageWorld.forLevel(world * 15 + 1),
        approach: 1,
        routesAtDestination: 2,
        showCourier: true,
        ambient: AlwaysStoppedAnimation(phase),
        verticalFocus: .38,
      );
      final still = painter(0);
      final moving = painter(2 / 180);
      expect(moving.currentPlanetBounds(size), still.currentPlanetBounds(size));
      expect(moving.courierPosition(size), still.courierPosition(size));
      final bounds = still.currentPlanetBounds(size);
      final interior = bounds.deflate(bounds.width * .15);
      final before = await _paint(still, size);
      final after = await _paint(moving, size);
      final changed = _changedPixels(before, after, size, interior);
      expect(
        changed,
        greaterThan(150),
        reason:
            '${still.current.name} has visible surface movement, not merely a running ticker.',
      );
      final loop = await _paint(painter(1), size);
      expect(
        _changedPixels(before, loop, size, Offset.zero & size),
        lessThan(8),
        reason: 'The surface and star cycle meets itself without a jump.',
      );
    }
  });

  testWidgets(
    'puzzle home visibly glides in two seconds without moving controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: const ValueKey('home-motion-capture'),
            child: SpaceBackdrop(
              level: 11,
              reduceMotion: false,
              child: Center(
                child: Builder(
                  builder: (_) {
                    builds++;
                    return const Text(
                      'Puzzle',
                      key: ValueKey('steady-control'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('home-motion-capture')),
      );
      Future<Uint8List> pixels() async => (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!.buffer.asUint8List();
      }))!;
      final before = await pixels();
      final initialBuilds = builds;
      final controlBounds = tester.getRect(
        find.byKey(const ValueKey('steady-control')),
      );
      await tester.pump(const Duration(seconds: 2));
      final after = await pixels();
      const size = Size(390, 844);
      expect(
        _changedPixels(before, after, size, Offset.zero & size),
        greaterThan(160),
      );
      expect(
        _changedPixels(
          before,
          after,
          size,
          const Rect.fromLTWH(0, 200, 390, 644),
        ),
        greaterThan(20),
        reason: 'The star field below the home planet glides visibly too.',
      );
      expect(builds, initialBuilds);
      expect(
        tester.getRect(find.byKey(const ValueKey('steady-control'))),
        controlBounds,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<Uint8List> _paint(VoyageDepthPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

int _changedPixels(Uint8List before, Uint8List after, Size size, Rect region) {
  var changed = 0;
  for (
    var y = region.top.ceil().clamp(0, size.height.toInt());
    y < region.bottom.floor().clamp(0, size.height.toInt());
    y++
  ) {
    for (
      var x = region.left.ceil().clamp(0, size.width.toInt());
      x < region.right.floor().clamp(0, size.width.toInt());
      x++
    ) {
      final start = (y * size.width.toInt() + x) * 4;
      if ((before[start] - after[start]).abs() +
              (before[start + 1] - after[start + 1]).abs() +
              (before[start + 2] - after[start + 2]).abs() >=
          12) {
        changed++;
      }
    }
  }
  return changed;
}
