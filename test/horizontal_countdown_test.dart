import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final mode in ['prominent', 'dense', 'compact', 'inline']) {
    testWidgets('$mode rocket carries elapsed time along its horizontal rail', (
      tester,
    ) async {
      for (final scale in [1.0, 3.0]) {
        final positions = <Offset>[];
        Rect? instrument;
        Rect? rail;
        Offset? numberAnchor;
        for (final seconds in [60, 30, 9, 0]) {
          await _host(tester, mode: mode, seconds: seconds, scale: scale);
          await tester.pumpAndSettle();
          instrument ??= _rect(tester, 'launch-countdown');
          rail ??= _rect(tester, 'launch-time-rail');
          numberAnchor ??= _rect(tester, 'launch-seconds').topRight;
          expect(_rect(tester, 'launch-countdown'), instrument);
          expect(_rect(tester, 'launch-time-rail'), rail);
          expect(_rect(tester, 'launch-seconds').topRight, numberAnchor);
          final rocket = _rect(tester, 'countdown-rocket');
          positions.add(rocket.center);
          expect(rocket.width, greaterThan(rocket.height));
          expect(rail.inflate(.01).contains(rocket.topLeft), isTrue);
          expect(rail.inflate(.01).contains(rocket.bottomRight), isTrue);
          expect(tester.takeException(), isNull);
        }
        for (var i = 1; i < positions.length; i++) {
          expect(positions[i].dx, greaterThan(positions[i - 1].dx));
          expect(positions[i].dy, closeTo(positions.first.dy, .01));
        }
        expect(tester.binding.transientCallbackCount, 0);
      }
    });

    testWidgets('$mode follows subsecond clock updates and then stops', (
      tester,
    ) async {
      await _host(tester, mode: mode, seconds: 30);
      final before = _rect(tester, 'countdown-rocket').center;
      await _host(tester, mode: mode, milliseconds: 29800);
      expect(_rect(tester, 'countdown-rocket').center, before);
      await tester.pump(const Duration(milliseconds: 40));
      final middle = _rect(tester, 'countdown-rocket').center;
      await tester.pump(const Duration(milliseconds: 60));
      final after = _rect(tester, 'countdown-rocket').center;
      expect(middle.dx, greaterThan(before.dx));
      expect(middle.dx, lessThan(after.dx));
      expect(find.text('30s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(_rect(tester, 'countdown-rocket').center, after);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('$mode pauses and respects both system motion preferences', (
      tester,
    ) async {
      for (final state in [
        'paused',
        'reduced',
        'disable-animations',
        'reduce-motion',
      ]) {
        await _host(tester, mode: mode, seconds: 60);
        await tester.pumpAndSettle();
        final before = _rect(tester, 'countdown-rocket').center;
        await _host(tester, mode: mode, seconds: 9, state: state);
        await tester.pump();
        final after = _rect(tester, 'countdown-rocket').center;
        expect(after.dx, greaterThan(before.dx));
        expect(tester.binding.transientCallbackCount, 0, reason: state);
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byKey(const ValueKey('countdown-rocket')),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as CountdownRocketPainter;
        expect(painter.reducedMotion, state != 'paused');
        await tester.pump(const Duration(seconds: 2));
        expect(_rect(tester, 'countdown-rocket').center, after);
      }
    });

    testWidgets('$mode reaches launch for terminal and invalid clock values', (
      tester,
    ) async {
      await _host(tester, mode: mode, seconds: 0);
      final finish = _rect(tester, 'countdown-rocket').center;
      for (final state in ['complete', 'expired', 'zero-total', 'negative']) {
        await _host(tester, mode: mode, seconds: 60);
        await tester.pumpAndSettle();
        final start = _rect(tester, 'countdown-rocket').center;
        await _host(
          tester,
          mode: mode,
          seconds: state == 'negative' ? -5 : 20,
          state: state,
        );
        await tester.pumpAndSettle();
        expect(
          (_rect(tester, 'countdown-rocket').center - finish).distance,
          lessThan(.001),
          reason: state,
        );
        await _host(tester, mode: mode, seconds: 120);
        await tester.pumpAndSettle();
        expect(_rect(tester, 'countdown-rocket').center, start);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      }
    });
  }
}

Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(ValueKey(key)));

Future<void> _host(
  WidgetTester tester, {
  required String mode,
  int seconds = 60,
  int? milliseconds,
  double scale = 1,
  String state = 'active',
}) => tester.pumpWidget(
  MaterialApp(
    theme: gameTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(scale),
        disableAnimations: state == 'disable-animations',
        reduceMotion: state == 'reduce-motion',
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: switch (mode) {
              'compact' => 120,
              'dense' => 240,
              _ => 288,
            },
            child: LaunchCountdown(
              compact: mode == 'compact',
              prominent: mode == 'prominent' || mode == 'dense',
              dense: mode == 'dense',
              remaining: Duration(milliseconds: milliseconds ?? seconds * 1000),
              total: Duration(seconds: state == 'zero-total' ? 0 : 60),
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
