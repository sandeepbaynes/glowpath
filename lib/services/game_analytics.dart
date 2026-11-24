import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Bounded, on-device event journal for launch tuning. Nothing is uploaded.
/// Keys and values are allowlisted so puzzle paths and personal identifiers
/// cannot accidentally enter the journal.
class GameAnalytics {
  GameAnalytics({SharedPreferences? preferences}) : this._(preferences);

  GameAnalytics._(this._preferences);

  static const storageKey = 'glowpath.analytics.local.v1';
  static const maxEvents = 200;
  static const allowedNames = <String>{
    'session_start',
    'level_start',
    'level_complete',
    'level_fail',
    'level_retry',
    'level_skip',
    'hint_used',
    'ad_eligible',
    'ad_impression',
    'ad_closed',
    'ad_reward',
    'ad_no_fill',
  };
  static const allowedFields = <String>{
    'mode',
    'level',
    'assisted',
    'timeBucket',
    'placement',
    'outcome',
  };

  SharedPreferences? _preferences;
  Future<void> _queue = Future<void>.value();

  Future<void> record(String name, Map<String, Object?> fields) {
    if (!allowedNames.contains(name)) {
      throw ArgumentError.value(name, 'name', 'Unknown analytics event');
    }
    if (fields.keys.any((key) => !allowedFields.contains(key))) {
      throw ArgumentError.value(fields.keys, 'fields', 'Unknown analytics field');
    }
    final safe = <String, Object?>{};
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value is bool || value is int ||
          (value is String && value.length <= 40 &&
              RegExp(r'^[a-zA-Z0-9_-]*$').hasMatch(value))) {
        safe[entry.key] = value;
      } else {
        throw ArgumentError.value(value, entry.key, 'Unsupported analytics value');
      }
    }
    _queue = _queue.then((_) async {
      final preferences = _preferences ??= await SharedPreferences.getInstance();
      final current = preferences.getStringList(storageKey) ?? <String>[];
      current.add(jsonEncode({
        'v': 1,
        'name': name,
        'time': DateTime.now().toUtc().toIso8601String(),
        'fields': safe,
      }));
      if (current.length > maxEvents) {
        current.removeRange(0, current.length - maxEvents);
      }
      await preferences.setStringList(storageKey, current);
    });
    return _queue;
  }

  Future<List<Map<String, dynamic>>> readLocal() async {
    await _queue;
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    return (preferences.getStringList(storageKey) ?? const <String>[])
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList(growable: false);
  }

  Future<void> clear() async {
    await _queue;
    final preferences = _preferences ??= await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
  }
}
