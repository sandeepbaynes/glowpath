import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/services/flight_support.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/earned_supply_panel.dart';
import 'package:glowpath/ui/flight_settings.dart';
import 'package:glowpath/ui/flight_support_panel.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:glowpath/ui/rewards_panel.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _paneSize = Size(393, 350);

void main() {
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final scale in [1.0, 1.5, 3.0]) {
    testWidgets('every settings page fits a clamshell pane at ${scale}x', (
      tester,
    ) async {
      final game = await _game();
      addTearDown(game.dispose);
      await tester.pumpWidget(
        _host(
          scale,
          FlightSettings(
            game: game,
            demo: true,
            onRestart: () {},
            onSupport: () {},
            onLeague: () {},
            onRewards: () {},
            onLicenses: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var section = 0; section < 3; section++) {
        await tester.tap(find.byKey(ValueKey('settings-section-$section')));
        await tester.pumpAndSettle();
        final pager = find.byKey(const ValueKey('settings-page'));
        final count = pager.evaluate().isEmpty
            ? 1
            : int.parse(tester.widget<Text>(pager).data!.split(' / ').last);
        for (var page = 0; page < count; page++) {
          _checkPane(tester, scale, 'settings section $section page $page');
          if (page + 1 < count) {
            await tester.tap(find.byKey(const ValueKey('settings-next')));
            await tester.pumpAndSettle();
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('free support stays usable in a clamshell pane at ${scale}x', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final support = FlightSupport(mock: true);
      await support.initialize();
      addTearDown(support.dispose);
      var skips = 0;
      await tester.pumpWidget(
        _host(
          scale,
          FlightSupportPanel(
            support: support,
            canSkip: true,
            onSkip: () => skips++,
            reduceMotion: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      _checkPane(tester, scale, 'skip support');
      await tester.tap(find.byKey(const ValueKey('skip-level')));
      await tester.pumpAndSettle();
      expect(skips, 1);
      await tester.tap(find.byKey(const ValueKey('reward-skip')));
      await tester.pumpAndSettle();
      expect(support.skipCredits, 1);
      _checkPane(tester, scale, 'skip reward');
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is OrbitMode && widget.label == 'Hints',
        ),
      );
      await tester.pumpAndSettle();
      _checkPane(tester, scale, 'hint support');
      await tester.tap(find.byKey(const ValueKey('reward-hints')));
      await tester.pumpAndSettle();
      expect(support.hintCredits, 6);
      _checkPane(tester, scale, 'hint reward');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cargo and supplies fit a clamshell pane at ${scale}x', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
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
            cargoCollection: const {CargoKind.moonPearl: 2},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var specimen = 0; specimen < 6; specimen++) {
        _checkPane(tester, scale, 'cargo $specimen');
        if (specimen < 5) {
          await tester.tap(find.byKey(const ValueKey('cargo-next')));
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(find.byKey(const ValueKey('cargo-details')));
      await tester.pumpAndSettle();
      _checkPane(tester, scale, 'cargo details');
      final game = await _game();
      addTearDown(game.dispose);
      await tester.pumpWidget(
        _host(
          scale,
          EarnedSupplyPanel(
            game: game,
            onHint: () {},
            onSkip: () {},
            onUsePower: (_) {},
            onLegacyStore: () {},
            reduceMotion: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var page = 0; page < 4; page++) {
        await tester.tap(find.byKey(ValueKey('earned-supply-page-$page')));
        await tester.pumpAndSettle();
        _checkPane(tester, scale, 'supply $page');
      }
      await tester.tap(find.byKey(const ValueKey('earned-supply-details')));
      await tester.pumpAndSettle();
      _checkPane(tester, scale, 'supply details');
      await tester.pumpWidget(const SizedBox());
    });
  }
}

Future<GameController> _game() async {
  SharedPreferences.setMockInitialValues({});
  final game = GameController(
    preferences: await SharedPreferences.getInstance(),
    snapshotWriter: (_) async => true,
  );
  await game.load();
  return game;
}

Widget _host(double scale, Widget child) => MaterialApp(
  theme: gameTheme(),
  home: Scaffold(
    body: Center(
      child: SizedBox.fromSize(
        size: _paneSize,
        child: MediaQuery(
          data: MediaQueryData(
            size: _paneSize,
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: OrbitSheet(
            title: 'FLIGHT PANEL',
            floating: true,
            fit: true,
            onClose: () {},
            child: child,
          ),
        ),
      ),
    ),
  ),
);

void _checkPane(WidgetTester tester, double scale, String stage) {
  expect(tester.takeException(), isNull, reason: stage);
  expect(find.byType(Scrollable), findsNothing, reason: stage);
  final sheet = find.byType(OrbitSheet);
  final area = tester.getRect(sheet);
  for (final element
      in find
          .descendant(
            of: sheet,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text ||
                  widget is SpaceAction ||
                  widget is OrbitMode ||
                  widget is OrbitUtility,
            ),
          )
          .evaluate()) {
    expect(
      MediaQuery.textScalerOf(element).scale(16),
      scale * 16,
      reason: '$stage preserves requested text scale',
    );
    final render = element.renderObject;
    if (render is! RenderBox || !render.hasSize) continue;
    final rect = Rect.fromPoints(
      render.localToGlobal(Offset.zero),
      render.localToGlobal(render.size.bottomRight(Offset.zero)),
    );
    expect(rect.top, greaterThanOrEqualTo(area.top - 1), reason: stage);
    expect(rect.bottom, lessThanOrEqualTo(area.bottom + 1), reason: stage);
    expect(rect.left, greaterThanOrEqualTo(area.left - 1), reason: stage);
    expect(rect.right, lessThanOrEqualTo(area.right + 1), reason: stage);
    if (element.widget is! Text) {
      expect(rect.height, greaterThanOrEqualTo(48), reason: stage);
      expect(rect.width, greaterThanOrEqualTo(48), reason: stage);
    }
  }
}
