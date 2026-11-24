import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

const _scene = ValueKey('scroll-voyage-scene');

void main() {
  testWidgets(
    'a single wheel signal survives release between its first frames',
    (tester) async {
      await _show(tester);
      await _sendWheel(tester, 42);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_depth(tester), greaterThan(0));
      await tester.pumpAndSettle();
      expect(_depth(tester), 0);
    },
  );

  testWidgets('33ms wheel signals keep moving between unsynchronized frames', (
    tester,
  ) async {
    await _show(tester);
    await _sendWheel(tester, 12);
    final position = tester.getCenter(find.byKey(_scene));
    final input = Timer.periodic(const Duration(milliseconds: 33), (_) {
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: position,
          scrollDelta: const Offset(0, 12),
        ),
      );
    });
    var advancingFrames = 0;
    var previous = 0.0;
    final depths = <double>[];
    try {
      for (var frame = 0; frame < 32; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final current = _depth(tester);
        depths.add(current);
        if (current > previous + .0001) advancingFrames++;
        previous = current;
      }
    } finally {
      input.cancel();
    }
    expect(
      advancingFrames,
      greaterThan(12),
      reason:
          'Frame depths: ${depths.map((depth) => depth.toStringAsFixed(3)).join(', ')}',
    );
    expect(_depth(tester), greaterThan(.15));
    await tester.pumpAndSettle();
    expect(_depth(tester), 0);
  });

  for (final direction in [-1.0, 1.0]) {
    testWidgets(
      'wheel $direction responds on the first frame without leaping',
      (tester) async {
        await _show(tester);
        await _wheel(tester, direction * 42);
        expect(_depth(tester), closeTo(0, .001));
        await tester.pump(const Duration(milliseconds: 16));
        final firstFrame = _depth(tester).abs();
        expect(firstFrame, greaterThan(.005));
        expect(firstFrame, lessThan(.06));
        await tester.pump(const Duration(milliseconds: 9));
        var peak = firstFrame;
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (_depth(tester).abs() > peak) peak = _depth(tester).abs();
        }
        // A modest wheel gesture must not throw the current destination out
        // of view. At 350px high, this is a 0.12-page wheel gesture.
        expect(peak, lessThan(.9));
        expect(
          _painter(tester).visiblePlanetBounds(const Size(342, 350)).keys,
          contains(1),
        );
        await tester.pumpAndSettle();
        expect(_depth(tester), 0);
        expect(_painter(tester).current.planetIndex, 1);
        expect(_painter(tester).routesAtDestination, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('retargeting and reversal preserve the displayed velocity', (
    tester,
  ) async {
    await _show(tester);
    for (var frame = 0; frame < 6; frame++) {
      await _wheel(tester, 8);
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (final delta in [42.0, -42.0]) {
      final before = _depth(tester);
      await tester.pump(const Duration(milliseconds: 1));
      final atEvent = _depth(tester);
      final velocityBefore = (atEvent - before) / .001;
      await _wheel(tester, delta);
      expect(_depth(tester), closeTo(atEvent, .00001));
      await tester.pump(const Duration(milliseconds: 1));
      final velocityAfter = (_depth(tester) - atEvent) / .001;
      // New input changes acceleration, not position or velocity. A new
      // easing tween per event produces a large velocity jump here.
      expect((velocityAfter - velocityBefore).abs(), lessThan(.35));
      await tester.pump(const Duration(milliseconds: 12));
    }
    final afterReversal = _depth(tester);
    for (var frame = 0; frame < 4; frame++) {
      await _wheel(tester, -8);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_depth(tester), lessThan(afterReversal));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(_depth(tester), 0);
  });

  testWidgets('wheel bursts between frames never restart the frame clock', (
    tester,
  ) async {
    await _show(tester);
    var previous = 0.0;
    for (var frame = 0; frame < 9; frame++) {
      // Browser input can deliver several trackpad signals between vsyncs.
      // Do not give each signal an artificial zero-duration animation frame.
      await _sendWheel(tester, 4);
      await _sendWheel(tester, 4);
      await tester.pump(const Duration(milliseconds: 16));
      final current = _depth(tester);
      if (frame > 0) expect(current, greaterThan(previous));
      expect(current - previous, lessThan(.15));
      previous = current;
    }
    expect(previous, greaterThan(.3));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();
    expect(_depth(tester), 0);
  });

  testWidgets('active wheel bursts do not fight the home spring', (
    tester,
  ) async {
    await _show(tester);
    var last = 0.0;
    for (var frame = 0; frame < 20; frame++) {
      await _wheel(tester, 8);
      await tester.pump(const Duration(milliseconds: 16));
      final current = _depth(tester);
      expect(current, greaterThanOrEqualTo(last - .00001));
      expect(current - last, lessThan(.15));
      last = current;
    }
    await tester.pump(const Duration(milliseconds: 9));
    await tester.pump(const Duration(milliseconds: 39));
    final at64ms = _depth(tester);
    await tester.pump(const Duration(milliseconds: 16));
    // By 80ms after final input, the camera is moving toward home. The
    // short forward continuation before this preserves release momentum.
    expect(_depth(tester), lessThan(at64ms));
    await tester.pumpAndSettle();
    expect(_depth(tester), 0);
  });

  testWidgets('wheel release snaps home with a small bounded elastic rebound', (
    tester,
  ) async {
    await _show(tester);
    for (var frame = 0; frame < 20; frame++) {
      await _wheel(tester, 8);
      await tester.pump(const Duration(milliseconds: 16));
    }
    final beforeReturn = _depth(tester);
    await tester.pump(const Duration(milliseconds: 9));
    final held = _depth(tester);
    expect(held, closeTo(beforeReturn, .001));
    var lowest = held;
    for (var frame = 1; frame <= 90; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final depth = _depth(tester);
      if (depth < lowest) lowest = depth;
      expect(depth, greaterThanOrEqualTo(-held * .04));
      if (frame == 21) {
        // At 336ms the return must already read as having reached home,
        // rather than slowly drifting back across the following seconds.
        expect(depth.abs(), lessThan(held * .06));
      }
    }
    expect(lowest, lessThan(-held * .005));
    expect(_depth(tester), 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('trackpad-sized bursts accumulate and restart the quiet window', (
    tester,
  ) async {
    await _show(tester);
    for (var i = 0; i < 6; i++) {
      await _wheel(tester, 8);
      await tester.pump(const Duration(milliseconds: 16));
    }
    final held = _depth(tester);
    expect(held, greaterThan(.15));
    expect(held, lessThan(1));
    await _wheel(tester, 8);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_depth(tester), greaterThan(held));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(_depth(tester), 0);
  });

  testWidgets('first-planet wheel backtracking keeps increasing resistance', (
    tester,
  ) async {
    await _show(tester, level: 1, reduced: true);
    final positions = <double>[];
    for (var i = 0; i < 3; i++) {
      await _wheel(tester, -60);
      await tester.pump(const Duration(milliseconds: 16));
      positions.add(_depth(tester));
    }
    expect(positions[1], lessThan(positions[0]));
    expect(positions[2], lessThan(positions[1]));
    expect(positions[1] - positions[2], lessThan(positions[0] - positions[1]));
    expect(positions.last, greaterThan(VoyageElasticity.minimumDepth(0)));
    expect(
      _painter(tester).visiblePlanetBounds(const Size(342, 350)).keys,
      everyElement(greaterThanOrEqualTo(0)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(_depth(tester), 0);
  });

  testWidgets('wheel over the map is consumed without scrolling its parent', (
    tester,
  ) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 120),
                _explorer(),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _wheel(tester, 100);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_depth(tester), greaterThan(0));
    expect(scroll.offset, 0);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: Offset(20, 20),
        scrollDelta: Offset(0, 100),
      ),
    );
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    scroll.dispose();
  });

  testWidgets('touch takes over wheel motion without a timer interrupting it', (
    tester,
  ) async {
    await _show(tester);
    await _wheel(tester, 90);
    await tester.pump(const Duration(milliseconds: 16));
    final atGrab = _depth(tester);
    final touch = await tester.startGesture(
      tester.getCenter(find.byKey(_scene)),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(_depth(tester), closeTo(atGrab, .001));
    await touch.moveBy(const Offset(0, 40));
    await tester.pump();
    final dragged = _depth(tester);
    expect(dragged, greaterThan(atGrab));
    await _wheel(tester, -300);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_depth(tester), closeTo(dragged, .001));
    await touch.cancel();
    await tester.pumpAndSettle();
    expect(_depth(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion follows wheel directly and resets after quiet', (
    tester,
  ) async {
    await _show(tester, reduced: true);
    await _wheel(tester, -60);
    expect(_depth(tester), lessThan(0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_depth(tester), lessThan(0));
    await tester.pump(const Duration(milliseconds: 9));
    expect(_depth(tester), 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('unmount cancels pending wheel return', (tester) async {
    await _show(tester);
    await _wheel(tester, 80);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1000));
    expect(tester.takeException(), isNull);
  });
}

Widget _explorer({int level = 16, bool reduced = false}) => SizedBox(
  width: 342,
  height: 350,
  child: VoyageExplorer(
    current: VoyageWorld.forLevel(level),
    routesAtDestination: 2,
    reduceMotion: reduced,
    animateArrival: false,
    sceneKey: _scene,
  ),
);

Future<void> _show(
  WidgetTester tester, {
  int level = 16,
  bool reduced = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: _explorer(level: level, reduced: reduced),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _wheel(WidgetTester tester, double delta) async {
  await _sendWheel(tester, delta);
  await tester.pump();
}

Future<void> _sendWheel(WidgetTester tester, double delta) async {
  await tester.sendEventToBinding(
    PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: tester.getCenter(find.byKey(_scene)),
      scrollDelta: Offset(0, delta),
    ),
  );
}

VoyageDepthPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(_scene)).painter!
        as VoyageDepthPainter;
double _depth(WidgetTester tester) => _painter(tester).cameraExcursion;
