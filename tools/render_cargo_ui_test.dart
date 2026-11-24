// Capture the shipped gallery/shop widgets with isolated review data.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/earned_supply_panel.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:glowpath/ui/rewards_panel.dart';
import 'package:glowpath/ui/space_scenery.dart';
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
  testWidgets('capture earned cargo gallery and resource shelf', (
    tester,
  ) async {
    // This is a Flutter test fixture kept with the other capture tools.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final game = GameController(
      preferences: await SharedPreferences.getInstance(),
    );
    await game.load();
    for (var round = 0; round < 5; round++) {
      game.updateAttemptTiming(
        const Duration(seconds: 3),
        const Duration(seconds: 30),
      );
      for (final action in game.puzzle.solutionActions) {
        if (game.status.solved) break;
        game.rotate(action);
      }
      game.nextPuzzle();
    }
    game.updateAttemptTiming(
      const Duration(seconds: 3),
      const Duration(seconds: 30),
    );
    game.buyPowerUp(PowerUp.timeCell);
    const key = ValueKey('cargo-review-capture');
    for (final (name, viewport, scale, supply) in [
      ('cargo-phone', const Size(393, 852), 1.0, false),
      ('cargo-tablet', const Size(1024, 1366), 1.0, false),
      ('cargo-large-type', const Size(844, 390), 3.0, false),
      ('supply-phone', const Size(393, 852), 1.0, true),
      ('supply-large-type', const Size(844, 390), 3.0, true),
    ]) {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      final panel = supply
          ? EarnedSupplyPanel(
              game: game,
              onHint: () {},
              onSkip: () {},
              onUsePower: (_) {},
              onLegacyStore: () {},
              initialPage: 2,
              reduceMotion: true,
            )
          : RewardsPanel(
              stars: 24,
              equippedTrail: ShipTrail.ember,
              earnedAchievementIds: const {'first_signal', 'first_cargo'},
              dailyMedals: 1,
              weeklyMedals: 0,
              onEquip: (_) {},
              reduceMotion: true,
              coinBalance: 86,
              initialCargo: true,
              cargoCollection: const {
                CargoKind.moonPearl: 2,
                CargoKind.dawnPrism: 1,
                CargoKind.chronoCell: 3,
              },
              powerUps: const {PowerUp.timeCell: 1},
            );
      final sheet = Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: math.min(viewport.width, 600),
          height: math.min(820, viewport.height * .92),
          child: OrbitSheet(
            title: supply ? 'FLIGHT SUPPLIES' : 'YOUR COLLECTION',
            fit: true,
            onClose: () {},
            child: panel,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: MediaQueryData(
              size: viewport,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: SpaceBackdrop(
                  level: 31,
                  reduceMotion: true,
                  child: sheet,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/screenshots/0.8.0-$name.png')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    game.dispose();
  });
}
