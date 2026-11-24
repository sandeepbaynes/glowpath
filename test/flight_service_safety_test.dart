import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glowpath/services/flight_league.dart';
import 'package:glowpath/services/flight_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'review defaults never initialize ads or purchases and stay free',
    () async {
      final support = FlightSupport();
      await support.initialize();
      expect(FlightSupport.adsEnabled, isFalse);
      expect(FlightSupport.purchasesEnabled, isFalse);
      expect(support.reviewMode, isTrue);
      expect(support.adFree, isFalse);
      expect(support.canBuy, isFalse);
      for (var i = 0; i < 20; i++) {
        expect(support.consumeHint(), isTrue);
        expect(support.consumeSkip(), isTrue);
      }
      expect(await support.earnReward(skip: false), isFalse);
      expect(support.hintCredits, 3);
      expect(support.skipCredits, 1);
      await support.flushCredits();
      support.dispose();
    },
  );

  test('live credits are atomic and do not replenish after restart', () async {
    final prefs = await SharedPreferences.getInstance();
    var support = FlightSupport(
      ads: true,
      purchases: false,
      preferences: prefs,
    );
    // A tap before loading cannot consume a stale/default balance.
    expect(support.consumeHint(), isFalse);
    await support.initialize();
    expect(support.consumeHint(), isTrue);
    expect(support.consumeHint(), isTrue);
    expect(support.consumeSkip(), isTrue);
    expect(support.consumeSkip(), isFalse);
    await support.flushCredits();
    expect(jsonDecode(prefs.getString(FlightSupport.creditStorageKey)!), {
      'version': 1,
      'hints': 1,
      'skips': 0,
    });
    support.dispose();
    support = FlightSupport(ads: true, purchases: false, preferences: prefs);
    await support.initialize();
    expect(support.hintCredits, 1);
    expect(support.skipCredits, 0);
    expect(support.consumeSkip(), isFalse);
    await support.flushCredits();
    support.dispose();
  });

  test('previously earned credits survive load and consumption', () async {
    SharedPreferences.setMockInitialValues({
      FlightSupport.creditStorageKey: jsonEncode({
        'version': 1,
        'hints': 12,
        'skips': 4,
      }),
    });
    final support = FlightSupport(ads: true, purchases: false);
    await support.initialize();
    expect(support.hintCredits, 12);
    expect(support.skipCredits, 4);
    support.consumeHint();
    support.consumeSkip();
    await support.flushCredits();
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(FlightSupport.creditStorageKey)!), {
      'version': 1,
      'hints': 11,
      'skips': 3,
    });
    support.dispose();
  });

  test(
    'unreadable credits fail closed without replacing the saved balance',
    () async {
      SharedPreferences.setMockInitialValues({
        FlightSupport.creditStorageKey: 'damaged',
      });
      final support = FlightSupport(ads: true, purchases: false);
      await support.initialize();
      expect(support.consumeHint(), isFalse);
      expect(support.consumeSkip(), isFalse);
      expect(support.message, contains('could not load'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(FlightSupport.creditStorageKey), 'damaged');
      support.dispose();
    },
  );

  test('invalid structured balances cannot reset lifetime freebies', () async {
    for (final value in [
      {'version': 2, 'hints': 0, 'skips': 0},
      {'version': 1, 'hints': -1, 'skips': 0},
      {'version': 1, 'hints': '3', 'skips': 1},
    ]) {
      final raw = jsonEncode(value);
      SharedPreferences.setMockInitialValues({
        FlightSupport.creditStorageKey: raw,
      });
      final support = FlightSupport(ads: true, purchases: false);
      await support.initialize();
      expect(support.consumeHint(), isFalse);
      expect(support.consumeSkip(), isFalse);
      await support.flushCredits();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(FlightSupport.creditStorageKey), raw);
      support.dispose();
    }
  });

  test(
    'current verified entitlement controls access including revocation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var active = true;
      var unavailable = false;
      final support = FlightSupport(
        purchases: true,
        entitlementReader: () async {
          if (unavailable) throw StateError('Store unavailable');
          return active;
        },
      );
      expect(await support.refreshEntitlements(), isTrue);
      expect(support.adFree, isTrue);
      unavailable = true;
      expect(await support.refreshEntitlements(), isFalse);
      expect(support.adFree, isTrue);
      unavailable = false;
      active = false;
      expect(await support.refreshEntitlements(), isTrue);
      expect(support.adFree, isFalse);
      support.dispose();
    },
  );

  test('stale entitlement reads cannot overwrite a newer revocation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final first = Completer<bool>(), second = Completer<bool>();
    var calls = 0;
    final support = FlightSupport(
      purchases: true,
      entitlementReader: () {
        return calls++ == 0 ? first.future : second.future;
      },
    );
    final older = support.refreshEntitlements();
    final newer = support.refreshEntitlements();
    second.complete(false);
    expect(await newer, isTrue);
    first.complete(true);
    expect(await older, isFalse);
    expect(support.adFree, isFalse);
    support.dispose();
  });

  const token =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  void savedPilot() => SharedPreferences.setMockInitialValues({
    'glowpath.league.token': token,
    'glowpath.league.name': 'Pilot AAAAAA',
  });

  test('unconfigured league stays honest and performs no request', () async {
    var requests = 0;
    final league = FlightLeague(
      endpoint: '',
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    expect(league.configured, isFalse);
    await expectLater(
      league.standings('daily'),
      throwsA(isA<LeagueException>()),
    );
    expect(requests, 0);
    league.dispose();
  });

  test(
    '401 clears only the local stale session and allows rejoining',
    () async {
      savedPilot();
      final league = FlightLeague(
        endpoint: 'https://league.example',
        client: MockClient((request) async {
          if (request.url.path == '/v1/pilots') {
            return http.Response(
              jsonEncode({'token': token, 'name': 'Pilot BBBBBB'}),
              201,
            );
          }
          return http.Response('{"error":"expired"}', 401);
        }),
      );
      await league.load();
      expect(league.joined, isTrue);
      await expectLater(
        league.standings('daily'),
        throwsA(isA<LeagueException>()),
      );
      expect(league.joined, isFalse);
      expect(league.callsign, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('glowpath.league.token'), isNull);
      await league.join();
      expect(league.joined, isTrue);
      expect(league.callsign, 'Pilot BBBBBB');
      league.dispose();
    },
  );

  test(
    'a late 401 from an old pilot cannot clear a newly joined pilot',
    () async {
      savedPilot();
      final oldResponse = Completer<http.Response>();
      const newToken =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final league = FlightLeague(
        endpoint: 'https://league.example',
        client: MockClient((request) async {
          if (request.url.path == '/v1/pilots') {
            return http.Response(
              jsonEncode({'token': newToken, 'name': 'Pilot BBBBBB'}),
              201,
            );
          }
          return oldResponse.future;
        }),
      );
      await league.load();
      final oldRequest = league.standings('daily');
      await league.join();
      oldResponse.complete(http.Response('{}', 401));
      await expectLater(oldRequest, throwsA(isA<LeagueException>()));
      expect(league.joined, isTrue);
      expect(league.callsign, 'Pilot BBBBBB');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('glowpath.league.token'), newToken);
      league.dispose();
    },
  );

  test('a network error never discards a valid saved pilot', () async {
    savedPilot();
    final league = FlightLeague(
      endpoint: 'https://league.example',
      client: MockClient((_) async {
        throw http.ClientException('Offline');
      }),
    );
    await league.load();
    await expectLater(
      league.standings('daily'),
      throwsA(isA<LeagueException>()),
    );
    expect(league.joined, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('glowpath.league.token'), token);
    league.dispose();
  });

  test('timeout includes a response body that never finishes', () async {
    savedPilot();
    final stalled = StreamController<List<int>>();
    final league = FlightLeague(
      endpoint: 'https://league.example',
      requestTimeout: const Duration(milliseconds: 25),
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(stalled.stream, 200),
      ),
    );
    await league.load();
    await expectLater(
      league.standings('daily'),
      throwsA(isA<LeagueException>()),
    );
    expect(league.joined, isTrue);
    await stalled.close();
    league.dispose();
  });
}
