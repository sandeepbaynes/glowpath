import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
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

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('inline countdown fits 320px at ${scale}x without actions', (
      tester,
    ) async {
      await _host(tester, seconds: 60, scale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('60s'), findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);
      final bounds = tester.getRect(
        find.byKey(const ValueKey('launch-countdown')),
      );
      expect(bounds.width, 288);
      if (scale == 1) expect(bounds.height, lessThanOrEqualTo(70));
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets(
    'countdown reads its time and pauses without live announcements',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _host(tester, seconds: 25);
        final timer = find.byKey(const ValueKey('launch-countdown'));
        final active = tester.semantics.find(timer).getSemanticsData();
        expect(active.label, 'Launch countdown');
        expect(active.value, contains('25 seconds remaining'));
        expect(active.flagsCollection.isLiveRegion, isFalse);
        await _host(tester, seconds: 25, paused: true);
        expect(
          tester.semantics.find(timer).getSemanticsData().value,
          '25 seconds remaining. Countdown paused.',
        );
        expect(find.text('Clock paused'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('late countdown has visibly stronger exhaust without a ticker', (
    tester,
  ) async {
    await _host(tester, seconds: 60);
    final cold = await _pixels(tester);
    await _host(tester, seconds: 5);
    final hot = await _pixels(tester);
    var changed = 0;
    for (var i = 0; i < hot.length; i += 4) {
      if ((hot[i] - cold[i]).abs() > 8 ||
          (hot[i + 1] - cold[i + 1]).abs() > 8 ||
          (hot[i + 2] - cold[i + 2]).abs() > 8) {
        changed++;
      }
    }
    expect(changed, greaterThan(40));
    await tester.pump(const Duration(seconds: 3));
    expect(
      await _pixels(tester),
      orderedEquals(hot),
      reason: 'Time belongs to the owner. The instrument has no idle flicker.',
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion keeps countdown and heat information still', (
    tester,
  ) async {
    await _host(tester, seconds: 8, reduced: true);
    final before = await _pixels(tester);
    await tester.pump(const Duration(seconds: 8));
    expect(await _pixels(tester), orderedEquals(before));
    expect(find.text('8s'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'terminal states announce result once and show no launch button',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final timer = find.byKey(const ValueKey('launch-countdown'));
        await _host(tester, seconds: 0, expired: true);
        expect(find.text('Time up'), findsOneWidget);
        expect(
          tester.semantics.find(timer).getSemanticsData().value,
          'Launch time reached. Route incomplete.',
        );
        expect(
          tester.semantics
              .find(timer)
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          isTrue,
        );
        await _host(tester, seconds: 20, complete: true);
        expect(find.text('Launched'), findsOneWidget);
        expect(
          tester.semantics.find(timer).getSemanticsData().value,
          'Rocket launched. Route complete.',
        );
        expect(find.byType(GestureDetector), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );
}

Future<void> _host(
  WidgetTester tester, {
  required int seconds,
  double scale = 1,
  bool paused = false,
  bool reduced = false,
  bool expired = false,
  bool complete = false,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: gameTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RepaintBoundary(
              key: const ValueKey('countdown-capture'),
              child: LaunchCountdown(
                remaining: Duration(seconds: seconds),
                total: const Duration(seconds: 60),
                reducedMotion: reduced,
                expired: expired,
                complete: complete,
                paused: paused,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<List<int>> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('countdown-rocket')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}
