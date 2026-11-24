import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/game/rewards.dart';
import 'package:glowpath/services/flight_league.dart';
import 'package:glowpath/services/flight_support.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_league_panel.dart';
import 'package:glowpath/ui/flight_manual.dart';
import 'package:glowpath/ui/flight_support_panel.dart';
import 'package:glowpath/ui/mission_briefing.dart';
import 'package:glowpath/ui/planet_flight.dart';
import 'package:glowpath/ui/rewards_panel.dart';
import 'package:glowpath/ui/space_scenery.dart';

void main() {
  setUpAll(() async {
    for (final (name, path) in [
      ('Manrope', 'assets/fonts/Manrope-VariableFont_wght.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(path))).load();
    }
  });

  testWidgets('secondary screens render with the real display font', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final support = FlightSupport(mock: true);
    final league = FlightLeague(mock: true);
    await support.initialize();
    await league.join();
    final latePuzzle = Puzzle.planet(seed: 55, levelNumber: 196);
    for (final size in [
      const Size(393, 852),
      const Size(844, 390),
      const Size(1024, 1366),
      const Size(1366, 1024),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final screen in [
        'briefing',
        'new-rule',
        'guide',
        'trails',
        'medals',
        'hints',
        'skips',
        'ad-free',
        'league',
        'flight',
      ]) {
        final widget = switch (screen) {
          'briefing' => MissionBriefing(
            onStart: () {},
            destination: 'Your first flight',
            reduceMotion: true,
          ),
          'new-rule' => MissionBriefing(
            onStart: () {},
            destination: 'Tidal crossings',
            planet: 14,
            beats: mechanicBriefingFor(latePuzzle),
            reduceMotion: true,
          ),
          'guide' => FlightManual(
            puzzle: latePuzzle,
            onClose: () {},
            reduceMotion: true,
          ),
          'trails' || 'medals' => RewardsPanel(
            stars: 45,
            equippedTrail: ShipTrail.aurora,
            earnedAchievementIds: const {
              'first_signal',
              'navigator_5',
              'efficient_200',
            },
            dailyMedals: 2,
            weeklyMedals: 1,
            onEquip: (_) {},
            reduceMotion: true,
          ),
          'hints' || 'skips' || 'ad-free' => FlightSupportPanel(
            support: support,
            onSkip: () {},
            canSkip: true,
            initialPage: screen == 'hints'
                ? 0
                : screen == 'skips'
                ? 1
                : 2,
            reduceMotion: true,
          ),
          'league' => FlightLeaguePanel(league: league, reduceMotion: true),
          _ => PlanetFlight(
            onComplete: () {},
            world: VoyageWorld.forLevel(31),
            beats: mechanicBriefingFor(latePuzzle),
            reduceMotion: true,
          ),
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: RepaintBoundary(
              key: const ValueKey('gallery-frame'),
              child: Scaffold(
                body: screen == 'flight'
                    ? widget
                    : Center(
                        child: SizedBox(
                          width: math.min(560, size.width - 48),
                          height: math.min(600, size.height - 100),
                          child: widget,
                        ),
                      ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (screen == 'medals') {
          await tester.tap(find.byKey(const ValueKey('collection-medals')));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: '$screen at $size');
        expect(find.byType(Scrollable), findsNothing);
        if (const bool.fromEnvironment('CAPTURE_DESIGN')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('gallery-frame')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('/tmp/glowpath-secondary-polish')
                .create(recursive: true);
            await File(
              '/tmp/glowpath-secondary-polish/${size.width.toInt()}-$screen.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
    support.dispose();
    league.dispose();
  });
}
