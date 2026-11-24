// Internal visual review entry point; never used by the shipped app.
// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/main.dart';
import '../lib/game/game_controller.dart';
import '../lib/game/puzzle.dart';
import '../lib/services/flight_league.dart';
import '../lib/services/flight_support.dart';
import '../lib/ui/design.dart';
import '../lib/ui/flight_failure.dart';
import '../lib/ui/flight_league_panel.dart';
import '../lib/ui/flight_manual.dart';
import '../lib/ui/flight_settings.dart';
import '../lib/ui/flight_support_panel.dart';
import '../lib/ui/earned_supply_panel.dart';
import '../lib/ui/launch_splash.dart';
import '../lib/ui/orbit_sheet.dart';
import '../lib/ui/planet_flight.dart';
import '../lib/ui/mission_briefing.dart';
import '../lib/ui/rewards_panel.dart';
import '../lib/ui/space_scenery.dart';
import '../lib/ui/voyage_route_log.dart';

@JS('location.assign')
external void _navigate(JSString url);
void openScene(String name) => _navigate('?scene=$name'.toJS);
int? get reviewPlanet => int.tryParse(Uri.base.queryParameters['planet'] ?? '');
int get reviewLevel => (math.max(1, reviewPlanet ?? 1) - 1) * 15 + 1;
const scenes = <String, String>{
  'intro': '01 · First flight',
  'puzzle': '02 · Opening route',
  'advanced': '03 · Advanced route',
  'daily': '04 · Daily sprint',
  'weekly': '05 · Weekly gauntlet',
  'arrival': '06 · Arrival',
  'map': '07 · Voyage map',
  'collection': '08 · Your collection',
  'support': '09 · Flight support',
  'league': '10 · Flight league',
  'settings': '11 · Flight controls',
  'manual': '12 · Flight notes',
  'failure': '13 · Signal lost',
  'splash': '14 · Launch splash',
  'transit': '15 · Planet approach',
  'salvage': '16 · Optional cargo route',
  'cargo': '17 · Cargo collection',
  'supplies': '18 · Earned flight supplies',
  'daily-result': '19 · Sprint result',
  'weekly-result': '20 · Gauntlet result',
  'achievements': '21 · Achievements',
  'records': '22 · Flight log',
};
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scene = Uri.base.queryParameters['scene'] ?? 'index';
  SharedPreferences.setMockInitialValues({
    'journeyLevel': reviewPlanet != null
        ? reviewLevel
        : ['salvage', 'cargo', 'supplies'].contains(scene)
        ? 31
        : scene == 'advanced'
        ? 211
        : 1,
  });
  final game = GameController(
    preferences: await SharedPreferences.getInstance(),
    now: () => DateTime(2026, 11, 23, 8),
  );
  await game.load();
  if (scene.startsWith('daily')) game.setMode(GameMode.daily);
  if (scene.startsWith('weekly')) game.setMode(GameMode.weekly);
  if (scene.endsWith('-result')) {
    final count = game.isWeekly ? 5 : 3;
    for (var stage = 0; stage < count; stage++) {
      game.updateAttemptTiming(
        const Duration(seconds: 6),
        game.challengeLaunchBudget,
      );
      for (final action in game.puzzle.solutionActions) {
        if (game.status.solved) break;
        game.rotate(action);
      }
      if (stage < count - 1) game.nextPuzzle();
    }
  }
  if ([
    'arrival',
    'collection',
    'achievements',
    'records',
    'cargo',
    'supplies',
  ].contains(scene)) {
    final count = ['collection', 'achievements', 'records'].contains(scene)
        ? 18
        : scene == 'cargo'
        ? 31
        : 1;
    for (var route = 0; route < count; route++) {
      game.updateAttemptTiming(
        const Duration(seconds: 8),
        const Duration(seconds: 30),
      );
      for (final action in game.puzzle.solutionActions) {
        if (game.status.solved) break;
        game.rotate(action);
      }
      if (route < count - 1 || scene == 'supplies') {
        game.nextPuzzle();
      }
    }
  }
  final support = FlightSupport(mock: true);
  await support.initialize();
  final league = FlightLeague(mock: true);
  await league.join();
  runApp(Review(scene: scene, game: game, support: support, league: league));
}

class Review extends StatelessWidget {
  const Review({
    super.key,
    required this.scene,
    required this.game,
    required this.support,
    required this.league,
  });
  final String scene;
  final GameController game;
  final FlightSupport support;
  final FlightLeague league;
  @override
  Widget build(BuildContext context) {
    if ([
      'intro',
      'puzzle',
      'advanced',
      'daily',
      'weekly',
      'arrival',
      'map',
      'salvage',
      'daily-result',
      'weekly-result',
    ].contains(scene)) {
      return GlowpathApp(
        controller: game,
        ambientMotion: true,
        showBriefings: scene == 'intro',
        clockNow: Uri.base.queryParameters['clock'] == 'live'
            ? null
            : () => Duration.zero,
        startOnVoyage: scene == 'map',
      );
    }
    return MaterialApp(
      title: 'Glowpath · Design review',
      theme: gameTheme(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            (double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1)
                .clamp(1, 3),
          ),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          if (scene == 'index') {
            return Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Glowpath / design review', style: bookTitle(28)),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Internal gallery. All progress is temporary.',
                      ),
                    ),
                    for (final entry in scenes.entries)
                      TextButton(
                        onPressed: () => openScene(entry.key),
                        child: Text(entry.value),
                      ),
                  ],
                ),
              ),
            );
          }
          if (scene == 'transit') {
            return Scaffold(
              body: PlanetFlight(
                world: VoyageWorld.forLevel(
                  reviewPlanet != null ? reviewLevel : 31,
                ),
                beats: [
                  MissionBriefingBeat(
                    compactText: 'Linked relays turn together.',
                    text:
                        'Approaching ${VoyageWorld.forLevel(reviewPlanet != null ? reviewLevel : 31).name}. Linked relays turn together, even across the board.',
                  ),
                  const MissionBriefingBeat(
                    compactText: 'Align linked relays before launch.',
                    text: 'Align linked relays before launch.',
                  ),
                ],
                onComplete: () => openScene('puzzle'),
              ),
            );
          }
          if (scene == 'splash') return const Scaffold(body: LaunchSplash());
          if (scene == 'failure') {
            return Scaffold(
              body: FlightFailureOverlay(onRetry: () => openScene('puzzle')),
            );
          }
          final title =
              scenes[scene]?.split(' · ').last.toUpperCase() ?? 'REVIEW';
          final child = switch (scene) {
            'collection' || 'cargo' || 'achievements' => ListenableBuilder(
              listenable: game,
              builder: (_, _) => RewardsPanel(
                stars: game.stars,
                equippedTrail: game.equippedTrail,
                earnedAchievementIds: game.earnedAchievementIds,
                dailyMedals: game.dailyMedals,
                weeklyMedals: game.weeklyMedals,
                cargoCollection: game.cargoCollection,
                coinBalance: game.coinBalance,
                powerUps: game.powerUps,
                initialCargo: scene == 'cargo',
                initialAchievements: scene == 'achievements',
                onEquip: (trail) => game.equipTrail(trail),
              ),
            ),
            'records' => VoyageRouteLog(
              frontierLevel: game.journeyLevel,
              currentLevel: game.puzzle.levelNumber,
              records: game.routeRecords,
              onReplay: (_) => openScene('puzzle'),
            ),
            'support' => FlightSupportPanel(
              support: support,
              canSkip: true,
              onSkip: () => openScene('puzzle'),
            ),
            'supplies' => EarnedSupplyPanel(
              game: game,
              onHint: game.useHintCredit,
              onSkip: game.buySkip,
              onUsePower: (power) => power == PowerUp.timeCell
                  ? game.useTimeCell()
                  : game.useRouteLens(),
              onLegacyStore: () => openScene('support'),
            ),
            'league' => FlightLeaguePanel(league: league),
            'settings' => FlightSettings(
              game: game,
              demo: true,
              onRestart: () => openScene('puzzle'),
              onSupport: () => openScene('support'),
              onLeague: () => openScene('league'),
              onRewards: () => openScene('collection'),
              onLicenses: () => showLicensePage(context: context),
            ),
            'manual' => FlightManual(
              puzzle: Puzzle.planet(seed: 927, levelNumber: 211),
              onClose: () => openScene('puzzle'),
            ),
            _ => const Text('Unknown scene'),
          };
          return Scaffold(
            body: SpaceBackdrop(
              level: 4,
              reduceMotion: false,
              child: OrbitPanelFrame(
                title: title,
                fit: true,
                preferredDesktopHeight: scene == 'settings' ? 620 : null,
                onClose: () => openScene('index'),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
