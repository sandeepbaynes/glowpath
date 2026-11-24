import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_settings.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final viewport in [
    const Size(320, 568),
    const Size(375, 667),
    const Size(393, 852),
    const Size(844, 390),
    const Size(1024, 1366),
    const Size(1366, 1024),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'every settings page fits $viewport at ${scale}x without scroll or font clamping',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final game = (await tester.runAsync(() async {
            final value = GameController(
              preferences: await SharedPreferences.getInstance(),
              snapshotWriter: (_) async => true,
            );
            await value.load();
            return value;
          }))!;
          addTearDown(game.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: gameTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: viewport,
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: OrbitPanelFrame(
                    title: 'FLIGHT CONTROLS',
                    fit: true,
                    onClose: () {},
                    child: FlightSettings(
                      game: game,
                      demo: true,
                      onRestart: () {},
                      onSupport: () {},
                      onLeague: () {},
                      onRewards: () {},
                      onLicenses: () {},
                      onPrivacyPolicy: () {},
                      onHelpSite: () {},
                      onAdPrivacy: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          void check(String stage) {
            expect(tester.takeException(), isNull, reason: stage);
            expect(
              find.descendant(
                of: find.byType(FlightSettings),
                matching: find.byType(Scrollable),
              ),
              findsNothing,
            );
            final area = tester.getRect(find.byType(FlightSettings));
            for (final element
                in find
                    .descendant(
                      of: find.byType(FlightSettings),
                      matching: find.byType(Text),
                    )
                    .evaluate()) {
              expect(
                MediaQuery.textScalerOf(element).scale(16),
                16 * scale,
                reason: '$stage keeps the requested text scale',
              );
              final render = element.renderObject;
              if (render is RenderBox && render.hasSize) {
                final rect = render.localToGlobal(Offset.zero) & render.size;
                expect(
                  rect.top,
                  greaterThanOrEqualTo(area.top - 1),
                  reason: stage,
                );
                expect(
                  rect.bottom,
                  lessThanOrEqualTo(area.bottom + 1),
                  reason: stage,
                );
              }
            }
            for (final key in [
              'settings-next',
              'settings-previous',
              'close-sheet',
            ]) {
              final target = find.byKey(ValueKey(key));
              if (target.evaluate().isEmpty) continue;
              final rect = tester.getRect(target);
              expect(
                rect.height,
                greaterThanOrEqualTo(48),
                reason: '$stage $key',
              );
              expect(
                rect.width,
                greaterThanOrEqualTo(48),
                reason: '$stage $key',
              );
              expect(
                rect.bottom,
                lessThanOrEqualTo(viewport.height),
                reason: '$stage $key',
              );
            }
          }

          for (var section = 0; section < 3; section++) {
            await tester.tap(find.byKey(ValueKey('settings-section-$section')));
            await tester.pump(const Duration(milliseconds: 16));
            check('section $section transition');
            await tester.pumpAndSettle();
            check('section $section first page');
            final pageText = find.byKey(const ValueKey('settings-page'));
            final count = pageText.evaluate().isEmpty
                ? 1
                : int.parse(
                    (tester.widget<Text>(pageText).data!).split(' / ').last,
                  );
            for (var page = 1; page < count; page++) {
              await tester.tap(find.byKey(const ValueKey('settings-next')));
              await tester.pump(const Duration(milliseconds: 16));
              check('section $section page ${page + 1} transition');
              await tester.pumpAndSettle();
              check('section $section page ${page + 1}');
            }
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
