import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_flight_league.dart';

class FlightLeague {
  FlightLeague({
    String? endpoint,
    http.Client? client,
    bool? mock,
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 12),
  }) : endpoint = endpoint ?? const String.fromEnvironment('LEADERBOARD_URL'),
       _client = client ?? http.Client(),
       isMock = mock ?? const bool.fromEnvironment('MOCK_SERVICES'),
       _mock = MockFlightLeague(now: now);
  final String endpoint;
  final bool isMock;
  final MockFlightLeague _mock;
  final Duration requestTimeout;
  final http.Client _client;
  static const _tokenKey = 'glowpath.league.token';
  String? _token;
  String? _callsign;
  String? get callsign => isMock ? _mock.callsign : _callsign;
  bool get configured => isMock || endpoint.isNotEmpty;
  bool get joined => isMock ? _mock.joined : _token != null;
  Future<void> load() async {
    if (isMock) return _mock.load();
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _callsign = prefs.getString('glowpath.league.name');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (isMock) {
      throw const LeagueException('Demo mode does not contact a server.');
    }
    if (!configured) {
      throw const LeagueException('The flight league opens soon.');
    }
    final uri = Uri.parse('$endpoint$path');
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
            ['localhost', '127.0.0.1'].contains(uri.host))) {
      throw const LeagueException(
        'The flight league connection is unavailable.',
      );
    }
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json';
    final requestToken = _token;
    if (requestToken != null) {
      request.headers['Authorization'] = 'Bearer $requestToken';
    }
    if (body != null) request.body = jsonEncode(body);
    try {
      // Bound the complete response, including a server that sends headers
      // promptly but stalls before completing its body.
      final response = await (() async {
        return http.Response.fromStream(await _client.send(request));
      })().timeout(requestTimeout);
      if (response.statusCode == 401) {
        // A delayed response from a previous identity must not log out a
        // newly joined pilot.
        if (_token == requestToken) await _clearLocalSession();
        throw const LeagueException(
          'Pilot session expired. Join the league again.',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw LeagueException(
          data['error'] as String? ?? 'Could not contact the league.',
        );
      }
      return data;
    } on LeagueException {
      rethrow;
    } catch (_) {
      throw const LeagueException(
        'Could not reach Mission Control. Try again shortly.',
      );
    }
  }

  Future<void> join() async {
    if (isMock) return _mock.join();
    final result = await _request('POST', '/v1/pilots');
    final token = result['token'];
    final name = result['name'];
    if (token is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(token) ||
        name is! String ||
        name.isEmpty ||
        name.length > 64) {
      throw const LeagueException(
        'Mission Control could not create a pilot. Please try again.',
      );
    }
    _token = token;
    _callsign = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString('glowpath.league.name', callsign!);
  }

  Future<Map<String, dynamic>> standings(String mode) =>
      isMock ? _mock.standings(mode) : _request('GET', '/v1/leaderboard/$mode');
  Future<void> submit({
    required String mode,
    required String period,
    required int index,
    required List<int> actions,
    String layout = 'planet-v4',
  }) async {
    if (isMock) {
      return _mock.submit(
        mode: mode,
        period: period,
        index: index,
        actions: actions,
        layout: layout,
      );
    }
    if (!joined || !configured) return;
    await _request('POST', '/v1/results', {
      'mode': mode,
      'period': period,
      'index': index,
      'actions': actions,
      'layout': layout,
      'assisted': false,
    });
  }

  Future<void> leave() async {
    if (isMock) return _mock.leave();
    await _request('DELETE', '/v1/pilots/me');
    await _clearLocalSession();
  }

  Future<void> _clearLocalSession() async {
    _token = null;
    _callsign = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('glowpath.league.name');
  }

  void dispose() => _client.close();
}

class LeagueException implements Exception {
  const LeagueException(this.message);
  final String message;
  @override
  String toString() => message;
}
