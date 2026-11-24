import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/daily_reset.dart';
import 'package:glowpath/ui/design.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
  });

  testWidgets(
    'UTC midnight announces availability and preserves the old route',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var now = DateTime.parse('2026-11-22T23:59:58.200Z');
      await tester.pumpWidget(_host(now: () => now));
      expect(find.text('00:00:02'), findsOneWidget);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:00:01'), findsOneWidget);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('New trio ready'), findsOneWidget);
      expect(find.text('Your current route stays saved.'), findsOneWidget);
      expect(
        tester.semantics.find(find.byType(DailyReset)).getSemanticsData().value,
        contains('Your current route is preserved'),
      );
      now = now.add(const Duration(hours: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('New trio ready'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );

  testWidgets('pause suspends updates and resume recomputes wall clock', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 22, 12);
    await tester.pumpWidget(_host(now: () => now));
    expect(find.text('12:00:00'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('12:00:00'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('10:00:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('3x text fits a narrow phone with real fonts', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(now: () => DateTime.utc(2026, 11, 22, 1), scale: 3),
    );
    expect(find.text('23:00:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'fresh daily date replaces the ready state with its next window',
    (tester) async {
      final now = DateTime.utc(2026, 11, 23, 8, 15, 30);
      await tester.pumpWidget(_host(now: () => now));
      expect(find.text('New trio ready'), findsOneWidget);
      await tester.pumpWidget(_host(now: () => now, date: '2026-11-23'));
      expect(find.text('15:44:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('compact HUD fits 40 pixels and retains midnight semantics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    var now = DateTime.utc(2026, 11, 22, 23, 59, 59);
    await tester.pumpWidget(_host(now: () => now, compact: true));
    expect(find.text('Next trio'), findsOneWidget);
    expect(find.text('00:00:01'), findsOneWidget);
    expect(
      tester.getSize(find.byType(DailyReset)).height,
      lessThanOrEqualTo(40),
    );
    expect(
      tester.semantics.find(find.byType(DailyReset)).getSemanticsData().value,
      contains('Refreshes at midnight UTC. Your current route is preserved.'),
    );
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('New trio ready'), findsOneWidget);
    expect(
      tester.getSize(find.byType(DailyReset)).height,
      lessThanOrEqualTo(40),
    );
    expect(
      tester.semantics.find(find.byType(DailyReset)).getSemanticsData().value,
      'A new trio is ready. Your current route is preserved.',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('compact large text wraps without losing the countdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(now: () => DateTime.utc(2026, 11, 22, 1), scale: 3, compact: true),
    );
    expect(find.text('23:00:00'), findsOneWidget);
    final clock = tester.getRect(
      find.byKey(const ValueKey('daily-reset-countdown')),
    );
    final instrument = tester.getRect(find.byType(DailyReset));
    expect(clock.right, lessThanOrEqualTo(instrument.right));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _host({
  required DateTime Function() now,
  String date = '2026-11-22',
  double scale = 1,
  bool compact = false,
}) => MaterialApp(
  theme: gameTheme(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 288,
          child: DailyReset(dailyDate: date, now: now, compact: compact),
        ),
      ),
    ),
  ),
);
