import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
  });

  for (final size in [const Size(80, 400), const Size(76, 360)]) {
    testWidgets('vertical instrument fits $size with enlarged text', (
      tester,
    ) async {
      for (final scale in [1.0, 2.0, 3.0]) {
        for (final seconds in [30, 9, 0]) {
          await _host(
            tester,
            remaining: Duration(seconds: seconds),
            size: size,
            scale: scale,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final instrument = _rect(tester, 'launch-countdown');
          expect(instrument.size, size);
          for (final key in [
            'launch-seconds',
            'launch-time-rail',
            'countdown-rocket',
          ]) {
            final child = _rect(tester, key);
            expect(child.left, greaterThanOrEqualTo(instrument.left));
            expect(child.right, lessThanOrEqualTo(instrument.right));
            expect(child.top, greaterThanOrEqualTo(instrument.top));
            expect(child.bottom, lessThanOrEqualTo(instrument.bottom));
          }
          expect(find.text('${seconds}s'), findsOneWidget);
          expect(find.text('LAUNCH'), findsOneWidget);
        }
      }
    });
  }

  testWidgets('craft ascends toward the fixed readout as time runs out', (
    tester,
  ) async {
    final positions = <Offset>[];
    Rect? instrument;
    double? numberTop;
    for (final seconds in [30, 20, 10, 0]) {
      await _host(tester, remaining: Duration(seconds: seconds));
      await tester.pumpAndSettle();
      instrument ??= _rect(tester, 'launch-countdown');
      numberTop ??= _rect(tester, 'launch-seconds').top;
      expect(_rect(tester, 'launch-seconds').top, numberTop);
      expect(_rect(tester, 'launch-countdown'), instrument);
      final craft = _rect(tester, 'countdown-rocket');
      positions.add(craft.center);
      expect(craft.height, greaterThan(craft.width));
      expect(craft.top, greaterThan(_rect(tester, 'launch-seconds').bottom));
      expect(
        tester
            .widget<RotatedBox>(
              find.byKey(const ValueKey('vertical-launch-craft-orientation')),
            )
            .quarterTurns,
        3,
      );
    }
    for (var i = 1; i < positions.length; i++) {
      expect(positions[i].dy, lessThan(positions[i - 1].dy));
      expect(positions[i].dx, positions.first.dx);
    }
    expect(positions.first.dy, greaterThan(instrument!.bottom - 45));
    expect(positions.last.dy, lessThan(instrument.top + 120));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('subsecond owner updates glide then stop without an idle clock', (
    tester,
  ) async {
    await _host(tester, remaining: const Duration(seconds: 10));
    final before = _rect(tester, 'countdown-rocket').center;
    await _host(tester, remaining: const Duration(milliseconds: 9800));
    expect(_rect(tester, 'countdown-rocket').center, before);
    await tester.pump(const Duration(milliseconds: 100));
    final middle = _rect(tester, 'countdown-rocket').center;
    await tester.pump(const Duration(milliseconds: 100));
    final after = _rect(tester, 'countdown-rocket').center;
    expect(middle.dy, lessThan(before.dy));
    expect(middle.dy, greaterThan(after.dy));
    expect(find.text('10s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(_rect(tester, 'countdown-rocket').center, after);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('paused and reduced-motion instruments settle immediately', (
    tester,
  ) async {
    for (final state in ['paused', 'reduced', 'system-reduced']) {
      await _host(tester, remaining: const Duration(seconds: 30));
      await tester.pumpAndSettle();
      final before = _rect(tester, 'countdown-rocket').center;
      await _host(tester, remaining: const Duration(seconds: 15), state: state);
      await tester.pump();
      final after = _rect(tester, 'countdown-rocket').center;
      expect(after.dy, lessThan(before.dy));
      expect(tester.binding.transientCallbackCount, 0, reason: state);
      await tester.pump(const Duration(seconds: 2));
      expect(_rect(tester, 'countdown-rocket').center, after);
    }
  });

  testWidgets(
    'vertical states preserve accessible status and terminal results',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final state in ['active', 'paused', 'expired', 'complete']) {
          await _host(
            tester,
            remaining: Duration(seconds: state == 'expired' ? 0 : 8),
            state: state,
          );
          await tester.pumpAndSettle();
          final status = tester.semantics
              .find(find.byKey(const ValueKey('launch-countdown')))
              .getSemanticsData();
          expect(status.label, 'Launch countdown');
          expect(status.value, switch (state) {
            'paused' => '8 seconds remaining. Countdown paused.',
            'expired' => 'Launch time reached. Route incomplete.',
            'complete' => 'Rocket launched. Route complete.',
            _ => '8 seconds remaining. Rocket at full thrust. Launches automatically.',
          });
          expect(
            status.flagsCollection.isLiveRegion,
            state == 'expired' || state == 'complete',
          );
          expect(
            find.text(switch (state) {
              'paused' => 'PAUSED',
              'expired' => 'TIME UP',
              'complete' => 'LAUNCHED',
              _ => 'LAUNCH',
            }),
            findsOneWidget,
          );
          expect(find.byType(GestureDetector), findsNothing);
          expect(tester.binding.transientCallbackCount, 0);
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}

Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey(key)));

Future<void> _host(
  WidgetTester tester, {
  required Duration remaining,
  Size size = const Size(80, 400),
  double scale = 1,
  String state = 'active',
}) => tester.pumpWidget(
  MaterialApp(
    theme: gameTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(scale),
        disableAnimations: state == 'system-reduced',
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: LaunchCountdown(
              vertical: true,
              remaining: remaining,
              total: const Duration(seconds: 30),
              reducedMotion: state == 'reduced',
              expired: state == 'expired',
              complete: state == 'complete',
              paused: state == 'paused',
            ),
          ),
        ),
      ),
    ),
  ),
);
