import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_failure.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final size in [
    const Size(740, 320),
    const Size(1194, 834),
    const Size(1366, 1024),
    const Size(1440, 900),
    const Size(1728, 1117),
    const Size(2048, 1009),
  ]) {
    for (final reduced in [false, true]) {
      testWidgets(
        'landscape recovery is centered across the whole screen at $size / reduced $reduced',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: gameTheme(),
              home: FlightFailureOverlay(onRetry: () {}, reduceMotion: reduced),
            ),
          );
          final recovery = find.byKey(
            const ValueKey('flight-failure-recovery'),
          );
          final original = tester.getRect(recovery);
          if (!reduced) {
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            final art = find.byKey(const ValueKey('flight-failure-rocket'));
            final stage = tester.getRect(art);
            final painter =
                tester.widget<CustomPaint>(art).painter! as LostRocketPainter;
            final rocket = stage.topLeft + painter.rocketPosition(stage.size);
            final (routeStart, routeEnd) = painter.intactRoute(stage.size);
            final channelCenter = stage.topLeft + (routeStart + routeEnd) / 2;
            expect(rocket.dx, closeTo(size.width / 2, .01));
            expect(rocket.dy, closeTo(size.height / 2, .01));
            expect(channelCenter.dx, closeTo(size.width / 2, .01));
            expect(channelCenter.dy, closeTo(size.height / 2, .01));
          }
          await tester.pumpAndSettle();
          final bounds = tester.getRect(recovery);
          expect(
            bounds,
            original,
            reason: 'Recovery must fade in without moving.',
          );
          expect(bounds.center.dx, closeTo(size.width / 2, .01));
          expect(bounds.center.dy, closeTo(size.height / 2, .01));
          expect(bounds.width, lessThanOrEqualTo(520));
          expect(
            tester.getRect(find.text('Signal lost')).center.dx,
            closeTo(size.width / 2, .01),
          );
          final retry = find.byKey(const ValueKey('retry-flight'));
          expect(tester.getRect(retry).center.dx, closeTo(size.width / 2, .01));
          expect(retry.hitTestable(), findsOneWidget);
          expect(find.byType(SpaceAction), findsOneWidget);
          expect(find.byType(Scrollable), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'failure owns the screen and reveals Retry after the snap and drift',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var retries = 0, backgroundTouches = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => backgroundTouches++,
                    onPanUpdate: (_) => backgroundTouches++,
                    child: Semantics(
                      button: true,
                      label: 'Underlying control',
                      child: const ColoredBox(color: Palette.board),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: FlightFailureOverlay(onRetry: () => retries++),
                ),
              ],
            ),
          ),
        ),
      );
      final retry = find.byType(SpaceAction);
      final initialBounds = tester.getRect(retry);
      expect(
        tester.getRect(find.byKey(const ValueKey('flight-failure-cover'))),
        const Rect.fromLTWH(0, 0, 800, 600),
      );
      expect(retry.hitTestable(), findsNothing);
      expect(find.bySemanticsLabel('Retry'), findsNothing);
      final tree = tester
          .binding
          .renderViews
          .single
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!
          .toStringDeep();
      expect(
        find.bySemanticsLabel(
          'Signal lost. The route broke and your rocket drifted away. '
          'Your route is saved. Retry appears after the drift.',
        ),
        findsOneWidget,
      );
      expect(tree, isNot(contains('Underlying control')));
      await tester.tapAt(const Offset(10, 10));
      await tester.dragFrom(const Offset(10, 10), const Offset(0, 80));
      expect(backgroundTouches, 0);
      await tester.pump();
      await tester.pump(FlightFailureOverlay.retryRevealStart);
      expect(retry.hitTestable(), findsNothing);
      expect(retries, 0);
      await tester.pump(
        FlightFailureOverlay.retryRevealEnd -
            FlightFailureOverlay.retryRevealStart,
      );
      expect(retry.hitTestable(), findsOneWidget);
      expect(
        tester.semantics.find(retry),
        isSemantics(
          label: 'Retry',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(retry);
      expect(retries, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(retry), initialBounds);
      await tester.pumpAndSettle();
      expect(tester.getRect(retry), initialBounds);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(retries, 2);
      expect(backgroundTouches, 0);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'flight, veer and distant loss paint distinct frames then settle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: RepaintBoundary(
            key: const ValueKey('failure-capture'),
            child: FlightFailureOverlay(onRetry: () {}),
          ),
        ),
      );
      await tester.pump();
      final initial = await _pixels(tester);
      await tester.pump(const Duration(milliseconds: 1600));
      final flying = await _pixels(tester);
      expect(flying, isNot(orderedEquals(initial)));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 1800));
      final veering = await _pixels(tester);
      expect(veering, isNot(orderedEquals(flying)));
      await tester.pump(const Duration(milliseconds: 2300));
      final receding = await _pixels(tester);
      expect(receding, isNot(orderedEquals(veering)));
      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'The flight must not freeze on the earlier oversized tableau.',
      );
      await tester.pump(
        FlightFailureOverlay.departureDuration -
            const Duration(milliseconds: 5700) +
            const Duration(milliseconds: 20),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      final settled = await _pixels(tester);
      expect(settled, isNot(orderedEquals(receding)));
      await tester.pump(const Duration(seconds: 1));
      expect(await _pixels(tester), orderedEquals(settled));
      expect(
        find.byKey(const ValueKey('retry-flight')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final preference in ['in-app', 'system-reduced', 'system-disabled']) {
    testWidgets('$preference skips the departure without hiding Retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              reduceMotion: preference == 'system-reduced',
              disableAnimations: preference == 'system-disabled',
            ),
            child: FlightFailureOverlay(
              onRetry: () {},
              reduceMotion: preference == 'in-app',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('Retry'), findsOneWidget);
      expect(
        find.text('The route broke. Your rocket drifted away.'),
        findsOneWidget,
      );
      final art = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('flight-failure-rocket')),
      );
      final painter = art.painter! as LostRocketPainter;
      final size = tester.getSize(
        find.byKey(const ValueKey('flight-failure-rocket')),
      );
      expect(painter.departure.value, 1);
      expect(
        painter.rocketOpacity(size),
        greaterThanOrEqualTo(.9),
        reason:
            'Reduced motion needs an explanatory static ship, not empty space.',
      );
      expect(painter.rocketLength(size), greaterThanOrEqualTo(48));
      expect(
        tester.getSize(find.byType(SpaceAction)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in [
    (size: const Size(320, 568), padding: EdgeInsets.zero),
    (
      size: const Size(390, 844),
      padding: const EdgeInsets.only(top: 47, bottom: 34),
    ),
    (
      size: const Size(740, 320),
      padding: const EdgeInsets.only(left: 44, right: 44, bottom: 21),
    ),
    (size: const Size(744, 1133), padding: EdgeInsets.zero),
    (
      size: const Size(1024, 1366),
      padding: const EdgeInsets.only(top: 24, bottom: 20),
    ),
    (
      size: const Size(1366, 1024),
      padding: const EdgeInsets.only(top: 24, bottom: 20),
    ),
  ]) {
    testWidgets(
      '3× text needs no scroll and Retry reveals within safe bounds at ${entry.size}',
      (tester) async {
        tester.view.physicalSize = entry.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var retries = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: entry.size,
                padding: entry.padding,
                viewPadding: entry.padding,
                textScaler: const TextScaler.linear(3),
              ),
              child: FlightFailureOverlay(onRetry: () => retries++),
            ),
          ),
        );
        final safeBounds = Rect.fromLTRB(
          entry.padding.left,
          entry.padding.top,
          entry.size.width - entry.padding.right,
          entry.size.height - entry.padding.bottom,
        );
        final retry = find.byKey(const ValueKey('retry-flight'));
        final initial = tester.getRect(retry);
        void verifyVisible() {
          expect(find.byType(Scrollable), findsNothing);
          expect(retry.hitTestable(), findsOneWidget);
          final bounds = tester.getRect(retry);
          expect(
            bounds,
            initial,
            reason: 'The animation must never move Retry.',
          );
          expect(bounds.width, greaterThanOrEqualTo(48));
          expect(bounds.height, greaterThanOrEqualTo(48));
          expect(bounds.left, greaterThanOrEqualTo(safeBounds.left));
          expect(bounds.top, greaterThanOrEqualTo(safeBounds.top));
          expect(bounds.right, lessThanOrEqualTo(safeBounds.right));
          expect(bounds.bottom, lessThanOrEqualTo(safeBounds.bottom));
          expect(tester.takeException(), isNull);
        }

        // No scrolling or ensureVisible call may rescue an off-screen control.
        expect(retry.hitTestable(), findsNothing);
        await tester.pump();
        await tester.pump(FlightFailureOverlay.retryRevealEnd);
        verifyVisible();
        await tester.tap(retry);
        expect(retries, 1);
        await tester.pump(const Duration(milliseconds: 1600));
        verifyVisible();
        await tester.pumpAndSettle();
        verifyVisible();
        await tester.tap(retry);
        expect(retries, 2);
      },
    );
  }

  for (final size in [
    const Size(320, 568),
    const Size(320, 640),
    const Size(375, 667),
    const Size(390, 844),
    const Size(740, 320),
    const Size(744, 1133),
    const Size(834, 1194),
    const Size(1194, 834),
    const Size(1024, 1366),
  ]) {
    testWidgets(
      'readable flight recedes to loss while Retry stays fixed at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var retries = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: gameTheme(),
            home: FlightFailureOverlay(onRetry: () => retries++),
          ),
        );
        final art = find.byKey(const ValueKey('flight-failure-rocket'));
        final artSize = tester.getSize(art);
        final available = Offset.zero & artSize;
        final retry = find.byKey(const ValueKey('retry-flight'));
        final retryBounds = tester.getRect(retry);
        expect(find.byType(Scrollable), findsNothing);
        expect(retryBounds.bottom, lessThanOrEqualTo(size.height));
        expect(retry.hitTestable(), findsNothing);
        expect(retries, 0);
        await tester.pump();
        for (var frame = 0; frame <= 30; frame++) {
          final painter =
              tester.widget<CustomPaint>(art).painter! as LostRocketPainter;
          final rocket = painter.rocketBounds(artSize);
          expect(
            available.contains(rocket.topLeft),
            isTrue,
            reason:
                'Nose/fins leave frame at $frame on $size: $rocket outside $available',
          );
          expect(
            available.contains(rocket.bottomRight),
            isTrue,
            reason:
                'Nose/fins leave frame at $frame on $size: $rocket outside $available',
          );
          if (frame <= 9) {
            expect(
              painter.rocketLength(artSize),
              greaterThanOrEqualTo(size.shortestSide >= 600 ? 64 : 48),
              reason:
                  'The first two seconds must show a readable flying craft.',
            );
            expect(painter.rocketOpacity(artSize), greaterThanOrEqualTo(.9));
          }
          if (frame == 30) {
            expect(
              painter.rocketOpacity(artSize),
              0,
              reason: 'The ship must actually disappear into deep space.',
            );
            expect(painter.rocketLength(artSize), lessThanOrEqualTo(12));
          }
          expect(tester.getRect(retry), retryBounds);
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('an intact straight route snaps without stopping the craft, then both pieces drift', () {
    const size = Size(342, 280);
    FlightFailureFrame at(int milliseconds) => FlightFailureFrame.at(
      milliseconds / FlightFailureOverlay.departureDuration.inMilliseconds,
      size,
    );
    final a = at(500), b = at(1000), c = at(1500);
    final first = b.rocketPosition - a.rocketPosition;
    final second = c.rocketPosition - b.rocketPosition;
    expect(
      (first - second).distance,
      lessThan(.01),
      reason: 'Straight flight has steady speed.',
    );
    expect(first.distance, greaterThan(15));
    expect(at(1999).routeBroken, isFalse);
    expect(at(2000).routeBroken, isTrue);
    expect(at(1999).routeBeforeOffset, Offset.zero);
    expect(at(1999).routeAfterOffset, Offset.zero);
    expect(
      (at(2001).rocketVelocity - at(1999).rocketVelocity).distance,
      lessThan(.2),
      reason: 'The snap cannot stop or teleport the rocket.',
    );
    for (var time = 1900; time <= 3000; time += 50) {
      expect(at(time).rocketVelocity.distance, greaterThan(25));
    }
    final guided = at(1500).rocketVelocity;
    final thrown = at(3500).rocketVelocity;
    final offAxis =
        (guided.dx * thrown.dy - guided.dy * thrown.dx).abs() /
        (guided.distance * thrown.distance);
    expect(offAxis, greaterThan(.2));
    expect(at(3500).routeBeforeOffset.distance, greaterThan(10));
    expect(at(3500).routeAfterOffset.distance, greaterThan(10));
    expect(at(5000).routeScale, lessThan(at(3000).routeScale));
    expect(at(5800).routeOpacity, lessThan(at(3500).routeOpacity));
    expect(at(5800).rocketLength, lessThan(at(3500).rocketLength * .2));
    expect(at(6000).rocketOpacity, 0);
    expect(at(6000).routeOpacity, 0);
    expect(at(4800).retryOpacity, 0);
    expect(at(5100).retryOpacity, inExclusiveRange(0, 1));
    expect(at(5500).retryOpacity, 1);
  });

  for (final size in [
    const Size(1080, 440),
    const Size(652, 299),
    const Size(480, 400),
    const Size(342, 280),
    const Size(280, 64),
  ]) {
    test(
      'guided channel, midpoint and nose fracture stay coherent at $size',
      () {
        final painter = LostRocketPainter(const AlwaysStoppedAnimation(1 / 6));
        final (start, end) = painter.intactRoute(size);
        final center = size.center(Offset.zero);
        expect(((start + end) / 2 - center).distance, lessThan(.01));
        expect((painter.rocketPosition(size) - center).distance, lessThan(.01));
        final snap = FlightFailureFrame.at(1 / 3, size);
        final direction = snap.rocketVelocity / snap.rocketVelocity.distance;
        final nose = snap.rocketPosition + direction * snap.rocketLength * .55;
        expect((painter.fracturePoint(size) - nose).distance, lessThan(.01));
        expect((Offset.zero & size).contains(start), isTrue);
        expect((Offset.zero & size).contains(end), isTrue);
        expect((Offset.zero & size).contains(nose), isTrue);
        final still = LostRocketPainter(
          const AlwaysStoppedAnimation(1),
          reducedMotion: true,
        ).rocketBounds(size);
        expect((Offset.zero & size).contains(still.topLeft), isTrue);
        expect((Offset.zero & size).contains(still.bottomRight), isTrue);
      },
    );
  }
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('failure-capture')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}
