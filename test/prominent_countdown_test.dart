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

  for (final dense in [false, true]) {
    testWidgets(
      'prominent countdown keeps a fixed ${dense ? 64 : 76}px slot across states and large text',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final width = dense ? 240.0 : 276.0;
          for (final scale in [1.0, 3.0]) {
            for (final state in [
              'active',
              'urgent',
              'paused',
              'expired',
              'complete',
            ]) {
              await _host(
                tester,
                dense: dense,
                width: width,
                scale: scale,
                state: state,
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: '$state / $scale');
              final instrument = tester.getRect(
                find.byKey(const ValueKey('launch-countdown')),
              );
              expect(instrument.size, Size(width, dense ? 64 : 76));
              for (final key in [
                'launch-seconds',
                'launch-time-rail',
                'countdown-rocket',
              ]) {
                final rect = tester.getRect(find.byKey(ValueKey(key)));
                expect(rect.left, greaterThanOrEqualTo(instrument.left));
                expect(rect.right, lessThanOrEqualTo(instrument.right));
                expect(rect.top, greaterThanOrEqualTo(instrument.top));
                expect(rect.bottom, lessThanOrEqualTo(instrument.bottom));
              }
              final value = tester.semantics
                  .find(find.byKey(const ValueKey('launch-countdown')))
                  .getSemanticsData()
                  .value;
              expect(value, switch (state) {
                'paused' => '8 seconds remaining. Countdown paused.',
                'expired' => 'Launch time reached. Route incomplete.',
                'complete' => 'Rocket launched. Route complete.',
                'urgent' => '8 seconds remaining. Rocket at full thrust. Launches automatically.',
                _ => '60 seconds remaining. Rocket warming up. Launches automatically.',
              });
              expect(find.byType(GestureDetector), findsNothing);
            }
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'final seconds become visibly urgent without moving the readout or adding idle animation',
    (tester) async {
      await _host(tester);
      final initialBounds = tester.getRect(
        find.byKey(const ValueKey('launch-countdown')),
      );
      final cold = tester
          .widget<Text>(find.byKey(const ValueKey('launch-seconds')))
          .style!
          .color;
      await _host(tester, remaining: const Duration(milliseconds: 4250));
      await tester.pumpAndSettle();
      final hot = tester
          .widget<Text>(find.byKey(const ValueKey('launch-seconds')))
          .style!
          .color;
      final numberBounds = tester.getRect(
        find.byKey(const ValueKey('launch-seconds')),
      );
      expect(hot, isNot(cold));
      expect(
        tester.getRect(find.byKey(const ValueKey('launch-countdown'))),
        initialBounds,
      );
      final pulse = tester
          .widget<Transform>(
            find.byKey(const ValueKey('launch-pressure-pulse')),
          )
          .transform
          .getMaxScaleOnAxis();
      expect(pulse, greaterThan(1));
      expect(pulse, lessThanOrEqualTo(1.05));
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.getRect(find.byKey(const ValueKey('launch-seconds'))),
        numberBounds,
      );
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'paused, reduced-motion and completed instruments stop pressure pulse',
    (tester) async {
      for (final state in [
        'paused',
        'complete',
        'expired',
        'reduced',
        'system-reduced',
      ]) {
        await _host(
          tester,
          state: state,
          remaining: const Duration(milliseconds: 4250),
        );
        await tester.pumpAndSettle();
        final pulse = tester
            .widget<Transform>(
              find.byKey(const ValueKey('launch-pressure-pulse')),
            )
            .transform
            .getMaxScaleOnAxis();
        expect(pulse, 1, reason: state);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Future<void> _host(
  WidgetTester tester, {
  bool dense = false,
  double width = 276,
  double scale = 1,
  String state = 'active',
  Duration? remaining,
}) async {
  final seconds = switch (state) {
    'expired' => 0,
    'urgent' || 'paused' => 8,
    _ => 60,
  };
  await tester.pumpWidget(
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
              width: width,
              child: LaunchCountdown(
                prominent: true,
                dense: dense,
                remaining: remaining ?? Duration(seconds: seconds),
                total: const Duration(seconds: 60),
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
}
