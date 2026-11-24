import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

const _scene = ValueKey('ambient-explorer');

void main() {
  testWidgets('idle voyage changes pixels without rebuilding scene or HUD', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 844,
            child: RepaintBoundary(
              key: const ValueKey('ambient-capture'),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: VoyageExplorer(
                      current: VoyageWorld.forLevel(11),
                      routesAtDestination: 2,
                      arrivalDuration: Duration.zero,
                      ambientMotion: true,
                      sceneKey: _scene,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Builder(
                      builder: (_) {
                        builds++;
                        return const Text(
                          'Play',
                          key: ValueKey('floating-hud'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final beforePainter = _painter(tester);
    final beforePhase = beforePainter.ambientPhase;
    final beforeBuilds = builds;
    final hudBounds = tester.getRect(
      find.byKey(const ValueKey('floating-hud')),
    );
    final before = await _pixels(tester);
    await tester.pump(const Duration(seconds: 16));
    expect(
      identical(_painter(tester), beforePainter),
      isTrue,
      reason:
          'Ambient frames repaint the existing painter without rebuilding it.',
    );
    expect(_painter(tester).ambientPhase, greaterThan(beforePhase));
    expect(builds, beforeBuilds);
    expect(
      tester.getRect(find.byKey(const ValueKey('floating-hud'))),
      hudBounds,
    );
    final after = await _pixels(tester);
    expect(after, isNot(orderedEquals(before)));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'voyage ambient pauses for lifecycle, preferences and TickerMode',
    (tester) async {
      Widget scene({
        bool ambient = true,
        bool reduced = false,
        bool osReduced = false,
        bool osDisabled = false,
        bool ticker = true,
      }) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            reduceMotion: osReduced,
            disableAnimations: osDisabled,
          ),
          child: TickerMode(
            enabled: ticker,
            child: VoyageExplorer(
              current: VoyageWorld.forLevel(6),
              routesAtDestination: 2,
              sceneKey: _scene,
              arrivalDuration: Duration.zero,
              ambientMotion: ambient,
              reduceMotion: reduced,
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(seconds: 1));
      final initial = _painter(tester).ambientPhase;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      expect(_painter(tester).ambientPhase, initial);
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(_painter(tester).ambientPhase, greaterThan(initial));
      expect(tester.binding.hasScheduledFrame, isTrue);
      for (final widget in [
        scene(ambient: false),
        scene(reduced: true),
        scene(osReduced: true),
        scene(osDisabled: true),
        scene(ticker: false),
      ]) {
        await tester.pumpWidget(widget);
        await tester.pump();
        final phase = _painter(tester).ambientPhase;
        await tester.pump(const Duration(seconds: 16));
        expect(_painter(tester).ambientPhase, phase);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}

VoyageDepthPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(_scene)).painter!
        as VoyageDepthPainter;

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('ambient-capture')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }))!;
}
