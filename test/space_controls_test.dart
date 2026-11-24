import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/space_controls.dart';
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
  testWidgets('fixed-height actions paint complete labels at 3x text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final label in ['Previous', 'Buy · 25 coins', 'Use · +8s']) {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 136,
                  height: 48,
                  child: SpaceAction(
                    label: label,
                    onPressed: () => calls++,
                    compact: true,
                    reduceMotion: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byType(SpaceAction);
      final text = find.text(label);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
        maxLines: 1,
      )..layout();
      final inkTop = paragraph.localToGlobal(Offset.zero);
      final inkBottom = paragraph.localToGlobal(
        Offset(painter.width, painter.height),
      );
      painter.dispose();
      final bounds = tester.getRect(button);
      expect(inkTop.dx, greaterThanOrEqualTo(bounds.left));
      expect(inkTop.dy, greaterThanOrEqualTo(bounds.top));
      expect(inkBottom.dx, lessThanOrEqualTo(bounds.right));
      expect(inkBottom.dy, lessThanOrEqualTo(bounds.bottom));
      expect(bounds.size, const Size(136, 48));
      expect(
        tester.semantics.find(button),
        isSemantics(
          label: label,
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(button);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });
  testWidgets('one touch or keyboard activation runs one action', (
    tester,
  ) async {
    var plays = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SpaceAction(label: 'Play', onPressed: () => plays++),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final play = find.byType(SpaceAction);
    await tester.tap(play);
    await tester.pumpAndSettle();
    expect(plays, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(plays, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(plays, 3);
  });

  testWidgets('cancelled press keeps the hit target fixed and never plays', (
    tester,
  ) async {
    var plays = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SpaceAction(label: 'Play', onPressed: () => plays++),
            ),
          ),
        ),
      ),
    );
    final play = find.byType(SpaceAction);
    final bounds = tester.getRect(play);
    final gesture = await tester.startGesture(bounds.center);
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(play), bounds);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(plays, 0);
    expect(tester.getRect(play), bounds);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mode selection eases visually while semantics change immediately',
    (tester) async {
      final selected = ValueNotifier(false);
      addTearDown(selected.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                child: ValueListenableBuilder<bool>(
                  valueListenable: selected,
                  builder: (_, value, _) => OrbitMode(
                    label: 'Voyage',
                    selected: value,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final bounds = tester.getRect(find.byType(OrbitMode));
      final before = tester.widget<Text>(find.text('Voyage')).style!.color;
      selected.value = true;
      await tester.pump();
      expect(
        tester.semantics.find(find.byType(OrbitMode)),
        isSemantics(
          isSelected: true,
          isEnabled: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(tester.widget<Text>(find.text('Voyage')).style!.color, before);
      await tester.pump(const Duration(milliseconds: 90));
      final middle = tester.widget<Text>(find.text('Voyage')).style!.color;
      expect(middle, isNot(before));
      expect(middle, isNot(Palette.white));
      expect(tester.getRect(find.byType(OrbitMode)), bounds);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Voyage')).style!.color,
        Palette.white,
      );
      semantics.dispose();
    },
  );

  testWidgets('keyboard press responds visually without delaying the action', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SpaceAction(label: 'Play', onPressed: () => calls++),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(SpaceAction);
    final bounds = tester.getRect(button);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final transform = tester.widget<Transform>(
      find.descendant(of: button, matching: find.byType(Transform)).first,
    );
    expect(transform.transform.storage.first, lessThan(1));
    expect(tester.getRect(button), bounds);
    await tester.pumpAndSettle();
    final settled = tester.widget<Transform>(
      find.descendant(of: button, matching: find.byType(Transform)).first,
    );
    expect(settled.transform.storage.first, 1);
    expect(calls, 1);
    expect(
      tester.getSize(find.byKey(const ValueKey('launch-glyph'))),
      const Size(22, 22),
    );
  });

  testWidgets('changing a hint label crossfades within one active button', (
    tester,
  ) async {
    final second = ValueNotifier(false);
    addTearDown(second.dispose);
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ValueListenableBuilder<bool>(
                valueListenable: second,
                builder: (_, value, _) => SpaceAction(
                  label: value ? 'Turn this relay' : 'Show a hint',
                  icon: value
                      ? Icons.rotate_right_rounded
                      : Icons.lightbulb_outline_rounded,
                  onPressed: () => calls++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final bounds = tester.getRect(find.byType(SpaceAction));
    second.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.text('Show a hint'), findsOneWidget);
    expect(find.text('Turn this relay'), findsOneWidget);
    final incoming = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Turn this relay'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(incoming.opacity.value, inExclusiveRange(0, 1));
    expect(
      tester.semantics.find(find.byType(SpaceAction)),
      isSemantics(
        label: 'Turn this relay',
        isEnabled: true,
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byType(SpaceAction));
    expect(calls, 1);
    await tester.pumpAndSettle();
    expect(find.text('Show a hint'), findsNothing);
    expect(tester.getRect(find.byType(SpaceAction)), bounds);
    semantics.dispose();
  });

  testWidgets(
    'mode selection and disabled action are accessible at large text',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(3),
              reduceMotion: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 288,
                  child: Column(
                    children: [
                      OrbitMode(
                        label: 'Voyage',
                        selected: true,
                        onPressed: () => calls++,
                      ),
                      const OrbitMode(
                        label: 'Daily trio',
                        selected: false,
                        onPressed: null,
                      ),
                      const SpaceAction(label: 'Play', onPressed: null),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.semantics.find(find.byType(OrbitMode).first),
        isSemantics(
          isButton: true,
          isEnabled: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.semantics.find(find.byType(OrbitMode).last),
        isSemantics(isButton: true, isEnabled: false, isSelected: false),
      );
      final play = find.byType(SpaceAction);
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(tester.getSize(play).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
