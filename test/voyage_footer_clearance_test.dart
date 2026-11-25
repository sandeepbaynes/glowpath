import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/services/native_ads.dart';
import 'package:glowpath/ui/space_scenery.dart';

void main() {
  setUpAll(() async {
    for (final (family, path) in [
      ('Manrope', 'assets/fonts/Manrope-VariableFont_wght.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  for (final entry in [
    (
      size: const Size(393, 852),
      top: 59.0,
      bottom: 34.0,
      level: 87,
      scale: 1.0,
      ads: false,
    ),
    (
      size: const Size(375, 667),
      top: 20.0,
      bottom: 0.0,
      level: 13,
      scale: 1.0,
      ads: true,
    ),
    (
      size: const Size(393, 852),
      top: 59.0,
      bottom: 34.0,
      level: 73,
      scale: 1.6,
      ads: false,
    ),
    (
      size: const Size(1024, 1366),
      top: 24.0,
      bottom: 20.0,
      level: 87,
      scale: 1.0,
      ads: true,
    ),
  ]) {
    testWidgets('voyage flight and orbit stay above footer $entry', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = entry.size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(
        top: entry.top,
        bottom: entry.bottom,
      );
      tester.platformDispatcher.textScaleFactorTestValue = entry.scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        instanceManager.channel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          instanceManager.channel,
          null,
        ),
      );
      SharedPreferences.setMockInitialValues({
        'journeyLevel': entry.level,
        'stars': 288,
      });
      final game = GameController(
        preferences: await SharedPreferences.getInstance(),
        snapshotWriter: (_) async => true,
      );
      await game.load();
      final ads = NativeAds(config: const NativeAdConfig(enabled: false))
        ..ready = entry.ads;
      addTearDown(game.dispose);
      addTearDown(ads.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-capture'),
          child: GlowpathApp(
            controller: game,
            ads: ads,
            ambientMotion: false,
            showBriefings: false,
            clockNow: () => Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 250 && !game.status.solved; i++) {
        game.hint();
      }
      expect(game.status.solved, isTrue);
      await tester.pumpAndSettle();
      final scene = find.byKey(const ValueKey('next-stop-flight'));
      final sceneRect = tester.getRect(scene);
      final painter =
          tester.widget<CustomPaint>(scene).painter! as VoyageDepthPainter;
      final footer = tester.getRect(find.byKey(const ValueKey('open-rewards')));
      expect(painter.contentBottom, isNotNull);
      for (var i = 0; i <= 40; i++) {
        final progress = i / 40;
        final position =
            painter.courierPosition(sceneRect.size, progress: progress) +
            sceneRect.topLeft;
        final extent =
            painter.courierUnit(sceneRect.size, progress: progress) * 2.2;
        expect(
          position.dy + extent,
          lessThanOrEqualTo(footer.top - 16),
          reason: 'The moving rocket must never cross collection progress.',
        );
      }
      final planet = painter
          .currentPlanetBounds(sceneRect.size)
          .shift(sceneRect.topLeft);
      for (var route = 0; route < 15; route++) {
        final dotY =
            planet.center.dy +
            math.sin(.72 + route * .76 / 14) * planet.width / 2 * 1.22;
        expect(dotY + 3, lessThan(footer.top - 16));
      }
      expect(
        find.byKey(const ValueKey('next-puzzle')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (Platform.environment['GLOWPATH_RENDER_REVIEW'] == '1' &&
          entry.size.width == 393 &&
          entry.scale == 1) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('review-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/glowpath-voyage-clearance.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
