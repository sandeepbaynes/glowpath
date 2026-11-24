import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/console_toggle.dart';
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

  testWidgets('touch, keyboard and semantic activation each toggle once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var value = false;
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ConsoleToggle(
              title: 'Reduce motion',
              subtitle: 'Still skies and instant turns.',
              value: value,
              onChanged: (next) => setState(() {
                value = next;
                calls++;
              }),
            ),
          ),
        ),
      ),
    );
    final toggle = find.byType(ConsoleToggle);
    expect(
      tester.semantics.find(toggle),
      isSemantics(
        label: 'Reduce motion',
        hint: 'Still skies and instant turns.',
        hasToggledState: true,
        isToggled: false,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(calls, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(calls, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(calls, 3);
    tester.semantics.tap(find.semantics.byLabel('Reduce motion'));
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(calls, 4);
    semantics.dispose();
  });

  testWidgets('cancelled press keeps its bounds and does not change value', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 288,
            child: ConsoleToggle(
              title: 'Touch feedback',
              subtitle: 'A light tap for each turn.',
              value: true,
              onChanged: (_) => calls++,
            ),
          ),
        ),
      ),
    );
    final toggle = find.byType(ConsoleToggle);
    final bounds = tester.getRect(toggle);
    expect(bounds.height, greaterThanOrEqualTo(48));
    final press = await tester.startGesture(bounds.center);
    await tester.pump();
    expect(tester.getRect(toggle), bounds);
    await press.cancel();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.getRect(toggle), bounds);
  });

  testWidgets('disabled switch wraps at 3x text and exposes its on state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(288, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: ConsoleToggle(
                title: 'Stronger pipe contrast',
                subtitle: 'Enabled by your device settings.',
                value: true,
                onChanged: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.byType(ConsoleToggle);
    expect(
      tester.semantics.find(toggle),
      isSemantics(
        hasToggledState: true,
        isToggled: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    final bounds = tester.getRect(toggle);
    for (final text in [
      'Stronger pipe contrast',
      'Enabled by your device settings.',
    ]) {
      final textBounds = tester.getRect(find.text(text));
      expect(bounds.contains(textBounds.topLeft), isTrue);
      expect(bounds.contains(textBounds.bottomRight), isTrue);
    }
    expect(bounds.height, greaterThanOrEqualTo(48));
    await tester.tap(toggle);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
