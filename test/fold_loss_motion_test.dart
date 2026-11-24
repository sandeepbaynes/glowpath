import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/services/fold_posture.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_failure.dart';
import 'package:glowpath/ui/fold_layout.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    for (final font in {
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final entry in [
    (
      name: 'flip',
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
    final media = MediaQueryData(
      size: entry.size,
      padding: entry.padding,
      viewPadding: entry.padding,
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

    Future<void> show(
      WidgetTester tester, {
      bool folded = true,
      bool reduced = false,
      bool tickerEnabled = true,
      VoidCallback? onRetry,
    }) async {
      tester.view.physicalSize = entry.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: MediaQuery(
            data: media,
            child: Scaffold(
              body: RepaintBoundary(
                key: const ValueKey('fold-loss-capture'),
                child: TickerMode(
                  enabled: tickerEnabled,
                  child: FlightFailureOverlay(
                    key: const ValueKey('fold-loss'),
                    panes: folded ? panes : null,
                    reduceMotion: reduced,
                    onRetry: onRetry ?? () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    LostRocketPainter painter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('flight-failure-rocket')),
                )
                .painter!
            as LostRocketPainter;

    testWidgets(
      '${entry.name} folded loss remains visible and moving at 6, 12, 60s',
      (tester) async {
        var retries = 0;
        await show(tester, onRetry: () => retries++);
        final art = find.byKey(const ValueKey('flight-failure-rocket'));
        final size = tester.getSize(art);
        final retry = find.byKey(const ValueKey('retry-flight'));
        final retryBounds = tester.getRect(retry);
        await tester.pump(const Duration(milliseconds: 4800));
        expect(retry.hitTestable(), findsNothing);
        await tester.pump(const Duration(milliseconds: 700));
        expect(retry.hitTestable(), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));

        FlightFailureFrame verifyScene() {
          final scene = painter(tester);
          final frame = scene.frame(size);
          final rocket = scene.rocketBounds(size);
          expect(frame.rocketOpacity, greaterThan(.6));
          expect(frame.rocketLength, greaterThan(25));
          expect(frame.routeOpacity, greaterThan(.5));
          expect(frame.routeBroken, isTrue);
          expect((Offset.zero & size).contains(rocket.topLeft), isTrue);
          expect((Offset.zero & size).contains(rocket.bottomRight), isTrue);
          expect(tester.getRect(retry), retryBounds);
          expect(retryBounds.overlaps(entry.hinge), isFalse);
          expect(retry.hitTestable(), findsOneWidget);
          expect(tester.binding.hasScheduledFrame, isTrue);
          expect(tester.takeException(), isNull);
          return frame;
        }

        final at6 = verifyScene();
        await _capture(tester, '${entry.name}-6s');
        await tester.pump(const Duration(seconds: 6));
        final at12 = verifyScene();
        expect(
          (at12.rocketPosition - at6.rocketPosition).distance,
          greaterThan(.1),
        );
        await tester.pump(const Duration(seconds: 8));
        verifyScene();
        await _capture(tester, '${entry.name}-20s');
        await tester.pump(const Duration(seconds: 40));
        final at60 = verifyScene();
        expect(
          (at60.rocketPosition - at12.rocketPosition).distance,
          greaterThan(.1),
        );
        expect(
          at60.routeBeforeRotation,
          isNot(closeTo(at12.routeBeforeRotation, .001)),
        );
        await tester.tap(retry);
        expect(retries, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets(
      '${entry.name} folded loss pauses without accumulating hidden time',
      (tester) async {
        addTearDown(
          () => tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          ),
        );
        await show(tester);
        await tester.pump(const Duration(seconds: 1));
        final departure = painter(tester).departure;
        final earlyProgress = departure.value;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump(const Duration(seconds: 20));
        expect(departure.value, earlyProgress);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 11));
        final clock = painter(tester).driftClock!;
        final elapsed = clock.value;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump(const Duration(seconds: 60));
        expect(clock.value, elapsed);
        expect(tester.binding.hasScheduledFrame, isFalse);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(clock.value, closeTo(elapsed + 1, .001));
        final resumed = clock.value;
        await show(tester, tickerEnabled: false);
        await tester.pump(const Duration(seconds: 30));
        expect(clock.value, resumed);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await show(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(clock.value, closeTo(resumed + 1, .001));
        final beforeFlat = clock.value;
        await show(tester, folded: false);
        await tester.pump(const Duration(seconds: 30));
        expect(clock.value, beforeFlat);
        expect(
          painter(tester).rocketOpacity(
            tester.getSize(find.byKey(const ValueKey('flight-failure-rocket'))),
          ),
          0,
        );
        await show(tester);
        expect(painter(tester).driftClock, same(clock));
        expect(clock.value, beforeFlat);
        expect(
          painter(tester)
              .frame(
                tester.getSize(
                  find.byKey(const ValueKey('flight-failure-rocket')),
                ),
              )
              .phase,
          FailurePhase.lost,
        );
        expect(
          find.byKey(const ValueKey('retry-flight')).hitTestable(),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${entry.name} completed flat flight folds into its existing lost phase',
      (tester) async {
        await show(tester, folded: false);
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        await show(tester);
        final scene = painter(tester);
        final size = tester.getSize(
          find.byKey(const ValueKey('flight-failure-rocket')),
        );
        expect(scene.driftClock!.value, greaterThanOrEqualTo(6));
        expect(scene.frame(size).phase, FailurePhase.lost);
        expect(scene.frame(size).routeBroken, isTrue);
        expect(scene.rocketOpacity(size), greaterThan(.6));
        expect(
          find.byKey(const ValueKey('retry-flight')).hitTestable(),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${entry.name} reduced loss remains a static visible scene', (
      tester,
    ) async {
      await show(tester, reduced: true);
      final scene = painter(tester);
      final size = tester.getSize(
        find.byKey(const ValueKey('flight-failure-rocket')),
      );
      final initial = scene.frame(size);
      await tester.pump(const Duration(seconds: 60));
      expect(scene.frame(size).rocketPosition, initial.rocketPosition);
      expect(scene.rocketOpacity(size), greaterThan(.9));
      expect(scene.frame(size).routeOpacity, greaterThan(.8));
      expect(scene.driftClock!.value, 0);
      expect(
        find.byKey(const ValueKey('retry-flight')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await show(tester, reduced: false);
      expect(painter(tester).departure.value, 1);
      expect(painter(tester).driftClock!.value, greaterThanOrEqualTo(6));
      expect(
        find.byKey(const ValueKey('retry-flight')).hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('folded flight has no pose or visibility discontinuity at the six-second boundary', () {
    const size = Size(357, 303);
    FlightFailureFrame frame(double seconds) => FlightFailureFrame.at(
      seconds / 6,
      size,
      persistentDrift: true,
      elapsedSeconds: seconds,
    );
    final before = frame(5.999), after = frame(6.001);
    expect(
      (after.rocketPosition - before.rocketPosition).distance,
      lessThan(.1),
    );
    expect(after.rocketLength, closeTo(before.rocketLength, .1));
    expect(after.rocketOpacity, closeTo(before.rocketOpacity, .01));
    expect(after.routeOpacity, closeTo(before.routeOpacity, .01));
    expect(
      (after.routeBeforeOffset - before.routeBeforeOffset).distance,
      lessThan(.1),
    );
    expect(
      (frame(2.001).rocketVelocity - frame(1.999).rocketVelocity).distance,
      lessThan(.1),
    );
    expect(FlightFailureFrame.at(1, size).rocketOpacity, 0);
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('fold-loss-capture')),
  );
  await tester.runAsync(() async {
    final output = Directory('build/review/fold-loss');
    await output.create(recursive: true);
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${output.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
