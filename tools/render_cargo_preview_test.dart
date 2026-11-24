// Capture the shipped app's courier, optional pickup and arrival sequence.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  testWidgets('capture cargo pickup from its relay into the hold', (
    tester,
  ) async {
    const capture = ValueKey('cargo-film');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'journeyLevel': 31});
    final game = GameController(
      preferences: await SharedPreferences.getInstance(),
      now: () => DateTime(2026, 11, 23, 8),
    );
    await game.load();
    var now = Duration.zero;
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: GlowpathApp(
          controller: game,
          ambientMotion: false,
          showBriefings: false,
          clockNow: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    now = const Duration(seconds: 9);
    await tester.pump(const Duration(milliseconds: 200));
    for (final action in game.puzzle.solutionActions) {
      if (game.status.solved) break;
      game.rotate(action);
    }
    await tester.pump();
    expect(game.lastReward?.cargoId, CargoKind.dawnPrism.name);
    final output = Directory('build/review/cargo-0.8.0-frames');
    await tester.runAsync(() => output.create(recursive: true));
    for (var frame = 0; frame <= 195; frame++) {
      if (frame > 0) await tester.pump(const Duration(microseconds: 33333));
      expect(tester.takeException(), isNull, reason: 'Frame $frame');
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/${frame.toString().padLeft(4, '0')}.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    await game.flush();
    game.dispose();
  });
}
