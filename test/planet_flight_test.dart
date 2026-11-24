import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/ui/mission_briefing.dart';
import 'package:glowpath/ui/planet_flight.dart';
import 'package:glowpath/ui/space_scenery.dart';

void main() {
  Future<void> showFlight(
    WidgetTester tester, {
    required VoidCallback onComplete,
    bool reduceMotion = true,
    Size size = const Size(393, 852),
    double textScale = 1,
    List<MissionBriefingBeat> beats = firstFlightBriefing,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: PlanetFlight(
            world: VoyageWorld.forLevel(31),
            beats: beats,
            reduceMotion: reduceMotion,
            onComplete: onComplete,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('reduced motion arrives immediately but waits for all dialogue', (
    tester,
  ) async {
    var completed = 0;
    await showFlight(tester, onComplete: () => completed++);
    await tester.pump(const Duration(seconds: 10));
    expect(completed, 0);
    expect(find.text('Viridian'), findsOneWidget);
    expect(
      find.byType(Image),
      findsNothing,
      reason: 'Flight uses the shared illustrated art, with no rendered movie or cockpit plate.',
    );
    expect(find.byKey(const ValueKey('skip-planet-flight')), findsNothing);
    expect(find.text(firstFlightBriefing[0].text), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flight-next')));
    await tester.pump();
    expect(find.text(firstFlightBriefing[1].text), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flight-previous')));
    await tester.pump();
    expect(find.text(firstFlightBriefing[0].text), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('flight-next')));
      await tester.pump();
    }
    expect(completed, 1);
    await tester.tap(find.byKey(const ValueKey('flight-next')));
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('flight arrives behind a conversation without dismissing it', (
    tester,
  ) async {
    var completed = 0;
    await showFlight(
      tester,
      onComplete: () => completed++,
      reduceMotion: false,
    );
    expect(find.byKey(const ValueKey('skip-planet-flight')), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    expect(find.byKey(const ValueKey('skip-planet-flight')), findsNothing);
    expect(find.text(firstFlightBriefing[0].text), findsOneWidget);
    expect(completed, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'skip flight changes travel only and backgrounding pauses travel',
    (tester) async {
      var completed = 0;
      await showFlight(
        tester,
        onComplete: () => completed++,
        reduceMotion: false,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(const ValueKey('skip-planet-flight')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.byKey(const ValueKey('skip-planet-flight')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(completed, 0);
      expect(find.text(firstFlightBriefing[0].text), findsOneWidget);
      expect(find.byKey(const ValueKey('skip-planet-flight')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('rotation preserves reading position across pagination', (
    tester,
  ) async {
    var completed = 0;
    final beats = mechanicBriefingFor(
      Puzzle.planet(seed: 55, levelNumber: 196),
    );
    await showFlight(
      tester,
      onComplete: () => completed++,
      size: const Size(320, 568),
      textScale: 3,
      beats: beats,
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('flight-next')));
      await tester.pump();
    }
    final before = tester
        .widget<Text>(find.byKey(const ValueKey('flight-dialogue-copy')))
        .data!;
    expect(beats.first.text, contains(before));
    await showFlight(
      tester,
      onComplete: () => completed++,
      size: const Size(1024, 1366),
      beats: beats,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('flight-dialogue-copy')))
          .data,
      beats.first.text,
    );
    expect(completed, 0);
    await tester.tap(find.byKey(const ValueKey('flight-next')));
    await tester.pump();
    expect(find.text(beats[1].text), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(844, 390),
    const Size(1024, 1366),
    const Size(1366, 1024),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('full dialogue remains readable at $size and ${scale}x', (
        tester,
      ) async {
        final beats = mechanicBriefingFor(
          Puzzle.planet(seed: 55, levelNumber: 196),
        );
        var completed = 0;
        await showFlight(
          tester,
          onComplete: () => completed++,
          size: size,
          textScale: scale,
          beats: beats,
        );
        final chunks = <String>[];
        for (var i = 0; i < 100 && completed == 0; i++) {
          expect(tester.takeException(), isNull);
          final copy = find.byKey(const ValueKey('flight-dialogue-copy'));
          chunks.add(tester.widget<Text>(copy).data!);
          final paragraph = tester.renderObject<RenderParagraph>(copy);
          expect(
            paragraph.getMaxIntrinsicHeight(paragraph.size.width),
            lessThanOrEqualTo(paragraph.size.height + .01),
          );
          for (final key in ['flight-next', 'flight-previous']) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
            expect(rect.right, lessThanOrEqualTo(size.width));
          }
          await tester.tap(find.byKey(const ValueKey('flight-next')));
          await tester.pump();
        }
        expect(completed, 1);
        expect(
          chunks.join('').replaceAll(RegExp(r'\s'), ''),
          beats.map((b) => b.text).join('').replaceAll(RegExp(r'\s'), ''),
        );
        expect(find.byType(Scrollable), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
