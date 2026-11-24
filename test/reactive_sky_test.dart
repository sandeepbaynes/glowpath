import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/reactive_sky.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tilt moves only painted sky after calibration and stays bounded',
    (tester) async {
      final source = StreamController<AccelerometerEvent>.broadcast();
      addTearDown(source.close);
      var builds = 0;
      var taps = 0;
      await _pumpSky(
        tester,
        source: source.stream,
        child: Builder(
          builder: (context) {
            builds++;
            return Center(
              child: SizedBox(
                key: const ValueKey('steady-board'),
                width: 200,
                height: 200,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const ColoredBox(color: Color(0xFF101D32)),
                ),
              ),
            );
          },
        ),
      );
      expect(source.hasListener, isTrue);
      final board = find.byKey(const ValueKey('steady-board'));
      final before = tester.getRect(board);
      final baselineBuilds = builds;
      await _calibrate(tester, source, x: 2, y: 8);
      expect(_painter(tester).parallax, Offset.zero);
      source.add(_event(7.5, 8));
      await tester.pump();
      final firstMove = _painter(tester).parallax;
      expect(firstMove.dx, lessThan(0));
      expect(firstMove.dx, greaterThan(-1));
      expect(firstMove.dy, closeTo(0, .00001));
      for (var i = 0; i < 80; i++) {
        source.add(_event(1000, -1000));
      }
      await tester.pump();
      final maximum = _painter(tester).parallax;
      expect(maximum.dx.abs(), lessThanOrEqualTo(1));
      expect(maximum.dy.abs(), lessThanOrEqualTo(1));
      expect(maximum.dx.abs(), greaterThan(.9));
      source.add(_event(double.nan, 0));
      await tester.pump();
      expect(_painter(tester).parallax, maximum);
      expect(tester.getRect(board), before);
      expect(builds, baselineBuilds);
      await tester.tap(board);
      expect(taps, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(_painter(tester).parallax, maximum);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final option in [
    'enabled',
    'in-game motion',
    'OS reduceMotion',
    'OS disableAnimations',
  ]) {
    testWidgets('$option stops sensing and re-enabling recalibrates', (
      tester,
    ) async {
      final source = StreamController<AccelerometerEvent>.broadcast();
      addTearDown(source.close);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pumpSky(tester, source: source.stream);
      await _calibrate(tester, source);
      source.add(_event(5, 8));
      await tester.pump();
      expect(_painter(tester).parallax, isNot(Offset.zero));
      if (option.startsWith('OS')) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(
              reduceMotion: option == 'OS reduceMotion',
              disableAnimations: option == 'OS disableAnimations',
            );
        await tester.pump();
      } else {
        await _pumpSky(
          tester,
          source: source.stream,
          enabled: option != 'enabled',
          reduceMotion: option == 'in-game motion',
        );
      }
      expect(source.hasListener, isFalse);
      expect(_painter(tester).parallax, Offset.zero);
      source.add(_event(-5, 8));
      await tester.pump();
      expect(_painter(tester).parallax, Offset.zero);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await _pumpSky(tester, source: source.stream);
      expect(source.hasListener, isTrue);
      await _calibrate(tester, source, x: -4, y: 3);
      expect(_painter(tester).parallax, Offset.zero);
      source.add(_event(1, 3));
      await tester.pump();
      expect(_painter(tester).parallax.dx, lessThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('inactive and background states cancel; resume subscribes once', (
    tester,
  ) async {
    var listens = 0;
    var cancellations = 0;
    final source = StreamController<AccelerometerEvent>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancellations++,
    );
    addTearDown(source.close);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _pumpSky(tester, source: source.stream);
    await _calibrate(tester, source);
    source.add(_event(5, 8));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(source.hasListener, isFalse);
    expect(_painter(tester).parallax, Offset.zero);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(listens, 1);
    expect(cancellations, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _finishSubscriptionChange(tester);
    expect(source.hasListener, isTrue);
    expect(listens, 2);
    await _calibrate(tester, source, x: -3, y: 6);
    expect(_painter(tester).parallax, Offset.zero);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(source.hasListener, isFalse);
    expect(cancellations, 2);
    source.add(_event(100, 100));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacing sensor source cancels the previous subscription', (
    tester,
  ) async {
    final first = StreamController<AccelerometerEvent>.broadcast();
    final second = StreamController<AccelerometerEvent>.broadcast();
    addTearDown(first.close);
    addTearDown(second.close);
    await _pumpSky(tester, source: first.stream);
    await _calibrate(tester, first);
    first.add(_event(5, 8));
    await tester.pump();
    expect(_painter(tester).parallax, isNot(Offset.zero));
    await _pumpSky(tester, source: second.stream);
    expect(first.hasListener, isFalse);
    expect(second.hasListener, isTrue);
    expect(_painter(tester).parallax, Offset.zero);
    first.add(_event(-5, 8));
    await tester.pump();
    expect(_painter(tester).parallax, Offset.zero);
    await _calibrate(tester, second);
    second.add(_event(-5, 8));
    await tester.pump();
    expect(_painter(tester).parallax.dx, greaterThan(0));
  });

  testWidgets(
    'sensor error leaves static playable decoration without retry loop',
    (tester) async {
      var listens = 0;
      var taps = 0;
      final source = StreamController<AccelerometerEvent>.broadcast(
        onListen: () => listens++,
      );
      addTearDown(source.close);
      await _pumpSky(
        tester,
        source: source.stream,
        child: Center(
          child: TextButton(onPressed: () => taps++, child: const Text('Play')),
        ),
      );
      await _calibrate(tester, source);
      source.add(_event(5, 8));
      await tester.pump();
      source.addError(StateError('No accelerometer'));
      await tester.pump();
      expect(source.hasListener, isFalse);
      expect(_painter(tester).parallax, Offset.zero);
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(seconds: 10));
      expect(taps, 1);
      expect(listens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop pointer fallback preserves controls and ignores reduced motion',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var taps = 0;
      final child = Center(
        child: TextButton(
          key: const ValueKey('play'),
          onPressed: () => taps++,
          child: const Text('Play'),
        ),
      );
      await _pumpSky(tester, child: child);
      final before = tester.getRect(find.byKey(const ValueKey('play')));
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: const Offset(160, 200));
      await pointer.moveTo(const Offset(310, 100));
      await tester.pump();
      expect(_painter(tester).parallax.dx, greaterThan(0));
      expect(tester.getRect(find.byKey(const ValueKey('play'))), before);
      await tester.tap(find.text('Play'));
      expect(taps, 1);
      await _pumpSky(tester, child: child, reduceMotion: true);
      await pointer.moveTo(const Offset(5, 400));
      await tester.pump();
      expect(_painter(tester).parallax, Offset.zero);
      await pointer.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
}

AccelerometerEvent _event(double x, double y) =>
    AccelerometerEvent(x, y, 0, DateTime.utc(2026, 11, 22));

Future<void> _calibrate(
  WidgetTester tester,
  StreamController<AccelerometerEvent> source, {
  double x = 0,
  double y = 8,
}) async {
  for (var sample = 0; sample < 4; sample++) {
    source.add(_event(x, y));
  }
  await tester.pump();
}

ReactiveSkyPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('reactive-sky-paint')),
            )
            .painter!
        as ReactiveSkyPainter;

Future<void> _pumpSky(
  WidgetTester tester, {
  Stream<AccelerometerEvent>? source,
  bool enabled = true,
  bool reduceMotion = false,
  Widget child = const SizedBox.expand(),
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ReactiveSky(
        sensorStream: source,
        enabled: enabled,
        reduceMotion: reduceMotion,
        child: SizedBox.expand(child: child),
      ),
    ),
  );
  await _finishSubscriptionChange(tester);
}

Future<void> _finishSubscriptionChange(WidgetTester tester) async {
  // Dart's broadcast cancellation may return its shared root-zone completed
  // Future. Drain that real-zone continuation before the next fake-async frame
  // verifies our deliberately serialized resubscription.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}
