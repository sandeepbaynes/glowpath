import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/cargo.dart';
import 'package:glowpath/ui/cargo_model.dart';
import 'package:glowpath/ui/design.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('capture all six handcrafted meshes from front and rear', (
    tester,
  ) async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    const key = ValueKey('cargo-model-sheet');
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: Palette.paper,
            body: Column(
              children: [
                for (final yaw in [-.22, 2.2])
                  Expanded(
                    child: Row(
                      children: [
                        for (final kind in CargoKind.values)
                          Expanded(
                            child: Column(
                              children: [
                                const SizedBox(height: 22),
                                Text(
                                  kind.label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Palette.light,
                                  ),
                                ),
                                Expanded(
                                  child: CustomPaint(
                                    painter: CargoModelPainter(
                                      kind: kind,
                                      yaw: yaw,
                                      pitch: -.24,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                                Text(
                                  yaw < 0
                                      ? 'Front three-quarter'
                                      : 'Rear three-quarter',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Palette.secondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('docs/screenshots/cargo-mesh-review.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
