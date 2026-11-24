import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/game/voyage_progression.dart';
import 'package:glowpath/services/flight_league.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('live result payload keeps the exact parked round layout', () async {
    final sent = <Map<String, dynamic>>[];
    final league = FlightLeague(
      endpoint: 'https://league.example',
      mock: false,
      client: MockClient((request) async {
        if (request.url.path == '/v1/pilots') {
          return http.Response(
            jsonEncode({
              'token': List.filled(64, 'a').join(),
              'name': 'Test pilot',
            }),
            200,
          );
        }
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{}', 200);
      }),
    );
    addTearDown(league.dispose);
    await league.join();
    for (final layout in ['planet-v4', 'planet-v5']) {
      await league.submit(
        mode: 'daily',
        period: '2026-11-22',
        index: 0,
        actions: [3, 4],
        layout: layout,
      );
    }
    expect(sent.map((body) => body['layout']), ['planet-v4', 'planet-v5']);
    expect(sent.every((body) => body['assisted'] == false), isTrue);
    expect(sent.first['actions'], [3, 4]);
  });

  for (final layout in ['planet-v4', 'planet-v5']) {
    test('$layout drag replay enters the matching preview challenge', () async {
      final date = DateTime.utc(2026, 11, 22);
      final day = date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
      final puzzle = layout == 'planet-v5'
          ? Puzzle.strategicPlanet(
              seed: day * 100,
              levelNumber: VoyageProgression.dailyLevel(0),
            )
          : Puzzle.planet(
              seed: day * 100,
              levelNumber: PlanetV4Progression.dailyLevel(0),
            );
      final trace = puzzle.planTrace(puzzle.solvedCopy().evaluate().route);
      expect(trace.accepted, isTrue);
      final league = FlightLeague(mock: true, now: () => date);
      addTearDown(league.dispose);
      await league.join();
      await league.submit(
        mode: 'daily',
        period: '2026-11-22',
        index: 0,
        actions: trace.actions,
        layout: layout,
      );
      final table = await league.standings('daily');
      final mine = (table['entries'] as List).singleWhere(
        (row) => row['id'] == table['pilotId'],
      );
      expect(mine['routes'], 1);
      expect(mine['moves'], trace.actions.length);
      expect(mine['score'], trace.puzzle.scoreForMoves(trace.actions.length));
    });
  }
}
