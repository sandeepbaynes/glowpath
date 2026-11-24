import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/rocket_effects.dart';
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

  testWidgets('map selects available levels but never a locked destination', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final selected = <int>[];
      await _host(
        tester,
        GalaxyRouteMap(
          highestUnlocked: 4,
          currentLevel: 3,
          totalLevels: 6,
          onSelect: selected.add,
        ),
      );
      final available = find.byKey(const ValueKey('galaxy-level-2'));
      await tester.ensureVisible(available);
      await tester.pumpAndSettle();
      expect(
        tester.semantics.find(available),
        isSemantics(isButton: true, hasTapAction: true),
      );
      await tester.tap(available);
      expect(selected, [2]);

      final locked = find.byKey(const ValueKey('galaxy-level-5'));
      await tester.ensureVisible(locked);
      await tester.pumpAndSettle();
      expect(
        tester.semantics.find(locked).getSemanticsData().label,
        'Level 5, locked',
      );
      expect(
        tester.semantics.find(locked),
        isSemantics(isButton: true, hasTapAction: false),
      );
      await tester.tap(locked);
      expect(selected, [2]);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('map labels the current level and supports Enter and Space', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final selected = <int>[];
      await _host(
        tester,
        GalaxyRouteMap(
          highestUnlocked: 3,
          currentLevel: 3,
          totalLevels: 6,
          onSelect: selected.add,
        ),
      );
      final node = find.byKey(const ValueKey('galaxy-level-3'));
      await tester.ensureVisible(node);
      await tester.pumpAndSettle();
      expect(
        tester.semantics.find(node).getSemanticsData().label,
        'Level 3, current destination',
      );
      expect(
        tester.semantics.find(node),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      final gesture = find
          .descendant(of: node, matching: find.byType(GestureDetector))
          .first;
      Focus.of(tester.element(gesture)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(selected, [3, 3]);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('320px map remains usable at ${scale}x text', (tester) async {
      await _host(
        tester,
        GalaxyRouteMap(highestUnlocked: 15, currentLevel: 12, onSelect: (_) {}),
        scale: scale,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final level in [1, 12, 15]) {
        final node = find.byKey(ValueKey('galaxy-level-$level'));
        await tester.ensureVisible(node);
        await tester.pumpAndSettle();
        final rect = tester.getRect(node);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(node.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final systemSetting in [false, true]) {
    testWidgets(
      '${systemSetting ? 'system' : 'app'} reduced motion keeps the launched pose static',
      (tester) async {
        Future<Uint8List> frame(double progress) async {
          await _host(
            tester,
            RepaintBoundary(
              key: const ValueKey('launch-capture'),
              child: RocketLaunchScene(
                launchProgress: progress,
                reducedMotion: !systemSetting,
              ),
            ),
            disableAnimations: systemSetting,
          );
          await tester.pump();
          return _pixels(tester);
        }

        final ready = await frame(0);
        final earlyFlight = await frame(.1);
        final lateFlight = await frame(.9);
        expect(
          earlyFlight,
          isNot(orderedEquals(ready)),
          reason: 'Reduced motion still communicates the launched state.',
        );
        expect(
          lateFlight,
          orderedEquals(earlyFlight),
          reason: 'No liftoff travel or changing plume in the static pose.',
        );
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('launch presentation never runs its own countdown or animation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _host(
        tester,
        const RocketLaunchScene(countdown: 3, countdownProgress: .25),
      );
      await tester.pump(const Duration(seconds: 30));
      expect(find.bySemanticsLabel('Launch countdown: 3'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await _host(tester, const RocketLaunchScene(launchProgress: 1));
      await tester.pump(const Duration(seconds: 30));
      expect(find.bySemanticsLabel('Rocket launching'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _host(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 640);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: gameTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 640),
          textScaler: TextScaler.linear(scale),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('launch-capture')),
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
