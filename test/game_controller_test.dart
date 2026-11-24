import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a diverted route hints at the earliest reference mismatch, not row order',
    () async {
      // Keep this exact diverted-path regression as a saved legacy lesson.
      // Fresh routes now use smaller, progressively generated boards.
      final initial = Puzzle.introduction(levelNumber: 3, seed: 2929);
      final preferences = await _preferences({
        GameController.storageKey: jsonEncode({
          'schemaVersion': 1,
          'generatorVersion': 2,
          'journeyLevel': 3,
          'round': {
            'layout': 'intro-v1',
            'seed': initial.seed,
            'level': 3,
            'rotations': initial.tiles.map((tile) => tile.rotation).toList(),
            'moves': 0,
            'recorded': false,
            'assisted': false,
          },
        }),
      });
      final game = _game(preferences);
      await game.load();
      final solution = game.puzzle.solvedCopy();
      final mismatches = solution
          .evaluate()
          .litCells
          .where(
            (index) =>
                game.puzzle.tiles[index].connections !=
                solution.tiles[index].connections,
          )
          .toList();
      expect(game.status.blockedAt, 21);
      expect(game.puzzle.tiles[21].isPath, isFalse);
      expect(mismatches.first, 16);
      expect((mismatches.toList()..sort()).first, 6);
      expect(game.suggestedHintIndex, 16);

      expect(game.hint(), isTrue);
      expect(game.lastChangedTile, 16);
      expect(game.status.blockedAt, 6);
      expect(game.suggestedHintIndex, 6);
    },
  );

  test(
    'requesting a hint reveals a tile without playing or adding history',
    () async {
      final preferences = await _preferences();
      final game = _game(preferences);
      await game.load();
      final puzzle = game.puzzle;
      final initial = _rotations(game);
      final suggestion = game.suggestedHintIndex;
      expect(suggestion, game.puzzle.startRow * game.puzzle.size);
      expect(game.requestHint(), isTrue);
      expect(identical(game.puzzle, puzzle), isTrue);
      expect(_rotations(game), initial);
      expect(game.moves, 0);
      expect(game.history, isEmpty);
      expect(game.assisted, isTrue);
      expect(game.stars, 0);
      expect(game.status.solved, isFalse);
      expect(game.suggestedHintIndex, suggestion);
      await game.flush();

      final resumed = _game(preferences);
      await resumed.load();
      expect(resumed.isPlanetRound, isTrue);
      expect(resumed.assisted, isTrue);
      expect(_rotations(resumed), initial);
      expect(resumed.moves, 0);
      expect(resumed.history, isEmpty);
      expect(resumed.hint(), isTrue);
      expect(resumed.moves, greaterThan(0));
      while (!resumed.status.solved) {
        expect(resumed.hint(), isTrue);
      }
      expect(resumed.status.solved, isTrue);
      expect(resumed.stars, 3);
      expect(resumed.best, 0);
      expect(resumed.suggestedHintIndex, isNull);
      expect(resumed.requestHint(), isFalse);
    },
  );

  test(
    'new Voyage uses strategic four-by-four routes throughout its first planet',
    () async {
      final preferences = await _preferences();
      final game = _game(preferences);
      await game.load();
      for (var level = 1; level <= 15; level++) {
        expect(game.isPlanetRound, isTrue);
        expect(game.isProgressionRound, isTrue);
        expect(game.puzzle.levelNumber, level);
        expect(game.puzzle.size, 4);
        expect(game.puzzle.parMoves, greaterThanOrEqualTo(3));
        final generated = Puzzle.strategicPlanet(
          seed: game.puzzle.seed,
          levelNumber: level,
          difficulty: game.roundDifficulty,
        );
        expect(game.puzzle.solutionRotations, generated.solutionRotations);
        expect(_rotations(game), generated.tiles.map((tile) => tile.rotation));
        _solveNormally(game);
        expect(game.stars, level * 3);
        expect(game.nextPuzzle(), isTrue);
      }
      expect(game.puzzle.levelNumber, 16);
      expect(game.puzzle.size, 4);
      expect(game.isIntroduction, isFalse);
      final generated = Puzzle.strategicPlanet(
        seed: game.puzzle.seed,
        levelNumber: 16,
        difficulty: game.roundDifficulty,
      );
      expect(game.puzzle.solutionRotations, generated.solutionRotations);
      expect(
        _rotations(game),
        generated.tiles.map((tile) => tile.rotation).toList(),
      );
      await game.flush();
      expect(
        (_snapshot(preferences)['round'] as Map<String, dynamic>)['layout'],
        'bounty-v6',
      );
    },
  );

  test('planet-v4 saves keep exact board and verified replay; next round adopts v6', () async {
    const seed = 731 + 97 + 1907;
    final initial = Puzzle.planet(seed: seed, levelNumber: 1);
    final action = initial.startRow * initial.size;
    final parked = initial.rotateAt(action);
    final preferences = await _preferences({
      GameController.storageKey: jsonEncode({
        'schemaVersion': 1,
        'generatorVersion': 2,
        'journeyLevel': 1,
        'round': {
          'layout': 'planet-v4',
          'seed': seed,
          'level': 1,
          'difficulty': 'balanced',
          'rotations': parked.tiles.map((t) => t.rotation).toList(),
          'moves': 1,
          'replayActions': [action],
          'recorded': false,
          'assisted': false,
          'history': [
            {
              'moves': 0,
              'rotations': initial.tiles.map((t) => t.rotation).toList(),
            },
          ],
        },
      }),
    });
    final game = _game(preferences);
    await game.load();
    expect(game.roundLayout, 'planet-v4');
    expect(game.puzzle.size, 3);
    expect(_rotations(game), parked.tiles.map((t) => t.rotation));
    expect(game.hasVerifiedReplay, isTrue);
    expect(game.replayActions, [action]);
    expect(game.undo(), isTrue);
    expect(_rotations(game), initial.tiles.map((t) => t.rotation));
    expect(game.skipCurrentLevel(), isTrue);
    expect(game.roundLayout, 'bounty-v6');
    expect(game.puzzle.size, 4);
    expect(game.puzzle.levelNumber, 2);
    expect(game.stars, 0);
    await game.flush();
    expect((_snapshot(preferences)['round'] as Map)['layout'], 'bounty-v6');
  });

  test(
    'an old marker-free level-one save keeps its exact generated board',
    () async {
      final initial = Puzzle.generate(seed: 2735, levelNumber: 1);
      final changed = initial.tiles.toList();
      changed[0] = changed[0].rotated();
      final saved = initial.copyWithTiles(changed);
      final oldSnapshot = <String, Object?>{
        'schemaVersion': 1,
        'generatorVersion': 2,
        'journeyLevel': 1,
        'stars': 0,
        'best': 0,
        'isDaily': false,
        'difficulty': 'balanced',
        'dailyDate': '2026-11-22',
        'dailyIndex': 0,
        'dailyCompleted': <int>[],
        'round': {
          'seed': initial.seed,
          'level': 1,
          'rotations': saved.tiles.map((tile) => tile.rotation).toList(),
          'moves': 1,
          'assisted': false,
          'recorded': false,
          'history': [
            {
              'moves': 0,
              'rotations': initial.tiles.map((tile) => tile.rotation).toList(),
            },
          ],
        },
      };
      final preferences = await _preferences({
        GameController.storageKey: jsonEncode(oldSnapshot),
      });
      final game = _game(preferences);
      await game.load();
      expect(game.isIntroduction, isFalse);
      expect(
        _rotations(game),
        saved.tiles.map((tile) => tile.rotation).toList(),
      );
      expect(game.puzzle.starIndices, initial.starIndices);
      expect(game.puzzle.solutionRotations, initial.solutionRotations);
      expect(game.puzzle.parMoves, initial.parMoves);
      expect(game.historyLength, 1);
      expect(game.restart(), isTrue);
      expect(
        _rotations(game),
        initial.tiles.map((tile) => tile.rotation).toList(),
      );
      game.setDaily(true);
      await game.flush();

      final resumed = _game(preferences);
      await resumed.load();
      resumed.setDaily(false);
      expect(resumed.isIntroduction, isFalse);
      expect(resumed.puzzle.starIndices, initial.starIndices);
      expect(
        _rotations(resumed),
        initial.tiles.map((tile) => tile.rotation).toList(),
      );
      await resumed.flush();
      expect(
        (_snapshot(preferences)['round'] as Map<String, dynamic>)['layout'],
        'generated-v2',
      );
    },
  );

  test(
    'mode switching and reload preserve both rounds and their own difficulty',
    () async {
      final preferences = await _preferences({'journeyLevel': 4});
      final game = _game(preferences);
      await game.load();
      game.rotate(0);
      game.requestHint();
      game.hint();
      final journeyRotations = _rotations(game);
      final journeyMoves = game.moves;
      final journeySeed = game.puzzle.seed;
      game.setDaily(true);
      game.rotate(1);
      game.hint();
      final dailyRotations = _rotations(game);
      final dailyMoves = game.moves;
      final dailySeed = game.puzzle.seed;
      game.setDifficulty(Difficulty.bright);
      expect(game.puzzle.seed, dailySeed);
      game.setDaily(false);
      expect(game.puzzle.seed, journeySeed);
      expect(_rotations(game), journeyRotations);
      expect(game.moves, journeyMoves);
      expect(game.historyLength, 2);
      expect(game.assisted, isTrue);
      expect(game.difficulty, Difficulty.bright);
      expect(game.roundDifficulty, Difficulty.balanced);
      game.undo();
      expect(game.moves, 1);
      await game.flush();

      final resumed = _game(preferences);
      await resumed.load();
      expect(resumed.moves, 1);
      expect(resumed.roundDifficulty, Difficulty.balanced);
      expect(resumed.difficulty, Difficulty.bright);
      resumed.setDaily(true);
      expect(resumed.puzzle.seed, dailySeed);
      expect(_rotations(resumed), dailyRotations);
      expect(resumed.moves, dailyMoves);
      expect(resumed.assisted, isTrue);
      expect(resumed.historyLength, 2);
      expect(resumed.undo(), isTrue);
      expect(resumed.moves, 1);
    },
  );

  test(
    'a parked Daily keeps its date while Journey advances across midnight',
    () async {
      final preferences = await _preferences();
      var now = DateTime.utc(2026, 11, 22, 23, 59);
      final game = _game(preferences, now: () => now);
      await game.load();
      game.setDaily(true);
      game.hint();
      final dailySeed = game.puzzle.seed;
      final dailyRotations = _rotations(game);
      final dailyMoves = game.moves;
      game.setDaily(false);
      now = now.add(const Duration(minutes: 2));
      _solveNormally(game);
      game.nextPuzzle();
      expect(game.puzzle.levelNumber, 2);
      await game.flush();

      final resumed = _game(preferences, now: () => now);
      await resumed.load();
      resumed.setDaily(true);
      expect(resumed.dailyDate, '2026-11-22');
      expect(resumed.puzzle.seed, dailySeed);
      expect(_rotations(resumed), dailyRotations);
      expect(resumed.moves, dailyMoves);
      _solveWithHints(resumed);
      expect(resumed.stars, 6);
      resumed.nextPuzzle();
      expect(resumed.dailyDate, '2026-11-23');
      expect(resumed.puzzle.seed, dailySeed + 100);
      expect(resumed.dailyIndex, 0);
      expect(resumed.dailyCompleted, isEmpty);
    },
  );

  test(
    'a ready listener can load and flush without re-entering initialization',
    () async {
      final preferences = await _preferences();
      var writes = 0;
      final game = _game(
        preferences,
        snapshotWriter: (snapshot) {
          writes++;
          return preferences.setString(GameController.storageKey, snapshot);
        },
      );
      var readyNotifications = 0;
      var requestedFromListener = false;
      Future<void>? listenerLoad;
      Future<void>? listenerFlush;
      game.addListener(() {
        if (!game.ready) return;
        readyNotifications++;
        // Bound the regression even if initialization becomes reentrant again.
        if (requestedFromListener) return;
        requestedFromListener = true;
        listenerLoad = game.load();
        listenerFlush = game.flush();
      });

      final initialLoad = game.load();
      await initialLoad;
      expect(listenerLoad, isNotNull);
      expect(identical(listenerLoad, initialLoad), isTrue);
      expect(listenerFlush, isNotNull);
      await listenerFlush!;
      expect(readyNotifications, 1);
      expect(writes, 1);
      expect(game.ready, isTrue);
      expect(game.saveError, isFalse);
      expect(_snapshot(preferences)['journeyLevel'], 1);
    },
  );

  test(
    'legacy progress migrates into one snapshot with existing defaults',
    () async {
      final preferences = await _preferences({
        'journeyLevel': 8,
        'stars': 18,
        'best': 190,
        'dailyDate': '2026-11-22',
        'dailyCompleted': <String>['0', '2', 'bad', '-1', '8'],
      });
      final game = _game(preferences);
      expect(game.ready, isFalse);
      expect(game.rotate(0), isFalse);
      await game.load();
      await game.flush();

      expect(game.ready, isTrue);
      expect(game.journeyLevel, 8);
      expect(game.puzzle.levelNumber, 8);
      expect(game.stars, 18);
      expect(game.best, 190);
      expect(game.difficulty, Difficulty.balanced);
      expect(game.dailyCompleted, {0, 2});
      expect(game.reduceMotion, isFalse);
      expect(game.highContrast, isFalse);
      expect(game.haptics, isTrue);
      final snapshot = _snapshot(preferences);
      expect(snapshot['schemaVersion'], 1);
      expect(snapshot['generatorVersion'], puzzleGeneratorVersion);
      expect(snapshot['journeyLevel'], 8);
      expect(game.setDaily(true), isTrue);
      expect(game.dailyIndex, 1);
      expect(game.puzzle.levelNumber, 91);
    },
  );

  test(
    'unfinished rotations, moves, assistance, history and settings resume',
    () async {
      final preferences = await _preferences({'journeyLevel': 4});
      final game = _game(preferences);
      await game.load();
      game.setDifficulty(Difficulty.bright);
      final initial = _rotations(game);
      game.rotate(0);
      final afterTap = _rotations(game);
      game.hint();
      expect(game.lastChangedTile, isNotNull);
      game.setReduceMotion(true);
      game.setHighContrast(true);
      game.setHaptics(false);
      final savedMoves = game.moves;
      final savedRotations = _rotations(game);
      await game.flush();

      final resumed = _game(preferences);
      await resumed.load();
      expect(resumed.difficulty, Difficulty.bright);
      expect(resumed.puzzle.seed, game.puzzle.seed);
      expect(_rotations(resumed), savedRotations);
      expect(resumed.moves, savedMoves);
      expect(resumed.assisted, isTrue);
      expect(resumed.historyLength, 2);
      expect(resumed.reduceMotion, isTrue);
      expect(resumed.highContrast, isTrue);
      expect(resumed.haptics, isFalse);
      expect(resumed.undo(), isTrue);
      expect(_rotations(resumed), afterTap);
      expect(resumed.moves, 1);
      expect(resumed.assisted, isTrue);
      expect(resumed.undo(), isTrue);
      expect(_rotations(resumed), initial);
      expect(resumed.moves, 0);
      expect(resumed.assisted, isTrue);
      expect(resumed.canUndo, isFalse);
      expect(resumed.canRestart, isTrue);
      expect(resumed.restart(), isTrue);
      expect(resumed.assisted, isFalse);
      expect(resumed.rotate(-1), isFalse);
      expect(resumed.rotate(25), isFalse);
      expect(() => resumed.history.clear(), throwsUnsupportedError);
      expect(() => resumed.dailyCompleted.clear(), throwsUnsupportedError);
    },
  );

  test(
    'undoing a hint stays assisted and a restored solve is rewarded once',
    () async {
      final preferences = await _preferences({'best': 175, 'journeyLevel': 2});
      final game = _game(preferences);
      await game.load();
      expect(game.hint(), isTrue);
      expect(game.undo(), isTrue);
      expect(game.assisted, isTrue);
      _solveNormally(game);
      expect(game.status.solved, isTrue);
      expect(game.stars, 3);
      expect(game.best, 175);
      expect(game.journeyLevel, 3);
      expect(game.canUndo, isFalse);
      expect(game.restart(), isFalse);
      await game.flush();

      final resumed = _game(preferences);
      await resumed.load();
      expect(resumed.status.solved, isTrue);
      expect(resumed.puzzle.levelNumber, 2);
      expect(resumed.journeyLevel, 3);
      expect(resumed.stars, 3);
      expect(resumed.rotate(0), isFalse);
      expect(resumed.hint(), isFalse);
      expect(resumed.undo(), isFalse);
      expect(resumed.stars, 3);
      expect(resumed.nextPuzzle(), isTrue);
      expect(resumed.puzzle.levelNumber, 3);
      expect(resumed.status.solved, isFalse);
      expect(resumed.moves, 0);
      expect(resumed.assisted, isFalse);
    },
  );

  test('an unassisted reference solve updates the best score', () async {
    final preferences = await _preferences();
    final game = _game(preferences);
    await game.load();
    expect(game.nextPuzzle(), isFalse);
    _solveNormally(game);
    expect(game.status.solved, isTrue);
    expect(game.assisted, isFalse);
    expect(game.best, 200);
    expect(game.stars, 3);
    await game.flush();
    expect(_snapshot(preferences)['best'], 200);
  });

  test(
    'daily replays and app reloads cannot award the same stars again',
    () async {
      final preferences = await _preferences();
      final game = _game(preferences);
      await game.load();
      game.setDaily(true);
      for (var daily = 0; daily < 3; daily++) {
        expect(game.dailyIndex, daily);
        _solveWithHints(game);
        expect(game.stars, (daily + 1) * 3);
        game.nextPuzzle();
      }
      expect(game.dailyIndex, 0);
      expect(game.dailyCompleted, {0, 1, 2});
      _solveWithHints(game);
      expect(game.stars, 9);
      expect(game.journeyLevel, 1);
      await game.flush();

      final resumed = _game(preferences);
      await resumed.load();
      expect(resumed.isDaily, isTrue);
      expect(resumed.status.solved, isTrue);
      expect(resumed.stars, 9);
      resumed.nextPuzzle();
      _solveWithHints(resumed);
      expect(resumed.stars, 9);
      expect(resumed.dailyCompleted, {0, 1, 2});
    },
  );

  test(
    'a resumed daily round keeps its UTC date through midnight until next',
    () async {
      final preferences = await _preferences();
      var now = DateTime.parse('2026-11-23T01:59:30+02:00');
      final game = _game(preferences, now: () => now);
      await game.load();
      game.setDaily(true);
      game.rotate(0);
      game.hint();
      final seed = game.puzzle.seed;
      final rotations = _rotations(game);
      final moves = game.moves;
      await game.flush();
      now = now.add(const Duration(minutes: 2));

      final resumed = _game(preferences, now: () => now);
      await resumed.load();
      expect(resumed.dailyDate, '2026-11-22');
      expect(resumed.puzzle.seed, seed);
      expect(_rotations(resumed), rotations);
      expect(resumed.moves, moves);
      expect(resumed.assisted, isTrue);
      resumed.restart();
      expect(resumed.dailyDate, '2026-11-22');
      expect(resumed.puzzle.seed, seed);
      expect(resumed.moves, 0);
      _solveWithHints(resumed);
      expect(resumed.dailyCompleted, {0});
      expect(resumed.stars, 3);
      resumed.nextPuzzle();
      expect(resumed.dailyDate, '2026-11-23');
      expect(resumed.dailyIndex, 0);
      expect(resumed.dailyCompleted, isEmpty);
      expect(resumed.puzzle.seed, seed + 100);
      expect(resumed.stars, 3);
    },
  );

  test(
    'bad JSON falls back to legacy progress and invalid rounds keep counters',
    () async {
      final preferences = await _preferences({
        GameController.storageKey: '{broken json',
        'journeyLevel': 7,
        'stars': 12,
        'dailyDate': '2026-11-21',
        'dailyCompleted': <String>['0', '1', '2'],
      });
      final game = _game(preferences);
      await game.load();
      await game.flush();
      expect(game.ready, isTrue);
      expect(game.journeyLevel, 7);
      expect(game.stars, 12);
      expect(game.dailyCompleted, isEmpty);
      expect(game.saveError, isFalse);

      final corrupted = _snapshot(preferences);
      corrupted['journeyLevel'] = 4;
      corrupted['stars'] = 21;
      (corrupted['round'] as Map<String, dynamic>)['rotations'] = ['invalid'];
      await preferences.setString(
        GameController.storageKey,
        jsonEncode(corrupted),
      );
      final recovered = _game(preferences);
      await recovered.load();
      expect(recovered.journeyLevel, 4);
      expect(recovered.puzzle.levelNumber, 4);
      expect(recovered.stars, 21);
      expect(recovered.moves, 0);
      expect(recovered.status.solved, isFalse);
    },
  );

  test(
    'generator changes discard only the saved round, retaining progress',
    () async {
      final preferences = await _preferences({'journeyLevel': 9, 'stars': 24});
      final game = _game(preferences);
      await game.load();
      game.rotate(0);
      game.setReduceMotion(true);
      await game.flush();
      final outdated = _snapshot(preferences);
      outdated['generatorVersion'] = puzzleGeneratorVersion - 1;
      await preferences.setString(
        GameController.storageKey,
        jsonEncode(outdated),
      );
      final recovered = _game(preferences);
      await recovered.load();
      expect(recovered.journeyLevel, 9);
      expect(recovered.stars, 24);
      expect(recovered.reduceMotion, isTrue);
      expect(recovered.moves, 0);
      expect(recovered.history, isEmpty);
    },
  );

  test(
    'serialized writes cannot let an older snapshot replace a newer one',
    () async {
      // Use an established route while serializing several independent edits.
      final preferences = await _preferences({'journeyLevel': 8});
      var activeWrites = 0;
      var maximumActiveWrites = 0;
      final writtenMoves = <int>[];
      final game = _game(
        preferences,
        snapshotWriter: (snapshot) async {
          activeWrites++;
          if (activeWrites > maximumActiveWrites) {
            maximumActiveWrites = activeWrites;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
          final decoded = jsonDecode(snapshot) as Map<String, dynamic>;
          writtenMoves.add(
            (decoded['round'] as Map<String, dynamic>)['moves'] as int,
          );
          final saved = await preferences.setString(
            GameController.storageKey,
            snapshot,
          );
          activeWrites--;
          return saved;
        },
      );
      await game.load();
      expect(game.rotate(0), isTrue);
      expect(game.rotate(1), isTrue);
      expect(game.rotate(2), isTrue);
      game.setHighContrast(true);
      await game.flush();
      expect(maximumActiveWrites, 1);
      expect(writtenMoves, [0, 1, 2, 3, 3]);
      final snapshot = _snapshot(preferences);
      expect((snapshot['round'] as Map<String, dynamic>)['moves'], 3);
      expect(
        (snapshot['settings'] as Map<String, dynamic>)['highContrast'],
        isTrue,
      );
      expect(game.saveError, isFalse);
    },
  );

  test(
    'throwing and false save results keep play usable and flush can recover',
    () async {
      final preferences = await _preferences();
      var failure = 'throw';
      final game = _game(
        preferences,
        snapshotWriter: (snapshot) async {
          if (failure == 'throw') throw StateError('Storage unavailable');
          if (failure == 'false') return false;
          return preferences.setString(GameController.storageKey, snapshot);
        },
      );
      await game.load();
      await game.flush();
      expect(game.ready, isTrue);
      expect(game.saveError, isTrue);
      expect(game.rotate(0), isTrue);
      failure = 'false';
      await game.flush();
      expect(game.saveError, isTrue);
      failure = '';
      await game.flush();
      expect(game.saveError, isFalse);
      expect(
        (_snapshot(preferences)['round'] as Map<String, dynamic>)['moves'],
        1,
      );
    },
  );
}

Future<SharedPreferences> _preferences([
  Map<String, Object> values = const {},
]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

GameController _game(
  SharedPreferences preferences, {
  DateTime Function()? now,
  Future<bool> Function(String snapshot)? snapshotWriter,
}) {
  final game = GameController(
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

Map<String, dynamic> _snapshot(SharedPreferences preferences) =>
    jsonDecode(preferences.getString(GameController.storageKey)!)
        as Map<String, dynamic>;

List<int> _rotations(GameController game) =>
    game.puzzle.tiles.map((tile) => tile.rotation).toList();

void _solveWithHints(GameController game) {
  for (var count = 0; count < 25 && !game.status.solved; count++) {
    expect(game.hint(), isTrue);
  }
  expect(game.status.solved, isTrue);
}

void _solveNormally(GameController game) {
  final target = game.puzzle.solvedCopy();
  for (
    var index = 0;
    index < target.tiles.length && !game.status.solved;
    index++
  ) {
    if (!target.tiles[index].isPath) continue;
    for (
      var turns = 0;
      turns < 4 &&
          !game.status.solved &&
          !game.puzzle.tiles[index].orientationMatches(target.tiles[index]);
      turns++
    ) {
      expect(game.rotate(index), isTrue);
    }
  }
  expect(game.status.solved, isTrue);
}
