import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/launch_pressure.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('pressure starts only near launch and never rebuilds the board', (
    tester,
  ) async {
    final remaining = ValueNotifier(const Duration(seconds: 60));
    addTearDown(remaining.dispose);
    var builds = 0;
    final board = Builder(
      builder: (context) {
        builds++;
        return const SizedBox(key: ValueKey('board'), width: 200, height: 200);
      },
    );
    await tester.pumpWidget(_host(remaining, child: board));
    final initialBuilds = builds;
    final initialRect = tester.getRect(find.byKey(const ValueKey('board')));
    expect(_painter(tester).pressure, 0);
    expect(tester.binding.transientCallbackCount, 0);
    remaining.value = const Duration(seconds: 10);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painter(tester).pressure, greaterThan(0));
    expect(_painter(tester).phase.value, greaterThan(0));
    expect(builds, initialBuilds);
    expect(tester.getRect(find.byKey(const ValueKey('board'))), initialRect);
    final mild = _painter(tester).pressure;
    remaining.value = const Duration(seconds: 2);
    await tester.pump();
    expect(_painter(tester).pressure, greaterThan(mild));
    remaining.value = Duration.zero;
    await tester.pump();
    expect(_painter(tester).pressure, 0);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pressure cannot intercept taps or add screen-reader content', (
    tester,
  ) async {
    final remaining = ValueNotifier(const Duration(seconds: 1));
    addTearDown(remaining.dispose);
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        remaining,
        child: GestureDetector(
          key: const ValueKey('board'),
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: Semantics(
            label: 'Puzzle board',
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(10, 200));
    await tester.tap(find.byKey(const ValueKey('board')));
    expect(taps, 2);
    expect(find.bySemanticsLabel('Puzzle board'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LaunchPressure),
        matching: find.byType(Semantics),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('pause and TickerMode stop visual work immediately', (
    tester,
  ) async {
    final remaining = ValueNotifier(const Duration(seconds: 3));
    addTearDown(remaining.dispose);
    await tester.pumpWidget(_host(remaining));
    await tester.pump(const Duration(milliseconds: 100));
    final phase = _painter(tester).phase;
    await tester.pumpWidget(_host(remaining, active: false));
    final paused = phase.value;
    await tester.pump(const Duration(seconds: 1));
    expect(phase.value, paused);
    expect(_painter(tester).pressure, 0);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_host(remaining, ticking: false));
    await tester.pump(const Duration(seconds: 1));
    expect(phase.value, paused);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_host(remaining));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(phase.value, greaterThan(paused));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final option in ['game', 'reduceMotion', 'disableAnimations']) {
    testWidgets(
      '$option reduced motion keeps a static warning without a ticker',
      (tester) async {
        final remaining = ValueNotifier(const Duration(seconds: 2));
        addTearDown(remaining.dispose);
        await tester.pumpWidget(
          _host(
            remaining,
            reduced: option == 'game',
            systemReduced: option == 'reduceMotion',
            disabledAnimations: option == 'disableAnimations',
          ),
        );
        expect(_painter(tester).still, isTrue);
        expect(_painter(tester).pressure, greaterThan(0));
        final phase = _painter(tester).phase.value;
        await tester.pump(const Duration(seconds: 2));
        expect(_painter(tester).phase.value, phase);
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('backgrounding stops pressure even if the owner remains active', (
    tester,
  ) async {
    final remaining = ValueNotifier(const Duration(seconds: 3));
    addTearDown(remaining.dispose);
    await tester.pumpWidget(_host(remaining));
    await tester.pump(const Duration(milliseconds: 100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final phase = _painter(tester).phase.value;
    await tester.pump(const Duration(seconds: 1));
    expect(_painter(tester).phase.value, phase);
    expect(_painter(tester).pressure, 0);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painter(tester).phase.value, greaterThan(phase));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'strongest pressure paints the edges but leaves central pixels transparent',
    (tester) async {
      final remaining = ValueNotifier(const Duration(milliseconds: 100));
      final phase = ValueNotifier(2.4);
      addTearDown(remaining.dispose);
      addTearDown(phase.dispose);
      final painter = LaunchPressurePainter(
        remaining: remaining,
        total: const Duration(seconds: 60),
        phase: phase,
        active: true,
        still: false,
      );
      final bytes = (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(200, 400));
        final picture = recorder.endRecording();
        final image = await picture.toImage(200, 400);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        picture.dispose();
        image.dispose();
        return bytes;
      }))!;
      int alpha(int x, int y) => bytes.getUint8((y * 200 + x) * 4 + 3);
      expect(alpha(1, 200), greaterThan(0));
      // Every point along the perimeter receives glow, including the old
      // junction between the vertical side wash and horizontal end wash.
      for (var x = 1; x < 199; x++) {
        expect(alpha(x, 1), greaterThan(0), reason: 'Top seam at $x');
        expect(alpha(x, 398), greaterThan(0), reason: 'Bottom seam at $x');
      }
      for (final x in [26, 27, 28, 29, 170, 171, 172, 173]) {
        expect(
          (alpha(x, 2) - alpha(x + 1, 2)).abs(),
          lessThan(4),
          reason: 'Glow must blend continuously across $x',
        );
      }
      for (var y = 80; y <= 320; y += 20) {
        for (var x = 60; x <= 140; x += 20) {
          expect(
            alpha(x, y),
            0,
            reason: 'Central field must stay clear at $x,$y',
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}

LaunchPressurePainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('launch-pressure-field')),
            )
            .painter!
        as LaunchPressurePainter;

Widget _host(
  ValueNotifier<Duration> remaining, {
  bool active = true,
  bool reduced = false,
  bool systemReduced = false,
  bool disabledAnimations = false,
  bool ticking = true,
  Widget? child,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: disabledAnimations,
      reduceMotion: systemReduced,
    ),
    child: TickerMode(
      enabled: ticking,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: child ?? const SizedBox(width: 200, height: 200)),
          LaunchPressure(
            remaining: remaining,
            total: const Duration(seconds: 60),
            active: active,
            reduceMotion: reduced,
          ),
        ],
      ),
    ),
  ),
);
