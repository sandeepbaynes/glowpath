import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/mission_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'planning and hints never unlock a mission before successful flight',
    () async {
      final preferences = await _preferences();
      final game = _game(preferences);
      await game.load();
      final before = game.rotations;
      expect(game.requestHint(), isTrue);
      expect(game.rotations, before);
      expect(game.moves, 0);
      expect(game.assisted, isTrue);
      _planSafeFlight(game);
      expect(game.highestUnlocked, 1);
      expect(game.stars, 0);
      expect(game.flightResult, isNull);
      final result = game.launch();
      expect(result.success, isTrue);
      expect(game.highestUnlocked, 2);
      expect(game.completedLevels, {1});
      expect(game.stars, 3);
      expect(identical(game.launch(), result), isTrue);
      expect(game.turn(0), isFalse);
      expect(game.undo(), isFalse);
      expect(game.retry(), isTrue);
      expect(game.attempt, 2);
      expect(game.launch().success, isTrue);
      expect(game.stars, 3);
      expect(game.next(), isTrue);
      expect(game.currentLevel, 2);
      expect(game.selectUnlocked(3), isFalse);
      expect(game.selectUnlocked(1), isTrue);
      _planSafeFlight(game);
      expect(game.launch().success, isTrue);
      expect(game.stars, 3);
      expect(game.highestUnlocked, 2);
    },
  );

  test(
    'retry keeps the plan and history while starting a new flight attempt',
    () async {
      final preferences = await _preferences();
      final game = _game(preferences);
      await game.load();
      game.turn(0);
      final plan = game.rotations;
      final failed = game.launch();
      expect(failed.success, isFalse);
      expect(game.highestUnlocked, 1);
      expect(game.attempt, 1);
      expect(game.retry(), isTrue);
      expect(game.rotations, plan);
      expect(game.moves, 1);
      expect(game.canUndo, isTrue);
      expect(game.attempt, 2);
      expect(game.flightResult, isNull);
      expect(game.undo(), isTrue);
      expect(game.moves, 0);
      expect(game.retry(), isFalse);
    },
  );

  test(
    'plans and launched outcomes resume without touching legacy saves',
    () async {
      final preferences = await _preferences({
        'glowpath.snapshot.v1': 'legacy-save-is-untouched',
        MissionController.storageKey: jsonEncode({
          'schemaVersion': 1,
          'campaignVersion': 1,
          'completed': [1, 2, 3],
        }),
      });
      final game = _game(preferences);
      await game.load();
      expect(game.currentLevel, 4);
      game.turn(0);
      game.hint();
      final rotations = game.rotations;
      final moves = game.moves;
      await game.flush();
      final resumed = _game(preferences);
      await resumed.load();
      expect(resumed.rotations, rotations);
      expect(resumed.moves, moves);
      expect(resumed.assisted, isTrue);
      expect(resumed.canUndo, isTrue);
      expect(resumed.highestUnlocked, 4);
      expect(resumed.stars, 9);
      final result = resumed.launch();
      await resumed.flush();
      final afterFlight = _game(preferences);
      await afterFlight.load();
      expect(afterFlight.flightResult?.success, result.success);
      expect(afterFlight.flightResult?.failure, result.failure);
      expect(afterFlight.flightResult?.failureCell, result.failureCell);
      expect(afterFlight.attempt, resumed.attempt);
      expect(
        preferences.getString('glowpath.snapshot.v1'),
        'legacy-save-is-untouched',
      );
    },
  );

  test('locked relays and blocks reject controller turns', () async {
    final preferences = await _preferences({
      MissionController.storageKey: jsonEncode({
        'schemaVersion': 1,
        'campaignVersion': 1,
        'completed': [1, 2, 3, 4],
      }),
    });
    final game = _game(preferences);
    await game.load();
    expect(game.currentLevel, 5);
    expect(game.turn(11), isFalse);
    expect(game.moves, 0);
    game.selectUnlocked(4);
    expect(game.turn(12), isFalse);
    expect(game.moves, 0);
    expect(game.turn(-1), isFalse);
    expect(game.turn(25), isFalse);
  });

  test('daily flight freezes its UTC date, preserves campaign and never unlocks it', () async {
    final preferences = await _preferences();
    var now = DateTime.utc(2026, 11, 22, 23, 59);
    final game = _game(preferences, now: () => now);
    await game.load();
    game.turn(0);
    final campaignPlan = game.rotations;
    game.setDaily(true);
    game.requestHint();
    final dailyNumber = game.currentLevel;
    final dailyPlan = game.rotations;
    now = now.add(const Duration(minutes: 2));
    await game.flush();
    final resumed = _game(preferences, now: () => now);
    await resumed.load();
    expect(resumed.isDaily, isTrue);
    expect(resumed.dailyDate, '2026-11-22');
    expect(resumed.dailyResetAt, DateTime.utc(2026, 11, 23));
    expect(resumed.currentLevel, dailyNumber);
    expect(resumed.rotations, dailyPlan);
    expect(resumed.assisted, isTrue);
    _planSafeFlight(resumed);
    expect(resumed.launch().success, isTrue);
    expect(resumed.dailyCompleted, isTrue);
    expect(resumed.highestUnlocked, 1);
    expect(resumed.completedLevels, isEmpty);
    expect(resumed.stars, 3);
    resumed.retry();
    expect(resumed.launch().success, isTrue);
    expect(resumed.stars, 3);
    resumed.setDaily(false);
    expect(resumed.rotations, campaignPlan);
    expect(resumed.moves, 1);
    resumed.setDaily(true);
    expect(resumed.dailyDate, '2026-11-23');
    expect(resumed.dailyCompleted, isFalse);
    expect(resumed.dailyResetAt, DateTime.utc(2026, 11, 24));
  });

  test('invalid saves remain playable and failed writes can recover', () async {
    final preferences = await _preferences({
      MissionController.storageKey: '{invalid',
    });
    var fail = true;
    final game = _game(
      preferences,
      snapshotWriter: (snapshot) async {
        if (fail) throw StateError('Storage blocked');
        return preferences.setString(MissionController.storageKey, snapshot);
      },
    );
    await game.load();
    await game.flush();
    expect(game.ready, isTrue);
    expect(game.saveError, isTrue);
    expect(game.currentLevel, 1);
    expect(game.turn(0), isTrue);
    fail = false;
    await game.flush();
    expect(game.saveError, isFalse);
    final data = jsonDecode(
      preferences.getString(MissionController.storageKey)!,
    ) as Map<String, dynamic>;
    expect((data['campaign'] as Map<String, dynamic>)['moves'], 1);
    expect(data['completed'], isEmpty);
  });
}

Future<SharedPreferences> _preferences([
  Map<String, Object> values = const {},
]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

MissionController _game(
  SharedPreferences preferences, {
  DateTime Function()? now,
  Future<bool> Function(String snapshot)? snapshotWriter,
}) {
  final game = MissionController(
    preferences: preferences,
    now: now ?? () => DateTime.utc(2026, 11, 22, 12),
    snapshotWriter: snapshotWriter,
  );
  addTearDown(() async {
    await game.flush();
    game.dispose();
  });
  return game;
}

void _planSafeFlight(MissionController game) {
  for (
    var step = 0;
    step < 25 && !game.mission.launch(ignoreRisk: true).success;
    step++
  ) {
    expect(game.hint(), isTrue);
  }
  expect(game.mission.launch(ignoreRisk: true).success, isTrue);
}
