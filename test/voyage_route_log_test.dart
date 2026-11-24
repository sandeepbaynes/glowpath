import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/voyage_records.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:glowpath/ui/voyage_archive.dart';
import 'package:glowpath/ui/voyage_route_log.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final entry in [
    (size: const Size(320, 568), scale: 3.0),
    (size: const Size(393, 852), scale: 1.0),
    (size: const Size(740, 360), scale: 3.0),
    (size: const Size(1024, 1366), scale: 1.0),
  ]) {
    testWidgets(
      'record-only route log fits and reaches earlier routes at $entry',
      (tester) async {
        tester.view.physicalSize = entry.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 600,
                      maxHeight: entry.size.height * .92,
                    ),
                    child: OrbitSheet(
                      title: 'FLIGHT LOG',
                      fit: true,
                      onClose: () {},
                      child: VoyageRouteLog(
                        frontierLevel: 524 * 15 + 1,
                        currentLevel: 524 * 15 + 1,
                        records: const {
                          1: RouteRecord(
                            level: 1,
                            bestScore: 860,
                            bestTime: Duration(milliseconds: 6200),
                          ),
                        },
                        onReplay: replayed.add,
                        reduceMotion: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(VoyageExplorer), findsNothing);
        expect(find.byType(Scrollable), findsNothing);
        expect(
          tester.widget<VoyageArchive>(find.byType(VoyageArchive)).planetIndex,
          524,
        );
        await tester.tap(find.byKey(const ValueKey('voyage-first-planet')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('replay-route-1')), findsOneWidget);
        final record = tester.semantics.find(
          find.byKey(const ValueKey('replay-route-1')),
        );
        expect(record.getSemanticsData().label, contains('Best score 860'));
        expect(
          record.getSemanticsData().label,
          contains('Best time 6.2 seconds'),
        );
        await tester.tap(find.byKey(const ValueKey('replay-route-1')));
        expect(replayed, [1]);
        await tester.tap(find.byKey(const ValueKey('voyage-next-planet')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<VoyageArchive>(find.byType(VoyageArchive)).planetIndex,
          1,
        );
        await tester.tap(find.byKey(const ValueKey('voyage-previous-planet')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<VoyageArchive>(find.byType(VoyageArchive)).planetIndex,
          0,
        );
        await tester.tap(find.byKey(const ValueKey('voyage-current-planet')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<VoyageArchive>(find.byType(VoyageArchive)).planetIndex,
          524,
        );
        final bounds = tester.getRect(find.byType(VoyageRouteLog));
        for (final key in [
          'voyage-first-planet',
          'voyage-previous-planet',
          'voyage-next-planet',
          'voyage-current-planet',
          'archive-previous-routes',
          'archive-next-routes',
        ]) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(bounds.contains(rect.center), isTrue);
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
