import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/scene_transition.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'incoming scene acts immediately while the old scene only paints',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final index = ValueNotifier(0);
      final calls = <int>[];
      await tester.pumpWidget(_host(index, calls));
      index.value = 1;
      await tester.pump();
      expect(find.text('Scene 0'), findsOneWidget);
      expect(find.text('Scene 1'), findsOneWidget);
      expect(_opacity(tester, 'Scene 1'), 0);
      expect(find.text('Scene 0').hitTestable(), findsNothing);
      expect(find.text('Scene 1').hitTestable(), findsOneWidget);
      expect(find.semantics.byLabel('Scene 0'), findsNothing);
      expect(find.semantics.byLabel('Scene 1'), findsOneWidget);
      await tester.tap(find.text('Scene 1'));
      expect(calls, [1]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(calls, [1, 1]);
      await tester.pump(const Duration(milliseconds: 160));
      expect(_opacity(tester, 'Scene 1'), closeTo(.5, .02));
      expect(_opacity(tester, 'Scene 0'), closeTo(.5, .02));
      await tester.pumpAndSettle();
      expect(find.text('Scene 0'), findsNothing);
      expect(_opacity(tester, 'Scene 1'), 1);
      index.dispose();
      semantics.dispose();
    },
  );

  testWidgets(
    'rapid changes dissolve from the visible blend without an opacity restart',
    (tester) async {
      final index = ValueNotifier(0);
      await tester.pumpWidget(_host(index, []));
      index.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final before = _opacity(tester, 'Scene 1');
      expect(before, inExclusiveRange(0, 1));
      index.value = 2;
      await tester.pump();
      expect(_opacity(tester, 'Scene 1'), before);
      expect(_opacity(tester, 'Scene 0'), closeTo(1 - before, .001));
      expect(_opacity(tester, 'Scene 2'), 0);
      await tester.pump(const Duration(milliseconds: 160));
      expect(_opacity(tester, 'Scene 1'), closeTo(before * .5, .02));
      expect(_opacity(tester, 'Scene 0'), closeTo((1 - before) * .5, .02));
      expect(_opacity(tester, 'Scene 2'), closeTo(.5, .02));
      await tester.pumpAndSettle();
      expect(find.text('Scene 0'), findsNothing);
      expect(find.text('Scene 1'), findsNothing);
      expect(find.text('Scene 2'), findsOneWidget);
      index.dispose();
    },
  );

  for (final setting in ['explicit', 'reduceMotion', 'disableAnimations']) {
    testWidgets('$setting removes retained scenes without a transition', (
      tester,
    ) async {
      final index = ValueNotifier(0);
      await tester.pumpWidget(_host(index, []));
      index.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(_host(index, [], reduced: setting));
      expect(find.text('Scene 0'), findsNothing);
      expect(_opacity(tester, 'Scene 1'), 1);
      index.value = 2;
      await tester.pump();
      expect(find.text('Scene 1'), findsNothing);
      expect(_opacity(tester, 'Scene 2'), 1);
      index.dispose();
    });
  }

  testWidgets('outgoing scene tickers pause and its state is retained', (
    tester,
  ) async {
    final index = ValueNotifier(0);
    final ticks = <int, int>{};
    final starts = <int, int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (context, value, _) => SceneTransition(
              child: _TickerScene(
                key: ValueKey(value),
                index: value,
                ticks: ticks,
                starts: starts,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    index.value = 1;
    await tester.pump();
    final oldTicks = ticks[0];
    await tester.pump(const Duration(milliseconds: 160));
    expect(ticks[0], oldTicks);
    expect(ticks[1], greaterThan(0));
    expect(starts[0], 1, reason: 'The old scene is frozen, not remounted.');
    await tester.pumpWidget(const SizedBox());
    index.dispose();
  });

  testWidgets(
    'intrinsic content resizes smoothly without horizontal movement',
    (tester) async {
      final index = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder<int>(
                valueListenable: index,
                builder: (context, value, _) => SceneTransition(
                  fill: false,
                  child: SizedBox(
                    key: ValueKey(value),
                    width: 240,
                    height: value == 0 ? 60 : 120,
                    child: Text('Content $value'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final first = tester.getRect(find.byType(SceneTransition));
      index.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      final middle = tester.getRect(find.byType(SceneTransition));
      expect(middle.height, inExclusiveRange(60, 120));
      expect(middle.left, first.left);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SceneTransition)).height, 120);
      expect(tester.takeException(), isNull);
      index.dispose();
    },
  );

  testWidgets(
    'a tall outgoing column is not squeezed into its short replacement',
    (tester) async {
      final tall = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder<bool>(
                valueListenable: tall,
                builder: (context, value, _) => SceneTransition(
                  fill: false,
                  child: SizedBox(
                    key: ValueKey(value),
                    width: 240,
                    child: value
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 80, child: Text('Old heading')),
                              SizedBox(height: 80, child: Text('Old action')),
                            ],
                          )
                        : const SizedBox(height: 50, child: Text('New action')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      tall.value = false;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SceneTransition)).height, 160);
      await tester.pump(const Duration(milliseconds: 160));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(SceneTransition)).height,
        inExclusiveRange(50, 160),
      );
      expect(tester.getSize(find.byType(Column)).height, 160);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SceneTransition)).height, 50);
      tall.dispose();
    },
  );

  for (final setting in ['explicit', 'reduceMotion', 'disableAnimations']) {
    testWidgets('$setting changes intrinsic height without an AnimatedSize', (
      tester,
    ) async {
      final height = ValueNotifier(60.0);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              reduceMotion: setting == 'reduceMotion',
              disableAnimations: setting == 'disableAnimations',
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: ValueListenableBuilder<double>(
                  valueListenable: height,
                  builder: (context, value, _) => SceneTransition(
                    fill: false,
                    reduceMotion: setting == 'explicit',
                    child: SizedBox(
                      key: ValueKey(value),
                      width: 240,
                      height: value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AnimatedSize), findsNothing);
      height.value = 140;
      await tester.pump();
      expect(tester.getSize(find.byType(SceneTransition)).height, 140);
      height.value = 40;
      await tester.pump();
      expect(tester.getSize(find.byType(SceneTransition)).height, 40);
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedSize), findsNothing);
      height.dispose();
    });
  }
}

double _opacity(WidgetTester tester, String label) => tester
    .widget<FadeTransition>(
      find
          .ancestor(of: find.text(label), matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

Widget _host(ValueNotifier<int> index, List<int> calls, {String? reduced}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          reduceMotion: reduced == 'reduceMotion',
          disableAnimations: reduced == 'disableAnimations',
        ),
        child: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (context, value, _) => SceneTransition(
              reduceMotion: reduced == 'explicit',
              child: Center(
                key: ValueKey(value),
                child: TextButton(
                  onPressed: () => calls.add(value),
                  child: Text('Scene $value'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

class _TickerScene extends StatefulWidget {
  const _TickerScene({
    super.key,
    required this.index,
    required this.ticks,
    required this.starts,
  });
  final int index;
  final Map<int, int> ticks, starts;
  @override
  State<_TickerScene> createState() => _TickerSceneState();
}

class _TickerSceneState extends State<_TickerScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..addListener(() {
          widget.ticks.update(
            widget.index,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        });
  @override
  void initState() {
    super.initState();
    widget.starts.update(widget.index, (value) => value + 1, ifAbsent: () => 1);
    _ticker.repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('Ticker ${widget.index}');
}
