import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/voyage_records.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:glowpath/ui/voyage_atlas.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final replay in [false, true]) {
    testWidgets(
      'atlas continuation is a standalone semantic button, replay=$replay',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: VoyageAtlas(
              completedRoutes: 30,
              isReplaying: replay,
              reduceMotion: true,
              onClose: () {},
              onContinue: () {},
              onReplay: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = replay ? 'Resume current route' : 'Continue voyage';
        final node = tester.semantics.find(
          find.byKey(const ValueKey('voyage-atlas-continue')),
        );
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(node.getSemanticsData().label, label);
        expect(
          node,
          isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
        );
        expect(node.rect.height, lessThanOrEqualTo(60));
        expect(node.rect.width, lessThan(600));
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in [
    (size: const Size(320, 568), scale: 3.0),
    (size: const Size(393, 852), scale: 1.0),
    (size: const Size(844, 390), scale: 3.0),
    (size: const Size(740, 360), scale: 3.0),
    (size: const Size(1024, 1366), scale: 1.0),
    (size: const Size(1366, 1024), scale: 3.0),
  ]) {
    testWidgets(
      'atlas fills device and routes fit without scrolling at $entry',
      (tester) async {
        tester.view.physicalSize = entry.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final replayed = <int>[];
        var resumed = false, closed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: entry.size,
                padding: const EdgeInsets.only(top: 24, bottom: 20),
                textScaler: TextScaler.linear(entry.scale),
              ),
              child: VoyageAtlas(
                completedRoutes: 524 * 15,
                frontierLevel: 524 * 15 + 1,
                currentLevel: 1,
                records: const {
                  1: RouteRecord(
                    level: 1,
                    bestScore: 860,
                    bestTime: Duration(milliseconds: 6200),
                  ),
                },
                isReplaying: true,
                reduceMotion: true,
                onClose: () => closed = true,
                onContinue: () => resumed = true,
                onReplay: replayed.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(OrbitSheet), findsNothing);
        expect(find.byType(Scrollable), findsNothing);
        expect(
          tester.getRect(find.byKey(const ValueKey('voyage-atlas-scene'))),
          Offset.zero & entry.size,
        );
        expect(
          tester
              .widget<VoyageExplorer>(find.byType(VoyageExplorer))
              .current
              .planetIndex,
          0,
        );
        await tester.tap(find.byKey(const ValueKey('voyage-current-planet')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<VoyageExplorer>(find.byType(VoyageExplorer))
              .current
              .planetIndex,
          524,
        );
        await tester.tap(find.byKey(const ValueKey('voyage-first-planet')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<VoyageExplorer>(find.byType(VoyageExplorer))
              .current
              .planetIndex,
          0,
        );
        await tester.tap(find.byKey(const ValueKey('voyage-route-log')));
        await tester.pumpAndSettle();
        expect(find.textContaining('860'), findsOneWidget);
        expect(find.textContaining('6.2s'), findsOneWidget);
        final first = find.byKey(const ValueKey('replay-route-1'));
        expect(
          tester.getRect(first).bottom,
          lessThan(
            tester.getRect(find.byKey(const ValueKey('voyage-route-log'))).top,
          ),
        );
        await tester.tap(first);
        expect(replayed, [1]);
        await tester.tap(find.byKey(const ValueKey('voyage-current-planet')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('voyage-next-planet')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('replay-route-7876')));
        expect(replayed, [1]);
        await tester.tap(find.byKey(const ValueKey('voyage-atlas-continue')));
        expect(resumed, isTrue);
        await tester.tap(find.byKey(const ValueKey('voyage-atlas-back')));
        expect(closed, isTrue);
        expect(find.byType(Scrollable), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('full-screen foreground leaves the universe draggable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: VoyageAtlas(
          completedRoutes: 60,
          onClose: () {},
          onContinue: () {},
          onReplay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    VoyageDepthPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('voyage-atlas-scene')),
                )
                .painter!
            as VoyageDepthPainter;
    final gesture = await tester.startGesture(const Offset(195, 330));
    await gesture.moveBy(const Offset(0, 25));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    expect(
      painter().cameraExcursion,
      greaterThan(VoyageDepthPainter.destinationSpacing),
    );
    expect(
      painter().visiblePlanetBounds(const Size(393, 852)).length,
      inInclusiveRange(3, 4),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(painter().cameraExcursion, 0);
    expect(tester.takeException(), isNull);
  });
}
