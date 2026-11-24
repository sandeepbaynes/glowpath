import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const destinations = [1, 5, 6, 49, 50, 51, 525];

  for (final destination in destinations) {
    final current = VoyageWorld.forLevel((destination - 1) * 15 + 1);
    test(
      'destination $destination has a bounded continuing chart and scene',
      () {
        final window = VoyageDestinationWindow(current);
        expect(window.chart, hasLength(4));
        expect(window.scene.length, lessThanOrEqualTo(4));
        expect(
          window.chart.map((world) => world.planetIndex),
          containsAll([
            current.planetIndex,
            current.planetIndex + 1,
            current.planetIndex + 2,
          ]),
        );
        expect(window.scene.last.planetIndex, current.planetIndex + 3);
        for (var i = 1; i < window.scene.length; i++) {
          expect(
            window.scene[i].planetIndex,
            window.scene[i - 1].planetIndex + 1,
          );
        }
        expect(current.planetIndex, destination - 1);
      },
    );

    for (final size in [
      const Size(390, 844),
      const Size(1024, 1366),
      const Size(1366, 1024),
    ]) {
      test(
        'future bodies remain visible from destination $destination on $size',
        () {
          final painter = VoyageDepthPainter(
            current: current,
            approach: 1,
            routesAtDestination: 14,
            showCourier: true,
          );
          final frames = painter.visiblePlanetBounds(size);
          for (var ahead = 1; ahead <= 3; ahead++) {
            final body = frames[current.planetIndex + ahead];
            expect(body, isNotNull);
            expect(body!.width, greaterThan(8));
            expect((Offset.zero & size).contains(body.center), isTrue);
            expect(body.overlaps(Offset.zero & size), isTrue);
          }
          final near = frames[current.planetIndex + 1]!;
          final horizon = frames[current.planetIndex + 3]!;
          expect(horizon.width, lessThan(near.width));
        },
      );
    }
  }

  testWidgets('exploring beyond The Veil never changes the playable anchor', (
    tester,
  ) async {
    final current = VoyageWorld.forLevel(61);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 342,
              height: 350,
              child: VoyageExplorer(
                current: current,
                routesAtDestination: 0,
                animateArrival: false,
                sceneKey: const ValueKey('continuing-voyage'),
              ),
            ),
          ),
        ),
      ),
    );
    final scene = find.byKey(const ValueKey('continuing-voyage'));
    VoyageDepthPainter painter() =>
        tester.widget<CustomPaint>(scene).painter! as VoyageDepthPainter;
    final before = painter().currentPlanetBounds(const Size(342, 350));
    final gesture = await tester.startGesture(tester.getCenter(scene));
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    expect(painter().cameraExcursion, greaterThan(0));
    expect(painter().current.planetIndex, 4);
    expect(
      painter().visiblePlanetBounds(const Size(342, 350)).keys,
      contains(7),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(painter().cameraExcursion, 0);
    expect(painter().current.planetIndex, 4);
    expect(painter().currentPlanetBounds(const Size(342, 350)), before);
    expect(tester.takeException(), isNull);
  });

  for (final entry in [
    (size: const Size(320, 568), scale: 3.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(1024, 1366), scale: 1.0),
    (size: const Size(1366, 1024), scale: 3.0),
  ]) {
    testWidgets(
      'bounded destination chart crosses planet50 without scrolling at $entry',
      (tester) async {
        tester.view.physicalSize = entry.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var continued = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: entry.size,
                textScaler: TextScaler.linear(entry.scale),
              ),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: VoyageMap(
                    completedRoutes: 49 * 15,
                    reduceMotion: true,
                    onContinue: () => continued++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Scrollable), findsNothing);
        final planets = tester.widgetList<PlanetMedallion>(
          find.byType(PlanetMedallion),
        );
        expect(planets.map((planet) => planet.world.planetIndex), [
          48,
          49,
          50,
          51,
        ]);
        expect(find.byType(SpaceAction), findsOneWidget);
        final actionBounds = tester.getRect(find.byType(SpaceAction));
        expect(
          (Offset.zero & entry.size).contains(actionBounds.bottomRight),
          isTrue,
        );
        await tester.tap(find.byType(SpaceAction));
        expect(continued, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
