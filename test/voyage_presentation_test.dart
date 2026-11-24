import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
  });

  test(
    'forward camera movement expands away from a stable vanishing point',
    () {
      const viewport = Size(342, 350);
      final vanishing = VoyageDepthPainter.project(viewport, 0, 0, 2);
      final far = VoyageDepthPainter.project(viewport, -.72, .72, 2.4);
      final near = VoyageDepthPainter.project(viewport, -.72, .72, 1.92);
      expect(VoyageDepthPainter.project(viewport, 0, 0, 1.92), vanishing);
      expect(
        (near - vanishing).distance,
        greaterThan((far - vanishing).distance),
      );
      expect(
        (near.dx - vanishing.dx) / (far.dx - vanishing.dx),
        closeTo(1.25, .00001),
      );
      expect(
        (near.dy - vanishing.dy) / (far.dy - vanishing.dy),
        closeTo(1.25, .00001),
      );
    },
  );

  for (final entry in [
    (width: 390.0, scale: 1.0),
    (width: 320.0, scale: 3.0),
  ]) {
    testWidgets(
      'chart names, progress and sole Continue remain usable at $entry',
      (tester) async {
        tester.view.physicalSize = Size(entry.width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        var continued = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(entry.width, 844),
                textScaler: TextScaler.linear(entry.scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: RepaintBoundary(
                      key: const ValueKey('map-capture'),
                      child: VoyageMap(
                        completedRoutes: 2,
                        reduceMotion: true,
                        onContinue: () => continued++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final name in ['Luma', 'Ember', 'Viridian', 'Halo']) {
          expect(find.text(name), findsOneWidget);
        }
        expect(find.byType(SpaceAction), findsOneWidget);
        expect(find.text('2 of 75 routes charted · Galaxy 1'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'Luma. Current destination. 2 of 15 routes charted.',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Halo. Upcoming destination. 0 of 15 routes charted. Complete earlier routes to unlock.',
          ),
          findsOneWidget,
        );
        if (entry.width == 390 &&
            Platform.environment['GLOWPATH_RENDER_MAP'] == '1') {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('map-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('/tmp/glowpath-voyage-map.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.byType(SpaceAction));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SpaceAction));
        expect(continued, 1);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'depth approach is finite and reduced motion settles immediately',
    (tester) async {
      Widget map(bool reduce) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VoyageMap(
              completedRoutes: 6,
              reduceMotion: reduce,
              onContinue: () {},
            ),
          ),
        ),
      );
      VoyageDepthPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('voyage-depth-scene')),
                  )
                  .painter!
              as VoyageDepthPainter;
      await tester.pumpWidget(map(false));
      expect(painter().approach, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(painter().approach, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(painter().approach, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(map(true));
      await tester.pump();
      expect(painter().approach, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ambient scenery never rebuilds or moves the puzzle child', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SpaceBackdrop(
          level: 1,
          reduceMotion: false,
          child: Builder(
            builder: (_) {
              builds++;
              return const Center(
                child: SizedBox(
                  key: ValueKey('steady-board'),
                  width: 200,
                  height: 200,
                ),
              );
            },
          ),
        ),
      ),
    );
    final initialBuilds = builds;
    final bounds = tester.getRect(find.byKey(const ValueKey('steady-board')));
    await tester.pump(const Duration(seconds: 16));
    expect(builds, initialBuilds);
    expect(tester.getRect(find.byKey(const ValueKey('steady-board'))), bounds);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ambient motion stops for preferences, ticker mode and lifecycle',
    (tester) async {
      Widget scene({
        bool reduced = false,
        bool ticker = true,
        bool ambient = true,
        bool osReduce = false,
        bool osDisable = false,
      }) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            reduceMotion: osReduce,
            disableAnimations: osDisable,
          ),
          child: TickerMode(
            enabled: ticker,
            child: SpaceBackdrop(
              level: 1,
              reduceMotion: reduced,
              ambientMotion: ambient,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      for (final widget in [
        scene(reduced: true),
        scene(ticker: false),
        scene(ambient: false),
        scene(osReduce: true),
        scene(osDisable: true),
      ]) {
        await tester.pumpWidget(widget);
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('courier paints approach and docking for every destination', (
    tester,
  ) async {
    for (var destination = 0; destination < 5; destination++) {
      for (final progress in [0.0, .5, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 320,
                height: 350,
                child: CustomPaint(
                  painter: VoyageDepthPainter(
                    current: VoyageWorld.forLevel(destination * 15 + 1),
                    approach: progress,
                    routesAtDestination: destination,
                    showCourier: true,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'Destination $destination at $progress',
        );
      }
    }
  });
}
