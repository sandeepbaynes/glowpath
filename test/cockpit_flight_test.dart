import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/mission.dart';
import 'package:glowpath/ui/cockpit_flight.dart';
import 'package:glowpath/ui/design.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Atkinson')..addFont(
          rootBundle.load(
            'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
          ),
        ))
        .load();
  });

  testWidgets('successful trace announces collected stars and docking', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final mission = Mission.campaign(3).solvedCopy();
      final result = mission.launch();
      expect(result.success, isTrue);
      await _show(tester, mission, result, 0);
      expect(
        find.bySemanticsLabel(
          'Cockpit. Following the planned route. 0 of 3 stars collected.',
        ),
        findsOneWidget,
      );
      await _show(tester, mission, result, .9);
      expect(
        find.bySemanticsLabel('Cockpit. Docking. 3 of 3 stars collected.'),
        findsOneWidget,
      );
      await _show(tester, mission, result, 1);
      expect(
        find.bySemanticsLabel('Cockpit. Docked. 3 of 3 stars collected.'),
        findsOneWidget,
      );
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('empty and dead-end failed traces reach the exterior safely', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final mission = Mission.campaign(1);
      for (final steps in <List<FlightStep>>[
        [],
        [FlightStep(cellIndex: mission.startRow * 5, incoming: 8)],
      ]) {
        final result = FlightResult(
          success: false,
          steps: steps,
          collectedStars: {},
          failure: FlightFailure.brokenConnection,
          failureCell: mission.startRow * 5,
        );
        for (final progress in [0.0, .5, .82, .94, 1.0]) {
          await _show(tester, mission, result, progress);
          expect(tester.takeException(), isNull);
        }
        expect(
          find.bySemanticsLabel(
            'Cockpit. Rocket lost in space. 0 of 3 stars collected.',
          ),
          findsOneWidget,
        );
      }
    } finally {
      handle.dispose();
    }
  });

  for (final mode in [
    'flight',
    'app reduced',
    'system reduced',
    'disabled animations',
  ]) {
    testWidgets('$mode: camera movement respects the motion preference', (
      tester,
    ) async {
      final mission = Mission.campaign(3).solvedCopy();
      final result = mission.launch();
      // Compare two positions between the same waypoints: HUD counts and
      // collected-star state stay unchanged, isolating forward camera motion.
      final firstProgress = .8 * 2.2 / (result.steps.length + 1);
      final nextProgress = .8 * 2.3 / (result.steps.length + 1);
      Future<Uint8List> frame(double progress) async {
        await _show(
          tester,
          mission,
          result,
          progress,
          reduced: mode == 'app reduced',
          systemReduced: mode == 'system reduced',
          disableAnimations: mode == 'disabled animations',
        );
        return _pixels(tester);
      }

      final first = await frame(firstProgress);
      final second = await frame(nextProgress);
      expect(
        second,
        mode == 'flight' ? isNot(orderedEquals(first)) : orderedEquals(first),
      );
      await tester.pump(const Duration(seconds: 20));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'actual campaign wormholes and edge wraps render across their jump',
    (tester) async {
      final seen = <FlightTransition>{};
      for (var number = 1; number <= Mission.campaignCount; number++) {
        final mission = Mission.campaign(number).solvedCopy();
        final result = mission.launch();
        final index = result.steps.indexWhere(
          (step) =>
              (step.transition == FlightTransition.wormhole ||
                  step.transition == FlightTransition.wrap) &&
              !seen.contains(step.transition),
        );
        if (index < 0) continue;
        seen.add(result.steps[index].transition);
        for (final fraction in [.35, .5, .65]) {
          final progress =
              .8 * (index + 1 + fraction) / (result.steps.length + 1);
          await _show(tester, mission, result, progress);
          expect(tester.takeException(), isNull);
        }
      }
      expect(
        seen,
        containsAll([FlightTransition.wormhole, FlightTransition.wrap]),
      );
    },
  );
}

Future<void> _show(
  WidgetTester tester,
  Mission mission,
  FlightResult result,
  double progress, {
  bool reduced = false,
  bool systemReduced = false,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: gameTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 568),
          reduceMotion: systemReduced,
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('cockpit-capture'),
              child: SizedBox(
                width: 320,
                height: 300,
                child: CockpitFlight(
                  mission: mission,
                  result: result,
                  progress: progress,
                  reducedMotion: reduced,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('cockpit-capture')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }))!;
}
