import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/cutout_beacon.dart';
import 'package:glowpath/ui/design.dart';
import 'package:material_ui/material_ui.dart';

const _size = Size(466, 678);
const _camera = Rect.fromLTWH(399.6667, 29.3333, 37, 37);
const _status = Rect.fromLTWH(382, 0, 84, 174);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('beacon never draws in overlapping camera and system regions', () async {
    final bytes = await _render(remaining: const Duration(seconds: 15));
    var outsideInk = 0;
    for (var y = 0; y < _size.height; y++) {
      for (var x = 0; x < _size.width; x++) {
        final alpha = _alpha(bytes, x, y);
        if (_status.contains(Offset(x + .5, y + .5)) ||
            _camera.inflate(2).contains(Offset(x + .5, y + .5))) {
          expect(alpha, 0, reason: 'Reserved pixel ($x, $y) must stay clear');
        } else if (alpha > 0) {
          outsideInk++;
        }
      }
    }
    expect(
      outsideInk,
      greaterThan(100),
      reason: 'Mask must not erase the beacon',
    );
  });

  test(
    'relay follows launch progress without a free-running animation',
    () async {
      final before = await _render(remaining: const Duration(seconds: 30));
      final after = await _render(remaining: Duration.zero);
      expect(
        _markerCenter(before).dy,
        greaterThan(_markerCenter(after).dy + 30),
      );
      expect(_markerCenter(before).dx, lessThan(_status.left));
      expect(_markerCenter(after).dx, lessThan(_status.left));
    },
  );

  test(
    'reduced motion keeps the orbital alignment marker stationary',
    () async {
      final before = await _render(
        remaining: const Duration(seconds: 30),
        reducedMotion: true,
      );
      final after = await _render(
        remaining: Duration.zero,
        reducedMotion: true,
      );
      expect(_markerCenter(before), _markerCenter(after));
    },
  );

  testWidgets('decorative beacon lets gameplay taps pass through', (
    tester,
  ) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const ColoredBox(color: Palette.paper),
            ),
            const CutoutBeacon(
              camera: _camera,
              systemOcclusions: [_camera, _status],
              remaining: Duration(seconds: 15),
              total: Duration(seconds: 30),
              reducedMotion: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(365, 48));
    expect(taps, 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}

Future<ByteData> _render({
  required Duration remaining,
  bool reducedMotion = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  CutoutBeaconPainter(
    camera: _camera,
    systemOcclusions: const [_camera, _status],
    remaining: remaining,
    total: const Duration(seconds: 30),
    reducedMotion: reducedMotion,
    paused: false,
    complete: false,
    trailColor: Palette.light,
  ).paint(canvas, _size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    _size.width.toInt(),
    _size.height.toInt(),
  );
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  picture.dispose();
  return bytes;
}

int _alpha(ByteData bytes, int x, int y) =>
    bytes.getUint8((y * _size.width.toInt() + x) * 4 + 3);

Offset _markerCenter(ByteData bytes) {
  var xSum = 0.0, ySum = 0.0, count = 0;
  for (var y = 0; y < _size.height; y++) {
    for (var x = 0; x < _size.width; x++) {
      if (_alpha(bytes, x, y) > 150) {
        xSum += x;
        ySum += y;
        count++;
      }
    }
  }
  expect(count, greaterThan(0));
  return Offset(xSum / count, ySum / count);
}
