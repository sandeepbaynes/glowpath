import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/ui/cargo_gallery.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/earned_supply_panel.dart';
import 'package:glowpath/ui/rewards_panel.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
  });
  Future<GameController> game({bool funded = false}) async {
    SharedPreferences.setMockInitialValues({});
    final result = GameController(
      preferences: await SharedPreferences.getInstance(),
    );
    await result.load();
    if (funded) {
      for (var round = 0; round < 4; round++) {
        result.updateAttemptTiming(
          const Duration(seconds: 2),
          const Duration(seconds: 30),
        );
        for (final action in result.puzzle.solutionActions) {
          if (result.status.solved) break;
          result.rotate(action);
        }
        expect(result.status.solved, isTrue);
        result.nextPuzzle();
      }
    }
    result.updateAttemptTiming(
      const Duration(seconds: 2),
      const Duration(seconds: 30),
    );
    return result;
  }

  for (final size in [
    const Size(276, 214.4),
    const Size(560, 214.4),
    const Size(345, 620),
    const Size(560, 820),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'cargo shelf and reading fit $size at ${scale}x without scroll',
        (tester) async {
          tester.view.physicalSize = const Size(1500, 1500);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _host(
              size,
              scale,
              RewardsPanel(
                stars: 24,
                equippedTrail: ShipTrail.ember,
                earnedAchievementIds: const {},
                dailyMedals: 0,
                weeklyMedals: 0,
                onEquip: (_) {},
                reduceMotion: true,
                initialCargo: true,
                coinBalance: 87,
                cargoCollection: const {
                  CargoKind.moonPearl: 2,
                  CargoKind.chronoCell: 3,
                },
                powerUps: const {PowerUp.timeCell: 1},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CargoGallery), findsOneWidget);
          for (var specimen = 0; specimen < 6; specimen++) {
            expect(tester.takeException(), isNull);
            expect(find.byType(Scrollable), findsNothing);
            if (specimen == 2) {
              await tester.tap(find.byKey(const ValueKey('cargo-details')));
              await tester.pumpAndSettle();
              final seen = StringBuffer();
              for (var page = 0; page < 120; page++) {
                expect(tester.takeException(), isNull);
                seen.write(
                  '${tester.widget<Text>(find.byKey(const ValueKey('specimen-reading-body'))).data} ',
                );
                final next = tester.widget<SpaceAction>(
                  find.byKey(const ValueKey('specimen-reading-next')),
                );
                if (next.onPressed == null) break;
                await tester.tap(
                  find.byKey(const ValueKey('specimen-reading-next')),
                );
                await tester.pumpAndSettle();
              }
              expect(seen.toString(), contains('06:00–10:00 local time'));
              expect(seen.toString(), contains('window returns every day'));
              expect(seen.toString(), contains('Cargo is optional'));
              await tester.tap(
                find.byKey(const ValueKey('specimen-reading-back')),
              );
              await tester.pumpAndSettle();
            }
            if (specimen < 5) {
              await tester.tap(find.byKey(const ValueKey('cargo-next')));
              await tester.pumpAndSettle();
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets('earned supply pages fit $size at ${scale}x', (tester) async {
        tester.view.physicalSize = const Size(1500, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = await game();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _host(
            size,
            scale,
            EarnedSupplyPanel(
              game: controller,
              onHint: () {},
              onSkip: () {},
              onUsePower: (_) {},
              onLegacyStore: () {},
              reduceMotion: true,
            ),
          ),
        );
        for (var resource = 0; resource < 4; resource++) {
          await tester.tap(
            find.byKey(ValueKey('earned-supply-page-$resource')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(Scrollable), findsNothing);
          final buy = tester.widget<SpaceAction>(
            find.byKey(ValueKey('earned-supply-buy-$resource')),
          );
          expect(buy.onPressed, isNull, reason: 'No coins to spend');
        }
        await tester.tap(find.byKey(const ValueKey('earned-supply-details')));
        await tester.pumpAndSettle();
        expect(find.byType(SpecimenReadingView), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('arrival collection opens the awarded dawn prism', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Size(345, 620),
        1,
        RewardsPanel(
          stars: 24,
          equippedTrail: ShipTrail.ember,
          earnedAchievementIds: const {},
          dailyMedals: 0,
          weeklyMedals: 0,
          onEquip: (_) {},
          reduceMotion: true,
          initialCargo: true,
          initialCargoKind: CargoKind.dawnPrism,
          cargoCollection: const {CargoKind.dawnPrism: 2},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CargoGallery), findsOneWidget);
    expect(find.text('Dawn prism'), findsOneWidget);
    expect(find.text('2 collected'), findsOneWidget);
    expect(find.text('3/6'), findsOneWidget);
    expect(find.text('Moon pearl'), findsNothing);
    expect(find.text('Undiscovered'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('cargo-next')));
    await tester.pumpAndSettle();
    expect(find.text('Night opal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'earned shelf charges exact coin costs and only uses through callbacks',
    (tester) async {
      final controller = await game(funded: true);
      addTearDown(controller.dispose);
      var hinted = 0, skipped = 0, openedStore = 0;
      PowerUp? used;
      await tester.pumpWidget(
        _host(
          const Size(345, 620),
          1,
          EarnedSupplyPanel(
            game: controller,
            reduceMotion: true,
            onHint: () => hinted++,
            onSkip: () => skipped++,
            onUsePower: (item) => used = item,
            onLegacyStore: () => openedStore++,
          ),
        ),
      );
      final initial = controller.coinBalance;
      await tester.tap(find.byKey(const ValueKey('earned-supply-buy-0')));
      await tester.pumpAndSettle();
      expect(controller.coinBalance, initial - 10);
      expect(controller.hintCredits, 1);
      expect(hinted, 0);
      await tester.tap(find.byKey(const ValueKey('earned-supply-use-0')));
      await tester.pumpAndSettle();
      expect(hinted, 1);
      await tester.tap(find.byKey(const ValueKey('earned-supply-page-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('earned-supply-buy-2')));
      await tester.pumpAndSettle();
      expect(controller.coinBalance, initial - 35);
      expect(controller.powerUpCount(PowerUp.timeCell), 1);
      expect(used, isNull);
      await tester.tap(find.byKey(const ValueKey('earned-supply-use-2')));
      await tester.pumpAndSettle();
      expect(used, PowerUp.timeCell);
      await tester.tap(find.byKey(const ValueKey('earned-supply-page-1')));
      await tester.pumpAndSettle();
      final beforeSkip = controller.coinBalance;
      await tester.tap(find.byKey(const ValueKey('earned-supply-buy-1')));
      await tester.pumpAndSettle();
      expect(skipped, 1);
      expect(
        controller.coinBalance,
        beforeSkip,
        reason: 'Root owns the atomic skip',
      );
      await tester.tap(find.byKey(const ValueKey('earned-supply-store')));
      await tester.pumpAndSettle();
      expect(openedStore, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _host(Size size, double scale, Widget child) => MaterialApp(
  theme: gameTheme(),
  home: Scaffold(
    body: Center(
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  ),
);
