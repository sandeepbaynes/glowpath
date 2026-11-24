import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/services/native_ads.dart';
import 'package:glowpath/ui/native_banner_slot.dart';
import 'package:glowpath/ui/puzzle_board.dart';

void main() {
  for (final size in [
    const Size(375, 667),
    const Size(393, 852),
    const Size(1024, 1366),
  ]) {
    testWidgets('reserved banner stays below navigation and board at $size', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      SharedPreferences.setMockInitialValues({'journeyLevel': 31});
      final game = GameController(
        preferences: await SharedPreferences.getInstance(),
      );
      await game.load();
      final ads = NativeAds(config: const NativeAdConfig(enabled: false))
        ..ready = true;
      addTearDown(game.dispose);
      addTearDown(ads.dispose);
      await tester.pumpWidget(
        GlowpathApp(
          controller: game,
          ads: ads,
          ambientMotion: false,
          showBriefings: false,
          clockNow: () => Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
      final banner = tester.getRect(find.byType(NativeBannerSlot));
      final navigation = tester.getRect(
        find.byKey(const ValueKey('shared-navigation')),
      );
      final board = tester.getRect(find.byType(PuzzleBoard));
      expect(banner.bottom, lessThanOrEqualTo(size.height));
      expect(navigation.bottom, lessThanOrEqualTo(banner.top));
      expect(board.bottom, lessThanOrEqualTo(navigation.top));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
