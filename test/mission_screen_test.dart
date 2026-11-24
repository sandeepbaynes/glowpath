import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/mission_controller.dart';
import 'package:glowpath/ui/cockpit_flight.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_controls.dart';
import 'package:glowpath/ui/mission_board.dart';
import 'package:glowpath/ui/mission_screen.dart';
import 'package:glowpath/ui/reactive_sky.dart';
import 'package:glowpath/ui/rocket_effects.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Atkinson')..addFont(
          rootBundle.load(
            'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
          ),
        ))
        .load();
  });

  _missionTest('only Begin arms the countdown; Hold preserves active time', (
    tester,
    fixture,
  ) async {
    final limit = fixture.game.mission.timeLimitSeconds;
    await fixture.elapse(tester, const Duration(minutes: 4));
    expect(fixture.game.flightResult, isNull);
    expect(_clock(tester).readout, '$limit');
    await _tap(tester, 'arm-mission');
    await fixture.elapse(tester, const Duration(seconds: 7));
    expect(_clock(tester).readout, '${limit - 7}');
    await _tap(tester, 'flight-pause');
    expect(_control(tester, 'launch-mission').onTap, isNull);
    expect(
      tester.widget<MissionBoard>(find.byType(MissionBoard)).enabled,
      isFalse,
    );
    await fixture.elapse(tester, const Duration(minutes: 3));
    expect(_clock(tester).readout, '${limit - 7}');
    expect(fixture.game.flightResult, isNull);
    await _tap(tester, 'flight-pause');
    await fixture.elapse(tester, const Duration(seconds: 3));
    expect(_clock(tester).readout, '${limit - 10}');
  });

  _missionTest('settings and app background do not consume launch time', (
    tester,
    fixture,
  ) async {
    await _tap(tester, 'arm-mission');
    await fixture.elapse(tester, const Duration(seconds: 6));
    final remaining = _clock(tester).readout;
    await _tap(tester, 'flight-settings');
    await tester.pump(const Duration(milliseconds: 250));
    await fixture.elapse(tester, const Duration(minutes: 8));
    expect(fixture.game.flightResult, isNull);
    await _tap(tester, 'close-flight-panel');
    await tester.pump(const Duration(milliseconds: 250));
    expect(_clock(tester).readout, remaining);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await fixture.elapse(tester, const Duration(minutes: 8));
    expect(fixture.game.flightResult, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_clock(tester).readout, remaining);
    await fixture.elapse(tester, const Duration(seconds: 2));
    expect(_clock(tester).readout, '${int.parse(remaining) - 2}');
  });

  _missionTest(
    'deadline launches the built route and explains its actual failure',
    (tester, fixture) async {
      final expected = fixture.game.mission.launch(
        attempt: fixture.game.attempt,
      );
      expect(expected.success, isFalse);
      final rotations = fixture.game.rotations;
      await _tap(tester, 'arm-mission');
      await fixture.elapse(
        tester,
        Duration(seconds: fixture.game.mission.timeLimitSeconds),
      );
      expect(find.byType(RocketLaunchScene), findsOneWidget);
      expect(find.byType(MissionBoard), findsNothing);
      final result = fixture.game.flightResult!;
      expect(result.failure, expected.failure);
      expect(result.failureCell, expected.failureCell);
      expect(fixture.game.rotations, rotations);
      await _completeIgnition(tester);
      final cockpit = tester.widget<CockpitFlight>(find.byType(CockpitFlight));
      expect(cockpit.result, same(result));
      expect(
        cockpit.mission.cells.map((cell) => cell.rotation).toList(),
        rotations,
      );
      await tester.pump(const Duration(milliseconds: 400));
      final progressing = tester.widget<CockpitFlight>(
        find.byType(CockpitFlight),
      );
      expect(progressing.progress, greaterThan(0));
      expect(progressing.progress, lessThan(1));
      await _tap(tester, 'skip-flight');
      expect(find.text(result.message), findsOneWidget);
      final board = tester.widget<MissionBoard>(find.byType(MissionBoard));
      expect(board.result, same(result));
      expect(board.showFailure, isTrue);
      expect(board.enabled, isFalse);
      final attempt = fixture.game.attempt;
      await _tap(tester, 'debrief-action');
      expect(fixture.game.flightResult, isNull);
      expect(fixture.game.rotations, rotations);
      expect(fixture.game.attempt, attempt + 1);
      expect(
        tester.widget<MissionBoard>(find.byType(MissionBoard)).enabled,
        isTrue,
      );
      expect(
        _clock(tester).readout,
        '${fixture.game.mission.timeLimitSeconds}',
      );
    },
  );

  _missionTest(
    'a completed route earns progress on launch; map travels and replays',
    (tester, fixture) async {
      await _tap(tester, 'arm-mission');
      await _tap(tester, 'mission-cell-10');
      expect(fixture.game.mission.launch(ignoreRisk: true).success, isTrue);
      expect(fixture.game.completedLevels, isEmpty);
      expect(fixture.game.highestUnlocked, 1);
      await _tap(tester, 'launch-mission');
      expect(find.byType(RocketLaunchScene), findsOneWidget);
      expect(fixture.game.flightResult!.success, isTrue);
      expect(fixture.game.completedLevels, {1});
      expect(fixture.game.stars, 3);
      await _tap(tester, 'skip-flight');
      expect(find.text('MISSION COMPLETE'), findsOneWidget);
      await _tap(tester, 'debrief-action');
      expect(find.byType(GalaxyRouteMap), findsOneWidget);
      await _tap(tester, 'galaxy-level-2');
      expect(fixture.game.currentLevel, 2);
      expect(find.byType(MissionBoard), findsNothing);
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump();
      expect(find.byKey(const ValueKey('arm-mission')), findsOneWidget);
      expect(find.text(fixture.game.mission.title), findsOneWidget);
      await _tap(tester, 'flight-map');
      await _tap(tester, 'galaxy-level-1');
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump();
      await _tap(tester, 'arm-mission');
      await _tap(tester, 'mission-cell-10');
      await _tap(tester, 'launch-mission');
      expect(fixture.game.flightResult!.success, isTrue);
      expect(
        fixture.game.stars,
        3,
        reason: 'Replaying must not duplicate earned stars.',
      );
    },
    level: 1,
  );

  _missionTest(
    'returning from Atlas preserves the plan and remaining countdown',
    (tester, fixture) async {
      await _tap(tester, 'arm-mission');
      await _tap(tester, 'mission-cell-7');
      await fixture.elapse(tester, const Duration(seconds: 9));
      final before = fixture.game.rotations;
      final remaining = _clock(tester).readout;
      await _tap(tester, 'flight-map');
      await fixture.elapse(tester, const Duration(minutes: 5));
      final back = find.byWidgetPredicate(
        (widget) => widget is FlightControl && widget.label == 'Back',
      );
      await _tapFinder(tester, back);
      expect(fixture.game.rotations, before);
      expect(fixture.game.moves, 1);
      expect(find.byKey(const ValueKey('launch-mission')), findsOneWidget);
      expect(_clock(tester).readout, remaining);
      await fixture.elapse(tester, const Duration(seconds: 1));
      expect(_clock(tester).readout, '${int.parse(remaining) - 1}');
    },
  );

  _missionTest(
    'guidance reveals first and inspector pauses fixed relay briefing',
    (tester, fixture) async {
      await _tap(tester, 'arm-mission');
      final before = fixture.game.rotations;
      final candidate = fixture.game.suggestedHintIndex;
      await _tap(tester, 'flight-hint');
      expect(fixture.game.assisted, isTrue);
      expect(fixture.game.moves, 0);
      expect(fixture.game.rotations, before);
      expect(
        tester.widget<MissionBoard>(find.byType(MissionBoard)).hintIndex,
        candidate,
      );
      await _tap(tester, 'flight-hint');
      expect(fixture.game.moves, greaterThan(0));
      expect(
        tester.widget<MissionBoard>(find.byType(MissionBoard)).hintIndex,
        isNull,
      );
      final turns = fixture.game.moves;
      final remaining = _clock(tester).readout;
      await _tap(tester, 'mission-cell-11');
      await tester.pump(const Duration(milliseconds: 250));
      await fixture.elapse(tester, const Duration(minutes: 4));
      expect(fixture.game.moves, turns);
      expect(fixture.game.flightResult, isNull);
      await _tap(tester, 'close-flight-panel');
      await tester.pump(const Duration(milliseconds: 250));
      expect(_clock(tester).readout, remaining);
    },
    level: 5,
  );

  for (final flag in ['reduceMotion', 'disableAnimations']) {
    _missionTest(
      'untimed planning and OS $flag keep rules playable without optic flow',
      (tester, fixture) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(
              reduceMotion: flag == 'reduceMotion',
              disableAnimations: flag == 'disableAnimations',
            );
        await tester.pump();
        expect(
          tester.widget<ReactiveSky>(find.byType(ReactiveSky)).reduceMotion,
          isTrue,
        );
        await _tap(tester, 'arm-mission');
        await fixture.elapse(tester, const Duration(hours: 1));
        expect(_clock(tester).label, 'Free flight');
        expect(fixture.game.flightResult, isNull);
        for (
          var i = 0;
          i < 25 && fixture.game.suggestedHintIndex != null;
          i++
        ) {
          expect(fixture.game.hint(), isTrue);
        }
        await tester.pump();
        await _tap(tester, 'launch-mission');
        expect(fixture.game.flightResult!.success, isTrue);
        expect(
          tester
              .widget<RocketLaunchScene>(find.byType(RocketLaunchScene))
              .reducedMotion,
          isTrue,
        );
        await _completeIgnition(tester);
        expect(
          tester
              .widget<CockpitFlight>(find.byType(CockpitFlight))
              .reducedMotion,
          isTrue,
        );
        await _tap(tester, 'skip-flight');
        expect(find.text('MISSION COMPLETE'), findsOneWidget);
      },
      untimed: true,
    );
  }

  _missionTest('a restored launched round opens its debrief and allows retry', (
    tester,
    fixture,
  ) async {
    expect(find.text(fixture.game.flightResult!.message), findsOneWidget);
    expect(find.byKey(const ValueKey('arm-mission')), findsNothing);
    expect(
      tester.widget<MissionBoard>(find.byType(MissionBoard)).enabled,
      isFalse,
    );
    await _tap(tester, 'debrief-action');
    expect(fixture.game.canEdit, isTrue);
    expect(fixture.game.flightResult, isNull);
    await _tap(tester, 'mission-cell-7');
    expect(fixture.game.moves, 1);
  }, launchedBeforeMount: true);

  const cases = <(Size, double)>[
    (Size(320, 568), 1),
    (Size(320, 568), 3),
    (Size(844, 390), 2),
    (Size(1280, 900), 3),
  ];
  for (final (viewport, scale) in cases) {
    _missionTest(
      '$viewport at ${scale}x keeps mission controls reachable',
      (tester, fixture) async {
        final semantics = tester.ensureSemantics();
        try {
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 25; i++) {
            final rect = tester.getRect(
              find.byKey(ValueKey('mission-cell-$i')),
            );
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
          }
          await _tap(tester, 'arm-mission');
          await _reveal(tester, find.byKey(const ValueKey('launch-mission')));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await _tap(tester, 'flight-settings');
          await tester.pump(const Duration(milliseconds: 250));
          await _reveal(
            tester,
            find.byKey(const ValueKey('option-Untimed planning')),
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await _tap(tester, 'close-flight-panel');
          await tester.pump(const Duration(milliseconds: 250));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      viewport: viewport,
      scale: scale,
    );
  }
}

void _missionTest(
  String description,
  Future<void> Function(WidgetTester, _MissionFixture) body, {
  int level = 2,
  bool untimed = false,
  bool launchedBeforeMount = false,
  Size viewport = const Size(390, 844),
  double scale = 1,
}) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final fixture = _MissionFixture();
    SharedPreferences.setMockInitialValues({
      MissionController.storageKey: jsonEncode({
        'schemaVersion': 1,
        'campaignVersion': 1,
        'completed': [for (var i = 1; i < level; i++) i],
      }),
      'glowpath.flight.untimed': untimed,
      'glowpath.flight.haptics': false,
    });
    fixture.game = (await tester.runAsync(() async {
      final game = MissionController(
        preferences: await SharedPreferences.getInstance(),
        now: () => fixture.now,
        snapshotWriter: (_) async => true,
      );
      await game.load();
      await game.flush();
      if (launchedBeforeMount) game.launch();
      return game;
    }))!;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: MissionScreen(
            controller: fixture.game,
            now: () => fixture.now,
            motionEnabled: false,
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await body(tester, fixture);
      expect(tester.takeException(), isNull);
    } finally {
      // The screen owns a periodic clock; cancel it before Flutter verifies timers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // UI mutations enqueue saves in fake async, while initial load uses the
      // real zone. Awaiting flush inside runAsync would suspend the fake queue
      // it needs. Pump both queues with a bounded completion check instead.
      var flushed = false;
      unawaited(
        fixture.game.flush().then<void>((_) {
          flushed = true;
        }),
      );
      for (var turn = 0; turn < 20 && !flushed; turn++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(
        flushed,
        isTrue,
        reason: 'The mission save queue must finish during teardown.',
      );
      fixture.game.dispose();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });
}

class _MissionFixture {
  late MissionController game;
  DateTime now = DateTime.utc(2026, 11, 22, 12);

  Future<void> elapse(WidgetTester tester, Duration duration) async {
    now = now.add(duration);
    // One delayed redraw must consume actual elapsed time, not one nominal tick.
    await tester.pump(const Duration(milliseconds: 250));
  }
}

OrbitClock _clock(WidgetTester tester) =>
    tester.widget<OrbitClock>(find.byKey(const ValueKey('launch-clock')));

Future<void> _completeIgnition(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  // Flutter's interpolation simulation completes when elapsed > duration. At
  // exactly 5s the final ignition pose remains, including with OS motion flags.
  expect(find.byType(RocketLaunchScene), findsOneWidget);
  expect(find.byType(CockpitFlight), findsNothing);
  expect(
    tester
        .widget<RocketLaunchScene>(find.byType(RocketLaunchScene))
        .launchProgress,
    closeTo(1, .00001),
  );
  await tester.pump(const Duration(milliseconds: 16));
  expect(find.byType(RocketLaunchScene), findsNothing);
  expect(find.byType(CockpitFlight), findsOneWidget);
}

FlightControl _control(WidgetTester tester, String key) =>
    tester.widget<FlightControl>(find.byKey(ValueKey(key)));

Future<void> _tap(WidgetTester tester, String key) =>
    _tapFinder(tester, find.byKey(ValueKey(key)));

Future<void> _tapFinder(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pump();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget);
}
