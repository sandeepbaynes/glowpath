import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/voyage_records.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:glowpath/ui/voyage_archive.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final compact in [false, true]) {
    testWidgets(
      'replay footer clearly resumes the parked route, compact=$compact',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var resumed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(compact ? 3 : 1),
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 600,
                  height: compact ? 240 : 560,
                  child: VoyageMap(
                    completedRoutes: 15,
                    frontierLevel: 16,
                    currentLevel: 1,
                    isReplaying: true,
                    reduceMotion: true,
                    onReplay: (_) {},
                    onContinue: () => resumed = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = compact ? 'Resume' : 'Resume current route';
        expect(find.text(label), findsOneWidget);
        expect(find.bySemanticsLabel('Resume current route'), findsOneWidget);
        expect(find.text('Continue'), findsNothing);
        await tester.tap(find.text(label));
        expect(resumed, isTrue);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  test(
    'a relaxed pull explores several destinations, with increasing resistance',
    () {
      final first = VoyageElasticity.depthForDrag(150, 350);
      expect(first, greaterThan(VoyageDepthPainter.destinationSpacing));
      expect(VoyageElasticity.depthForDrag(350, 350), greaterThan(5));
      expect(
        VoyageElasticity.depthForDrag(700, 350),
        lessThan(VoyageElasticity.maxDepth),
      );
      expect(
        VoyageElasticity.depthForDrag(350, 350) - first,
        greaterThan(
          VoyageElasticity.depthForDrag(550, 350) -
              VoyageElasticity.depthForDrag(350, 350),
        ),
      );
    },
  );

  test('camera window never crowds the scene and farther objects recede', () {
    for (final planet in [0, 4, 49, 524]) {
      for (var step = -76; step <= 76; step++) {
        final painter = VoyageDepthPainter(
          current: VoyageWorld.forLevel(planet * 15 + 1),
          approach: 1,
          routesAtDestination: 0,
          cameraExcursion: step / 10,
        );
        final bodies = painter.visiblePlanetBounds(const Size(390, 844));
        expect(bodies.length, inInclusiveRange(3, 4));
        expect(bodies.keys.every((index) => index >= 0), isTrue);
        final sizes = bodies.values.map((body) => body.width).toList();
        for (var i = 1; i < sizes.length; i++) {
          expect(sizes[i], lessThan(sizes[i - 1]));
        }
      }
    }
    final painter = VoyageDepthPainter(
      current: VoyageWorld.forLevel(61),
      approach: 1,
      routesAtDestination: 0,
      cameraExcursion: 6,
    );
    expect(painter.visiblePlanetBounds(const Size(390, 844)).keys, contains(7));
    expect(
      painter.destinationVisibility(4.5),
      greaterThan(painter.destinationVisibility(7)),
    );
    expect(
      painter.destinationVisibility(7),
      greaterThan(painter.destinationVisibility(10)),
    );
  });

  for (final entry in [
    (size: const Size(320, 568), scale: 3.0),
    (size: const Size(393, 852), scale: 1.0),
    (size: const Size(844, 390), scale: 3.0),
    (size: const Size(740, 360), scale: 3.0),
    (size: const Size(1024, 1366), scale: 1.0),
    (size: const Size(1366, 1024), scale: 3.0),
  ]) {
    testWidgets(
      'first planet replay and future locks fit without scrolling at $entry',
      (tester) async {
        tester.view.physicalSize = entry.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final replayed = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: entry.size,
                textScaler: TextScaler.linear(entry.scale),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: math.min(600, entry.size.width),
                    height: math.min(820, entry.size.height * .92),
                    child: OrbitSheet(
                      title: 'YOUR VOYAGE',
                      fit: true,
                      onClose: () {},
                      child: VoyageMap(
                        completedRoutes: 524 * 15,
                        frontierLevel: 524 * 15 + 1,
                        currentLevel: 524 * 15 + 1,
                        records: const {
                          1: RouteRecord(
                            level: 1,
                            bestScore: 860,
                            bestTime: Duration(milliseconds: 6200),
                          ),
                        },
                        reduceMotion: true,
                        onReplay: replayed.add,
                        onContinue: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('voyage-first-planet')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<VoyageExplorer>(find.byType(VoyageExplorer))
              .current
              .name,
          'Luma',
        );
        await tester.tap(find.byKey(const ValueKey('voyage-route-log')));
        await tester.pumpAndSettle();
        expect(find.textContaining('860'), findsOneWidget);
        expect(find.textContaining('6.2s'), findsOneWidget);
        expect(find.byType(Scrollable), findsNothing);
        expect(tester.takeException(), isNull);
        final first = find.byKey(const ValueKey('replay-route-1'));
        expect(
          (Offset.zero & entry.size).contains(
            tester.getRect(first).bottomRight,
          ),
          isTrue,
        );
        await tester.tap(first);
        expect(replayed, [1]);
        // A long journey can return directly to its frontier without hundreds
        // of backward swipes, then inspect a locked future sector safely.
        await tester.tap(find.byKey(const ValueKey('voyage-current-planet')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('voyage-next-planet')));
        await tester.pumpAndSettle();
        final future = find.byKey(const ValueKey('replay-route-7876'));
        expect(future, findsOneWidget);
        await tester.tap(future);
        expect(replayed, [1]);
        expect(find.byType(Scrollable), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('all fifteen completed routes are reachable in the flight log', (
    tester,
  ) async {
    final replayed = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 280,
              child: VoyageArchive(
                planetIndex: 0,
                frontierLevel: 31,
                records: const {},
                onReplay: replayed.add,
                reduceMotion: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (
      var page = 0;
      page < 15 &&
          find.byKey(const ValueKey('replay-route-15')).evaluate().isEmpty;
      page++
    ) {
      await tester.tap(find.byKey(const ValueKey('archive-next-routes')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('replay-route-15')));
    expect(replayed, [15]);
    expect(tester.takeException(), isNull);
  });
}
