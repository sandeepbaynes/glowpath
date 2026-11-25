import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [
    const Size(1366, 1024),
    const Size(1280, 800),
    const Size(1024, 1366),
    const Size(820, 1180),
  ]) {
    test('arrival route dots leave the tablet reward footer clear on $size', () async {
      final focus = size.width > size.height ? .22 : .38;
      final empty = await _paint(
        size,
        focus,
        0,
        contentBottom: size.height - 300,
      );
      final charted = await _paint(
        size,
        focus,
        15,
        contentBottom: size.height - 300,
      );
      // Only the decorative dots differ between these two actual paint frames.
      // The measured HUD edge now fits the universe above the controls rather
      // than fading away route markers that would overlap them.
      final changed = _changedPixels(
        empty,
        charted,
        size,
        size.height.toInt() - 296,
      );
      expect(
        changed,
        0,
        reason: 'Route markers must not compete with reward text or Play.',
      );
      if (size == const Size(1366, 1024)) {
        expect(
          _changedPixels(empty, charted, size, 0),
          greaterThan(0),
          reason: 'The upper orbit remains visible; this must not hide all markers.',
        );
      }
    });
  }

  for (final entry in [
    (size: const Size(375, 667), focus: .38),
    (size: const Size(844, 390), focus: .22),
    (size: const Size(1024, 744), focus: .36),
  ]) {
    test(
      'standalone maps retain their unreserved universe at $entry',
      () async {
        final empty = await _paint(entry.size, entry.focus, 0);
        final charted = await _paint(entry.size, entry.focus, 15);
        expect(
          _changedPixels(
            empty,
            charted,
            entry.size,
            entry.size.height.toInt() - 296,
          ),
          greaterThan(0),
          reason: 'Separate map panels have no overlaid footer to reserve.',
        );
      },
    );
  }
}

Future<Uint8List> _paint(
  Size size,
  double focus,
  int completed, {
  double? contentBottom,
}) async {
  final recorder = ui.PictureRecorder();
  final painter = VoyageDepthPainter(
    current: VoyageWorld.forLevel(751),
    approach: 1,
    routesAtDestination: completed,
    verticalFocus: focus,
    contentBottom: contentBottom,
  );
  painter.paint(ui.Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = Uint8List.fromList(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return result;
}

int _changedPixels(Uint8List a, Uint8List b, Size size, int firstRow) {
  var changed = 0;
  final first = firstRow.clamp(0, size.height.toInt()) * size.width.toInt() * 4;
  for (var offset = first; offset < a.length; offset += 4) {
    if (a[offset] != b[offset] ||
        a[offset + 1] != b[offset + 1] ||
        a[offset + 2] != b[offset + 2] ||
        a[offset + 3] != b[offset + 3]) {
      changed++;
    }
  }
  return changed;
}
