import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/game/voyage_progression.dart';
import 'package:glowpath/services/flight_league.dart';
import 'package:glowpath/services/flight_support.dart';
import 'package:glowpath/services/mock_flight_league.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 22, 12);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'mock rewards remain available without purchase offers or store access',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var storeReads = 0;
      final support = FlightSupport(
        mock: true,
        ads: true,
        entitlementReader: () async {
          storeReads++;
          throw StateError('Must not contact store');
        },
      );
      await support.initialize();
      expect(support.isMock, isTrue);
      expect(support.reviewMode, isFalse);
      expect(support.canBuy, isFalse);
      expect(support.price, 'Preview');
      expect(await support.earnReward(skip: false), isTrue);
      expect(support.hintCredits, 6);
      expect(support.message, contains('No ad was shown'));
      expect(await support.earnReward(skip: true), isTrue);
      expect(support.skipCredits, 2);
      await support.buy();
      expect(support.adFree, isFalse);
      expect(support.canBuy, isFalse);
      await support.restore();
      expect(support.message, contains('Purchases are disabled'));
      await support.refreshEntitlements();
      await support.privacyOptions();
      expect(storeReads, 0);
      expect(support.consumeSkip(), isTrue);
      expect(support.skipCredits, 1);
      support.dispose();
    },
  );

  test('mock credits persist without adding paid entitlements or entering production storage', () async {
    final original = jsonEncode({'version': 1, 'hints': 1, 'skips': 0});
    SharedPreferences.setMockInitialValues({
      FlightSupport.creditStorageKey: original,
    });
    var preview = FlightSupport(mock: true);
    await preview.initialize();
    preview.consumeHint();
    await preview.earnReward(skip: true);
    await preview.buy();
    await preview.flushCredits();
    preview.dispose();
    preview = FlightSupport(mock: true);
    await preview.initialize();
    expect(preview.hintCredits, 2);
    expect(preview.skipCredits, 2);
    expect(preview.adFree, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(FlightSupport.creditStorageKey), original);
    preview.dispose();
    final live = FlightSupport(mock: false, ads: true, purchases: false);
    await live.initialize();
    expect(live.hintCredits, 1);
    expect(live.skipCredits, 0);
    expect(live.adFree, isFalse);
    await live.flushCredits();
    live.dispose();
  });

  List<int> dailySolution() {
    final day =
        DateTime.utc(2026, 11, 22).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    var puzzle = Puzzle.planet(
      seed: day * 100,
      levelNumber: VoyageProgression.dailyLevel(0),
    );
    final actions = <int>[];
    for (final action in puzzle.solutionActions) {
      if (puzzle.evaluate().solved) break;
      actions.add(action);
      puzzle = puzzle.rotateAt(action);
    }
    return actions;
  }

  test('mock league joins and persists a real replay score against explicitly fictional pilots', () async {
    var requests = 0;
    FlightLeague league() => FlightLeague(
      mock: true,
      endpoint: 'https://must-not-contact.example',
      now: () => now,
      client: MockClient((_) async {
        requests++;
        throw http.ClientException('No remote access');
      }),
    );
    var preview = league();
    expect(preview.isMock, isTrue);
    expect(preview.configured, isTrue);
    await preview.join();
    var board = await preview.standings('daily');
    final entries = board['entries'] as List;
    expect(entries, hasLength(5));
    expect(
      entries.where((r) => (r['name'] as String).contains('demo')),
      hasLength(4),
    );
    expect(board['demo'], isTrue);
    final actions = dailySolution();
    for (var i = 0; i < 2; i++) {
      await preview.submit(
        mode: 'daily',
        period: '2026-11-22',
        index: 0,
        actions: actions,
      );
    }
    preview.dispose();
    preview = league();
    await preview.load();
    expect(preview.joined, isTrue);
    board = await preview.standings('daily');
    final mine = (board['entries'] as List).singleWhere(
      (r) => r['id'] == board['pilotId'],
    );
    expect(mine['routes'], 1);
    expect(mine['score'], 200);
    expect(mine['moves'], actions.length);
    expect(requests, 0);
    preview.dispose();
  });

  test(
    'mock league rejects incomplete actions instead of inventing player points',
    () async {
      final preview = FlightLeague(mock: true, now: () => now);
      await preview.join();
      await expectLater(
        preview.submit(
          mode: 'daily',
          period: '2026-11-22',
          index: 0,
          actions: [],
        ),
        throwsA(isA<MockLeagueException>()),
      );
      await expectLater(
        preview.submit(
          mode: 'daily',
          period: '2026-11-22',
          index: 0,
          actions: [99],
        ),
        throwsA(isA<MockLeagueException>()),
      );
      final board = await preview.standings('daily');
      final mine = (board['entries'] as List).singleWhere(
        (r) => r['id'] == board['pilotId'],
      );
      expect(mine['score'], 0);
      expect(mine['routes'], 0);
      preview.dispose();
    },
  );

  test(
    'leaving mock league deletes only preview identity and results',
    () async {
      const realToken =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      SharedPreferences.setMockInitialValues({
        'glowpath.league.token': realToken,
        'glowpath.league.name': 'Real pilot',
      });
      final preview = FlightLeague(mock: true, now: () => now);
      await preview.join();
      await preview.submit(
        mode: 'daily',
        period: '2026-11-22',
        index: 0,
        actions: dailySolution(),
      );
      await preview.leave();
      expect(preview.joined, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MockFlightLeague.storageKey), isNull);
      expect(prefs.getString('glowpath.league.token'), realToken);
      expect(prefs.getString('glowpath.league.name'), 'Real pilot');
      preview.dispose();
      final reloaded = FlightLeague(mock: true, now: () => now);
      await reloaded.load();
      expect(reloaded.joined, isFalse);
      reloaded.dispose();
    },
  );
}
