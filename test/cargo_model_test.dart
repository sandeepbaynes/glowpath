import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/cargo.dart';
import 'package:glowpath/ui/cargo_gallery.dart';
import 'package:glowpath/ui/cargo_model.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    CargoKind kind = CargoKind.moonPearl,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 620,
              child: CargoGallery(
                collection: const {CargoKind.moonPearl: 2},
                initialKind: kind,
                reduceMotion: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CargoModelPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<CargoModelPainter>()
      .single;

  testWidgets(
    'model drags turn a true camera without changing specimen; lower swipe browses',
    (tester) async {
      await show(tester);
      final before = painter(tester);
      await tester.drag(find.byType(CargoModelView), const Offset(80, 30));
      await tester.pumpAndSettle();
      final after = painter(tester);
      expect(after.yaw, isNot(before.yaw));
      expect(after.pitch, isNot(before.pitch));
      expect(after.kind, CargoKind.moonPearl);
      await tester.drag(find.text('1/6'), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(painter(tester).kind, CargoKind.cometShard);
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chevrons share orbit controls and preserve exact arrival specimen',
    (tester) async {
      await show(tester, kind: CargoKind.dawnPrism);
      expect(painter(tester).kind, CargoKind.dawnPrism);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('cargo-next')),
          matching: find.byType(OrbitUtility),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('cargo-next'))).width,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('cargo-next'))).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byKey(const ValueKey('cargo-previous')));
      await tester.pumpAndSettle();
      expect(painter(tester).kind, CargoKind.cometShard);
    },
  );

  testWidgets(
    'model supports keyboard rotation and reset, without idle motion',
    (tester) async {
      await show(tester);
      final modelMouseRegion = find.descendant(
        of: find.byType(CargoModelView),
        matching: find.byType(MouseRegion),
      );
      Focus.of(tester.element(modelMouseRegion)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(painter(tester).yaw, closeTo(math.pi * 2 - .04, .0001));
      await tester.pump(const Duration(seconds: 10));
      expect(painter(tester).yaw, closeTo(math.pi * 2 - .04, .0001));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(painter(tester).yaw, closeTo(-.22, .0001));
    },
  );
}
