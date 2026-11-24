import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glowpath/services/game_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('journal records coarse events locally and stays bounded', () async {
    SharedPreferences.setMockInitialValues({});
    final analytics = GameAnalytics();
    for (var level = 0; level < GameAnalytics.maxEvents + 5; level++) {
      await analytics.record('level_complete', {
        'mode': 'voyage',
        'level': level,
        'assisted': false,
      });
    }
    final events = await analytics.readLocal();
    expect(events.length, GameAnalytics.maxEvents);
    expect(events.first['fields']['level'], 5);
    await analytics.clear();
    expect(await analytics.readLocal(), isEmpty);
  });

  test('rejects arbitrary identifiers and unapproved properties', () async {
    SharedPreferences.setMockInitialValues({});
    final analytics = GameAnalytics();
    expect(() => analytics.record('email', {}), throwsArgumentError);
    expect(
      () => analytics.record('level_start', {'email': 'person@example.com'}),
      throwsArgumentError,
    );
    expect(
      () => analytics.record('level_start', {'mode': 'person@example.com'}),
      throwsArgumentError,
    );
    expect(await analytics.readLocal(), isEmpty);
  });
}
