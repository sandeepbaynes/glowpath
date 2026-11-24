import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

const _scene = ValueKey('elastic-system');

void main() {
  testWidgets('voyage exploration is an enabled adjustable semantic control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _show(tester, reduced: true);
    expect(
      tester.semantics.find(find.bySemanticsLabel('Voyage system')),
      isSemantics(
        isEnabled: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    semantics.dispose();
  });

  test('camera response gains resistance farther from the anchor', () {
    const height = 350.0;
    double depth(double drag) => VoyageElasticity.depthForDrag(drag, height);
    expect(depth(0), 0);
    expect(depth(-100), -depth(100));
    expect(depth(100) - depth(0), greaterThan(depth(200) - depth(100)));
    expect(depth(200) - depth(100), greaterThan(depth(300) - depth(200)));
    expect(depth(100000), lessThan(VoyageElasticity.maxDepth));
    for (final drag in [-500.0, -70.0, 0.0, 70.0, 500.0]) {
      expect(
        VoyageElasticity.dragForDepth(depth(drag), height),
        closeTo(drag, .001),
      );
    }
  });

  test(
    'backward drag approaches the available history without a hard edge',
    () {
      for (final planet in [0, 1, 8]) {
        const height = 350.0;
        double depth(double pixels) =>
            VoyageElasticity.depthForDrag(-pixels, height, planetIndex: planet);
        final positions = [
          for (final pull in [25.0, 75.0, 125.0, 175.0]) depth(pull),
        ];
        for (var i = 1; i < positions.length; i++) {
          expect(positions[i], lessThan(positions[i - 1]));
          expect(
            positions[i],
            greaterThan(VoyageElasticity.minimumDepth(planet)),
          );
        }
        expect(
          positions[0] - positions[1],
          greaterThan(positions[1] - positions[2]),
        );
        expect(
          positions[1] - positions[2],
          greaterThan(positions[2] - positions[3]),
        );
        expect(
          depth(100000),
          greaterThan(VoyageElasticity.minimumDepth(planet)),
        );
        for (final pixels in [-700.0, -150.0, -20.0, 0.0, 150.0]) {
          final excursion = VoyageElasticity.depthForDrag(
            pixels,
            height,
            planetIndex: planet,
          );
          expect(
            VoyageElasticity.dragForDepth(
              excursion,
              height,
              planetIndex: planet,
            ),
            closeTo(pixels, .001),
          );
        }
      }
    },
  );

  for (final level in [1, 16]) {
    testWidgets(
      'planet ${(level - 1) ~/ 15 + 1} keeps stretching backward and springs home',
      (tester) async {
        await _show(tester, level: level);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_scene)),
        );
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
        final first = _painter(tester);
        final initialDepth = first.cameraExcursion;
        final initialBounds = first.currentPlanetBounds(const Size(342, 350));
        await gesture.moveBy(const Offset(0, -70));
        await tester.pump();
        final second = _painter(tester);
        expect(second.cameraExcursion, lessThan(initialDepth));
        expect(
          second.currentPlanetBounds(const Size(342, 350)).width,
          lessThan(initialBounds.width),
        );
        final middleDepth = second.cameraExcursion;
        await gesture.moveBy(const Offset(0, -70));
        await tester.pump();
        final pulled = _painter(tester).cameraExcursion;
        expect(pulled, lessThan(middleDepth));
        expect(middleDepth - pulled, lessThan(initialDepth - middleDepth));
        final bodies = _painter(tester)
            .visiblePlanetBounds(const Size(342, 350));
        expect(bodies.keys, everyElement(greaterThanOrEqualTo(0)));
        expect(bodies.length, lessThanOrEqualTo(4));
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pump();
        expect(_painter(tester).cameraExcursion, closeTo(pulled, .001));
        await tester.pump(const Duration(milliseconds: 120));
        expect(_painter(tester).cameraExcursion, inExclusiveRange(pulled, 0));
        await tester.pumpAndSettle();
        expect(_painter(tester).cameraExcursion, 0);
        expect(_painter(tester).current.planetIndex, (level - 1) ~/ 15);
        expect(_painter(tester).routesAtDestination, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'downward exploration changes depth then springs past home and settles',
    (tester) async {
      await _show(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_scene)),
      );
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      final pulled = _painter(tester).cameraExcursion;
      expect(pulled, greaterThan(0));
      expect(_painter(tester).current.index, 1);
      expect(_painter(tester).routesAtDestination, 2);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();
      expect(_painter(tester).cameraExcursion, closeTo(pulled, .001));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_painter(tester).cameraExcursion, inExclusiveRange(0, pulled));
      await tester.pump(const Duration(milliseconds: 230));
      expect(_painter(tester).cameraExcursion, lessThan(0));
      expect(_painter(tester).cameraExcursion.abs(), lessThan(pulled * .1));
      await tester.pumpAndSettle();
      expect(_painter(tester).cameraExcursion, 0);
      expect(_painter(tester).current.index, 1);
      expect(_painter(tester).routesAtDestination, 2);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('cancel returns home and re-grabbing a spring does not jump', (
    tester,
  ) async {
    await _show(tester);
    final center = tester.getCenter(find.byKey(_scene));
    final first = await tester.startGesture(center);
    await first.moveBy(const Offset(0, 30));
    await first.moveBy(const Offset(0, -150));
    await tester.pump();
    expect(_painter(tester).cameraExcursion, lessThan(0));
    await first.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midReturn = _painter(tester).cameraExcursion;
    final second = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_painter(tester).cameraExcursion, closeTo(midReturn, .001));
    await second.moveBy(const Offset(0, 22));
    await tester.pump();
    final rawAtGrab = VoyageElasticity.dragForDepth(
      midReturn,
      350,
      planetIndex: 1,
    );
    final expected = VoyageElasticity.depthForDrag(
      rawAtGrab + 22,
      350,
      planetIndex: 1,
    );
    expect(_painter(tester).cameraExcursion, closeTo(expected, .015));
    await second.moveBy(const Offset(0, 10));
    await tester.pump();
    expect(
      _painter(tester).cameraExcursion,
      closeTo(
        VoyageElasticity.depthForDrag(rawAtGrab + 32, 350, planetIndex: 1),
        .015,
      ),
    );
    await second.cancel();
    await tester.pumpAndSettle();
    expect(_painter(tester).cameraExcursion, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion allows a direct pull but returns immediately', (
    tester,
  ) async {
    await _show(tester, reduced: true);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_scene)),
    );
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 110));
    await tester.pump();
    expect(_painter(tester).cameraExcursion, greaterThan(0));
    await gesture.up();
    await tester.pump();
    expect(_painter(tester).cameraExcursion, 0);
    expect(_painter(tester).approach, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'dragging the scene does not dismiss its sheet or activate Continue',
    (tester) async {
      var continued = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: VoyageMap(
                        completedRoutes: 16,
                        onContinue: () => continued++,
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final scene = find.byKey(const ValueKey('voyage-depth-scene'));
      await tester.drag(scene, const Offset(0, 150));
      await tester.pumpAndSettle();
      expect(find.byType(VoyageMap), findsOneWidget);
      expect(continued, 0);
      final painter =
          tester.widget<CustomPaint>(scene).painter! as VoyageDepthPainter;
      expect(painter.cameraExcursion, 0);
      expect(painter.current.index, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('extreme camera pulls remain paintable on phone and desktop', (
    tester,
  ) async {
    for (final size in [const Size(390, 844), const Size(1200, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final excursion in [-1.7, 0.0, 1.7]) {
        for (var world = 0; world < 5; world++) {
          await tester.pumpWidget(
            MaterialApp(
              home: CustomPaint(
                painter: VoyageDepthPainter(
                  current: VoyageWorld.forLevel(world * 15 + 1),
                  routesAtDestination: 4,
                  approach: .5,
                  cameraExcursion: excursion,
                  showCourier: true,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

VoyageDepthPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(_scene)).painter!
        as VoyageDepthPainter;

Future<void> _show(
  WidgetTester tester, {
  bool reduced = false,
  int level = 16,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 342,
            height: 350,
            child: VoyageExplorer(
              current: VoyageWorld.forLevel(level),
              routesAtDestination: 2,
              reduceMotion: reduced,
              sceneKey: _scene,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
