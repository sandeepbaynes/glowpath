import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/services/fold_posture.dart';
import 'package:glowpath/ui/flight_failure.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cases = [
  (
    label: 'phone',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
    geometry: FoldGeometry(),
    vertical: false,
  ),
  (
    label: 'closed fold vertical rail',
    size: Size(466, 678),
    insets: EdgeInsets.only(right: 84, bottom: 34),
    geometry: FoldGeometry(
      viewport: Size(466, 678),
      supported: true,
      status: HingePosture.closed,
      occlusions: [
        Rect.fromLTWH(399.6666667, 29.3333333, 37, 37),
        Rect.fromLTWH(382, 0, 84, 174),
      ],
    ),
    vertical: true,
  ),
  (
    label: 'partial book',
    size: Size(951, 669),
    insets: EdgeInsets.only(right: 84, bottom: 34),
    geometry: FoldGeometry(
      viewport: Size(951, 669),
      supported: true,
      status: HingePosture.partiallyOpen,
      divisions: [Rect.fromLTWH(455.5, 0, 40, 669)],
      occlusions: [Rect.fromLTWH(827, 585, 124, 84)],
    ),
    vertical: false,
  ),
  (
    // Synthetic compact clamshell geometry exercises the same public contract.
    label: 'partial flip',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 24, bottom: 24),
    geometry: FoldGeometry(
      viewport: Size(393, 852),
      supported: true,
      status: HingePosture.partiallyOpen,
      divisions: [Rect.fromLTWH(0, 426, 393, 0)],
    ),
    vertical: false,
  ),
];

void main() {
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final scenario in _cases) {
    testWidgets('${scenario.label} timeout inherits the last painted craft', (
      tester,
    ) async {
      _configure(tester, scenario.size, scenario.insets);
      SharedPreferences.setMockInitialValues({'journeyLevel': 20});
      final game = GameController(
        preferences: await SharedPreferences.getInstance(),
        now: () => DateTime.utc(2026, 11, 25, 12),
        snapshotWriter: (_) => SynchronousFuture(true),
      );
      await game.load();
      await game.flush();
      addTearDown(game.dispose);
      final geometry = ValueNotifier(scenario.geometry);
      addTearDown(geometry.dispose);
      var now = Duration.zero;
      await tester.pumpWidget(
        GlowpathApp(
          controller: game,
          showBriefings: false,
          ambientMotion: false,
          clockNow: () => now,
          foldGeometry: geometry,
        ),
      );
      await tester.pumpAndSettle();
      expect(_countdown(tester).vertical, scenario.vertical);
      expect(_countdown(tester).hideRocket, isFalse);
      final total = _countdown(tester).total;

      // Finish during an interpolated clock update. The final rendered craft
      // is intentionally short of the rail's end, so a guessed end position
      // cannot satisfy the handoff assertions.
      now = total - const Duration(milliseconds: 1500);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 250));
      now = total - const Duration(milliseconds: 450);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 60));
      final before = _paintedCountdownPose(tester);
      expect(_countdown(tester).remaining, const Duration(milliseconds: 450));
      _expectPose(_countdown(tester).tracker!.capture()!, before);

      now = total + const Duration(milliseconds: 200);
      await tester.pump(const Duration(milliseconds: 200));
      _expectHandoff(tester, before);

      // The still-laid-out countdown now has its terminal geometry. This must
      // differ from the captured craft we just inherited, proving the failure
      // used the pre-rebuild painting rather than the expired timer estimate.
      final terminal = _paintedCountdownPose(tester);
      expect((terminal.position - before.position).distance, greaterThan(.5));
      if (scenario.geometry.status == HingePosture.partiallyOpen) {
        final mission = tester.getRect(
          find.byKey(const ValueKey('failure-mission-pane')),
        );
        expect(mission.contains(before.position), isTrue);
      }

      await tester.pump(FlightFailureOverlay.departureDuration);
      await tester.tap(find.byKey(const ValueKey('retry-flight')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FlightFailureOverlay), findsNothing);
      expect(_countdown(tester).hideRocket, isFalse);
      expect(_countdown(tester).expired, isFalse);
      expect(_countdown(tester).remaining, greaterThan(Duration.zero));
      final restarted = _paintedCountdownPose(tester);
      final recaptured = _countdown(tester).tracker!.capture();
      expect(recaptured, isNotNull);
      _expectPose(recaptured!, restarted);
      expect((restarted.position - before.position).distance, greaterThan(20));
      expect(_countdownPaintIsHidden(tester), isFalse);

      // A second timeout must use the new attempt's position, not the previous
      // failure snapshot retained by the overlay or its tracker.
      now += _countdown(tester).remaining + const Duration(milliseconds: 200);
      await tester.pump(const Duration(milliseconds: 200));
      _expectHandoff(tester, restarted);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

LaunchCountdown _countdown(WidgetTester tester) =>
    tester.widget<LaunchCountdown>(find.byType(LaunchCountdown));

Finder _countdownPainter() => find.descendant(
  of: find.byType(LaunchCountdown),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint && widget.painter is CountdownRocketPainter,
  ),
);

// Measure the actual painted silhouette using the render object's complete
// transform: folded orientation, layout, safe areas and urgency scale.
LaunchFlightOrigin _paintedCountdownPose(WidgetTester tester) {
  final finder = _countdownPainter();
  final render = tester.renderObject<RenderBox>(finder);
  final painter =
      tester.widget<CustomPaint>(finder).painter! as CountdownRocketPainter;
  final local = Offset(render.size.width * 36 / 58, render.size.height / 2);
  final position = render.localToGlobal(local);
  final forward =
      render.localToGlobal(local + Offset(render.size.width / 58, 0)) -
      position;
  return LaunchFlightOrigin(
    position: position,
    angle: math.atan2(forward.dx, -forward.dy),
    length: forward.distance * 13.2 * 2.31,
    heat: painter.heat,
    urgent: painter.urgent,
    trailColor: painter.trailColor,
  );
}

bool _countdownPaintIsHidden(WidgetTester tester) => tester
    .widgetList<Opacity>(
      find.ancestor(of: _countdownPainter(), matching: find.byType(Opacity)),
    )
    .any((opacity) => opacity.opacity == 0);

void _expectHandoff(WidgetTester tester, LaunchFlightOrigin before) {
  final overlay = tester.widget<FlightFailureOverlay>(
    find.byType(FlightFailureOverlay),
  );
  expect(overlay.launchOrigin, isNotNull);
  _expectPose(overlay.launchOrigin!, before);
  expect(_countdown(tester).hideRocket, isTrue);
  expect(_countdownPaintIsHidden(tester), isTrue);
  final scene = find.byKey(const ValueKey('flight-failure-rocket'));
  final render = tester.renderObject<RenderBox>(scene);
  final painter =
      tester.widget<CustomPaint>(scene).painter! as LostRocketPainter;
  final frame = painter.frame(render.size);
  expect(painter.departure.value, 0);
  expect(frame.rocketOpacity, 1);
  expect(
    (render.localToGlobal(frame.rocketPosition) - before.position).distance,
    lessThan(.01),
  );
  expect(frame.rocketLength, closeTo(before.length, .01));
  expect(frame.rocketAngle, closeTo(before.angle, .001));
  expect(
    find.descendant(
      of: find.byType(FlightFailureOverlay),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is LostRocketPainter,
      ),
    ),
    findsOneWidget,
  );
}

void _expectPose(LaunchFlightOrigin actual, LaunchFlightOrigin expected) {
  expect((actual.position - expected.position).distance, lessThan(.01));
  expect(actual.angle, closeTo(expected.angle, .001));
  expect(actual.length, closeTo(expected.length, .01));
  expect(actual.heat, closeTo(expected.heat, .001));
  expect(actual.urgent, expected.urgent);
  expect(actual.trailColor, expected.trailColor);
}

void _configure(WidgetTester tester, Size size, EdgeInsets insets) {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  tester.view.padding = FakeViewPadding(
    left: insets.left * 3,
    top: insets.top * 3,
    right: insets.right * 3,
    bottom: insets.bottom * 3,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
}
