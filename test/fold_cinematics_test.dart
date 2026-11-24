import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/services/fold_posture.dart';
import 'package:glowpath/ui/challenge_result.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_failure.dart';
import 'package:glowpath/ui/fold_layout.dart';
import 'package:glowpath/ui/launch_splash.dart';
import 'package:glowpath/ui/mission_briefing.dart';
import 'package:glowpath/ui/planet_flight.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final entry in [
    (
      name: 'short clamshell',
      size: const Size(393, 852),
      hinge: const Rect.fromLTWH(0, 406, 393, 40),
      padding: const EdgeInsets.only(top: 59, bottom: 34),
    ),
    (
      name: 'book',
      size: const Size(951, 669),
      hinge: const Rect.fromLTWH(455.5, 0, 40, 669),
      padding: const EdgeInsets.only(right: 84, bottom: 34),
    ),
  ]) {
    for (final scale in [1.0, 3.0]) {
      final media = MediaQueryData(
        size: entry.size,
        padding: entry.padding,
        viewPadding: entry.padding,
        textScaler: TextScaler.linear(scale),
      );
      final panes = FoldPaneLayout.resolve(
        media,
        FoldGeometry(
          viewport: entry.size,
          divisions: [entry.hinge],
          status: HingePosture.partiallyOpen,
          supported: true,
        ),
      )!;

      Future<void> show(WidgetTester tester, Widget child) async {
        tester.view.physicalSize = entry.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: MediaQuery(data: media, child: child),
          ),
        );
        await tester.pump();
      }

      void within(WidgetTester tester, String key, Rect pane) {
        final finder = find.byKey(ValueKey(key));
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(pane.left - .01));
        expect(rect.top, greaterThanOrEqualTo(pane.top - .01));
        expect(rect.right, lessThanOrEqualTo(pane.right + .01));
        expect(rect.bottom, lessThanOrEqualTo(pane.bottom + .01));
        expect(rect.overlaps(entry.hinge), isFalse);
      }

      testWidgets(
        '${entry.name} ${scale}x loading separates brand and status',
        (tester) async {
          await show(tester, LaunchSplash(panes: panes));
          within(tester, 'launch-mission-pane', panes.missionRect);
          within(tester, 'launch-status', panes.actionRect);
          expect(find.text('Glowpath'), findsOneWidget);
          expect(find.byType(Scrollable), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${entry.name} ${scale}x result navigation stays in action pane',
        (tester) async {
          var voyage = 0, collection = 0;
          await show(
            tester,
            ChallengeResult(
              panes: panes,
              weekly: false,
              stageCount: 3,
              points: 250,
              activeElapsed: const Duration(seconds: 48),
              cleanStreak: 2,
              medalEarned: true,
              periodDate: '2026-11-24',
              now: () => DateTime.utc(2026, 11, 24, 14),
              onVoyage: () => voyage++,
              onCollection: () => collection++,
              reduceMotion: true,
            ),
          );
          within(tester, 'challenge-result-title', panes.missionRect);
          within(tester, 'challenge-result-score', panes.missionRect);
          for (final key in [
            'challenge-return-voyage',
            'challenge-open-collection',
          ]) {
            within(tester, key, panes.actionRect);
            final action = find.byKey(ValueKey(key));
            expect(action.hitTestable(), findsOneWidget);
            await tester.tap(action);
            await tester.pump();
          }
          expect(voyage, 1);
          expect(collection, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets('${entry.name} ${scale}x loss keeps Retry off the hinge', (
        tester,
      ) async {
        var retries = 0;
        await show(
          tester,
          FlightFailureOverlay(panes: panes, onRetry: () => retries++),
        );
        within(tester, 'flight-failure-rocket', panes.missionRect);
        within(tester, 'flight-failure-recovery', panes.actionRect);
        within(tester, 'retry-flight', panes.actionRect);
        final retry = find.byKey(const ValueKey('retry-flight'));
        final before = tester.getRect(retry);
        expect(retry.hitTestable(), findsNothing);
        await tester.pump(FlightFailureOverlay.retryRevealEnd);
        expect(tester.getRect(retry), before);
        expect(retry.hitTestable(), findsOneWidget);
        await tester.tap(retry);
        expect(retries, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets(
        '${entry.name} ${scale}x reduced loss shows Retry immediately',
        (tester) async {
          await show(
            tester,
            FlightFailureOverlay(
              panes: panes,
              reduceMotion: true,
              onRetry: () {},
            ),
          );
          within(tester, 'flight-failure-rocket', panes.missionRect);
          within(tester, 'retry-flight', panes.actionRect);
          expect(
            find.byKey(const ValueKey('retry-flight')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.binding.hasScheduledFrame, isFalse);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${entry.name} ${scale}x challenge retry has distinct panes',
        (tester) async {
          var retries = 0;
          await show(
            tester,
            ChallengeRetryOverlay(
              panes: panes,
              stage: 2,
              stageCount: 5,
              reduceMotion: true,
              onRetry: () => retries++,
            ),
          );
          within(tester, 'challenge-retry-mission-pane', panes.missionRect);
          within(tester, 'retry-flight', panes.actionRect);
          final retry = find.byKey(const ValueKey('retry-flight'));
          expect(retry.hitTestable(), findsOneWidget);
          await tester.tap(retry);
          expect(retries, 1);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${entry.name} ${scale}x briefing preserves every instruction',
        (tester) async {
          var starts = 0;
          await show(
            tester,
            MissionBriefing(
              panes: panes,
              reduceMotion: true,
              onStart: () => starts++,
            ),
          );
          within(tester, 'briefing-mission-pane', panes.missionRect);
          final chunks = <String>[];
          for (var i = 0; i < 100 && starts == 0; i++) {
            expect(tester.takeException(), isNull);
            within(tester, 'briefing-copy', panes.actionRect);
            within(tester, 'briefing-start', panes.actionRect);
            final copy = find.byKey(const ValueKey('briefing-copy'));
            final paragraph = tester.renderObject<RenderParagraph>(copy);
            expect(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width),
              lessThanOrEqualTo(paragraph.size.height + .01),
            );
            chunks.add(tester.widget<Text>(copy).data!);
            final next = find.byKey(const ValueKey('briefing-start'));
            expect(next.hitTestable(), findsOneWidget);
            await tester.tap(next);
            await tester.pump();
          }
          expect(starts, 1);
          expect(
            chunks.join('').replaceAll(RegExp(r'\s'), ''),
            firstFlightBriefing
                .map((beat) => beat.text)
                .join('')
                .replaceAll(RegExp(r'\s'), ''),
          );
          expect(find.byType(Scrollable), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '${entry.name} ${scale}x transit keeps dialogue in action pane',
        (tester) async {
          var completed = 0;
          await show(
            tester,
            PlanetFlight(
              panes: panes,
              world: VoyageWorld.forLevel(31),
              beats: firstFlightBriefing,
              reduceMotion: true,
              onComplete: () => completed++,
            ),
          );
          within(tester, 'transit-mission-pane', panes.missionRect);
          final chunks = <String>[];
          for (var i = 0; i < 100 && completed == 0; i++) {
            expect(tester.takeException(), isNull);
            within(tester, 'flight-dialogue-copy', panes.actionRect);
            within(tester, 'flight-next', panes.actionRect);
            within(tester, 'flight-previous', panes.actionRect);
            final copy = find.byKey(const ValueKey('flight-dialogue-copy'));
            final paragraph = tester.renderObject<RenderParagraph>(copy);
            expect(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width),
              lessThanOrEqualTo(paragraph.size.height + .01),
            );
            chunks.add(tester.widget<Text>(copy).data!);
            final next = find.byKey(const ValueKey('flight-next'));
            expect(next.hitTestable(), findsOneWidget);
            await tester.tap(next);
            await tester.pump();
          }
          expect(completed, 1);
          expect(
            chunks.join('').replaceAll(RegExp(r'\s'), ''),
            firstFlightBriefing
                .map((beat) => beat.text)
                .join('')
                .replaceAll(RegExp(r'\s'), ''),
          );
          expect(find.byType(Scrollable), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  const cycleMedia = MediaQueryData(
    size: Size(393, 852),
    padding: EdgeInsets.only(top: 59, bottom: 34),
    viewPadding: EdgeInsets.only(top: 59, bottom: 34),
    textScaler: TextScaler.linear(3),
  );
  final cyclePanes = FoldPaneLayout.resolve(
    cycleMedia,
    const FoldGeometry(
      viewport: Size(393, 852),
      divisions: [Rect.fromLTWH(0, 406, 393, 40)],
      status: HingePosture.partiallyOpen,
      supported: true,
    ),
  )!;

  Future<void> cycleShow(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = cycleMedia.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: MediaQuery(data: cycleMedia, child: child),
      ),
    );
    await tester.pump();
  }

  testWidgets('briefing cursor survives changing full-screen host wrappers', (
    tester,
  ) async {
    final key = GlobalKey();
    var starts = 0;
    Future<void> show(bool folded) async {
      final briefing = MissionBriefing(
        key: key,
        panes: folded ? cyclePanes : null,
        reduceMotion: true,
        onStart: () => starts++,
      );
      await cycleShow(
        tester,
        ColoredBox(
          color: Palette.paper,
          child: folded
              ? briefing
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 560,
                          maxHeight: 600,
                        ),
                        child: briefing,
                      ),
                    ),
                  ),
                ),
        ),
      );
    }

    await show(true);
    final first = tester
        .widget<Text>(find.byKey(const ValueKey('briefing-copy')))
        .data;
    await tester.tap(find.byKey(const ValueKey('briefing-start')));
    await tester.pump();
    final current = tester
        .widget<Text>(find.byKey(const ValueKey('briefing-copy')))
        .data;
    expect(current, isNot(first));
    final state = key.currentState;
    await show(false);
    expect(key.currentState, same(state));
    await show(true);
    expect(key.currentState, same(state));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('briefing-copy'))).data,
      current,
    );
    expect(starts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failure continues its existing departure through posture cycles',
    (tester) async {
      Future<void> show(bool folded) => cycleShow(
        tester,
        FlightFailureOverlay(
          key: const ValueKey('failure-cycle'),
          panes: folded ? cyclePanes : null,
          onRetry: () {},
        ),
      );
      LostRocketPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('flight-failure-rocket')),
                  )
                  .painter!
              as LostRocketPainter;

      await show(true);
      await tester.pump(const Duration(milliseconds: 2500));
      final departure = painter().departure;
      final progress = departure.value;
      expect(progress, inExclusiveRange(.4, .5));
      await show(false);
      expect(painter().departure, same(departure));
      expect(departure.value, closeTo(progress, .001));
      await show(true);
      expect(painter().departure, same(departure));
      expect(departure.value, closeTo(progress, .001));
      await tester.pump(const Duration(milliseconds: 3100));
      expect(
        find.byKey(const ValueKey('retry-flight')).hitTestable(),
        findsOneWidget,
      );
      final recovery = tester.getRect(
        find.byKey(const ValueKey('flight-failure-recovery')),
      );
      expect(recovery.overlaps(cyclePanes.gap), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'transit preserves reading and arrival, completing once after folds',
    (tester) async {
      var completed = 0;
      Future<void> show(bool folded) => cycleShow(
        tester,
        PlanetFlight(
          key: const ValueKey('transit-cycle'),
          panes: folded ? cyclePanes : null,
          world: VoyageWorld.forLevel(31),
          beats: firstFlightBriefing,
          onComplete: () => completed++,
        ),
      );
      await show(true);
      await tester.tap(find.byKey(const ValueKey('flight-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final current = tester
          .widget<Text>(find.byKey(const ValueKey('flight-dialogue-copy')))
          .data;
      final state = tester.state(find.byType(PlanetFlight));
      await tester.pump(const Duration(seconds: 2));
      await show(false);
      expect(tester.state(find.byType(PlanetFlight)), same(state));
      await tester.pump(const Duration(seconds: 2));
      await show(true);
      expect(tester.state(find.byType(PlanetFlight)), same(state));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('flight-dialogue-copy')))
            .data,
        current,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.byKey(const ValueKey('skip-planet-flight')), findsNothing);
      expect(completed, 0);
      for (var i = 0; i < 100 && completed == 0; i++) {
        final next = find.byKey(const ValueKey('flight-next'));
        expect(tester.getRect(next).overlaps(cyclePanes.gap), isFalse);
        await tester.tap(next);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(completed, 1);
      await show(false);
      await show(true);
      await tester.tap(find.byKey(const ValueKey('flight-next')));
      await tester.pump();
      expect(completed, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
