// Internal native layout QA entry point; never use for a shipped build.
// flutter run -t tools/native_review.dart --dart-define=REVIEW_LEVEL=1 \
//   --dart-define=MOCK_SERVICES=true --dart-define=ENABLE_ADS=false \
//   --dart-define=ENABLE_PURCHASES=false
// Device Hub pose changes use the real native FoldPosture bridge. Preferences
// are process-local mocks, so this entry point cannot overwrite player saves.
// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/game/game_controller.dart';
import '../lib/main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('ENABLE_ADS') ||
      const bool.fromEnvironment('ENABLE_PURCHASES') ||
      const String.fromEnvironment('LEADERBOARD_URL').isNotEmpty) {
    throw StateError('Native layout review requires live services disabled.');
  }
  const requestedLevel = int.fromEnvironment('REVIEW_LEVEL', defaultValue: 1);
  final level = requestedLevel < 1 ? 1 : requestedLevel;
  SharedPreferences.setMockInitialValues({'journeyLevel': level});
  final game = GameController(
    preferences: await SharedPreferences.getInstance(),
    now: () => DateTime.utc(2026, 11, 24, 12),
  );
  await game.load();
  runApp(
    GlowpathApp(
      controller: game,
      showBriefings: false,
      clockNow: () => Duration.zero,
      startOnVoyage: false,
      // Leave foldGeometry unset: GameScreen owns the real native FoldPosture.
    ),
  );
}
