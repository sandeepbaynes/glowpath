import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/daily_reset.dart';
import 'package:glowpath/ui/design.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Atkinson')..addFont(
          rootBundle.load(
            'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
          ),
        ))
        .load();
  });
  testWidgets('weekly instrument counts to Monday and preserves parked route', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var now = DateTime.utc(2026, 11, 22, 23, 59, 59);
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 288,
            child: DailyReset(
              dailyDate: '2026-11-16',
              weekly: true,
              compact: true,
              now: () => now,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Next week'), findsOneWidget);
    expect(find.text('00:00:01'), findsOneWidget);
    expect(
      tester.getSize(find.byType(DailyReset)).height,
      lessThanOrEqualTo(40),
    );
    expect(
      tester.semantics.find(find.byType(DailyReset)).getSemanticsData().value,
      contains('Monday midnight UTC'),
    );
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('New week ready'), findsOneWidget);
    expect(
      tester.semantics.find(find.byType(DailyReset)).getSemanticsData().value,
      contains('current route is preserved'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
  testWidgets(
    'fresh weekly countdown expresses days and fits narrow compact HUD',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 272,
              child: DailyReset(
                dailyDate: '2026-11-23',
                weekly: true,
                compact: true,
                now: () => DateTime.utc(2026, 11, 23, 12),
              ),
            ),
          ),
        ),
      );
      expect(find.text('6d 12:00:00'), findsOneWidget);
      expect(
        tester.getSize(find.byType(DailyReset)).height,
        lessThanOrEqualTo(40),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
