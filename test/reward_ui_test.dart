import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/rewards.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/reward_progress.dart';
import 'package:glowpath/ui/rewards_panel.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Atkinson')..addFont(
          rootBundle.load(
            'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
          ),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('reward strip exposes one immediate collection action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var opened = 0;
      await tester.pumpWidget(
        _host(
          width: 276,
          height: 48,
          scale: 3,
          child: RewardProgress(
            stars: 12,
            equippedTrail: ShipTrail.starlight,
            nextTrail: ShipTrail.ember,
            onOpen: () => opened++,
          ),
        ),
      );
      final progress = find.byType(RewardProgress);
      expect(tester.getSize(progress), const Size(276, 48));
      expect(
        find.bySemanticsLabel(
          '12 stars. 3 more to unlock the Ember rocket trail. Open your collection.',
        ),
        findsOneWidget,
      );
      await tester.tap(progress);
      await tester.pumpAndSettle();
      expect(opened, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(opened, 2);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'reward receipt announces every earned reward without a claim button',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            width: 276,
            height: 72,
            scale: 3,
            child: const CompletionRewardBadge(
              reward: CompletionReward(
                earnedStars: 3,
                newAchievements: ['first_signal', 'daily_trio'],
                newTrails: [ShipTrail.ember],
                dailyMedal: true,
              ),
            ),
          ),
        );
        expect(
          find.bySemanticsLabel(
            RegExp(
              '3 stars earned.*Ember rocket trail.*Daily medal.*First signal.*Three-star day',
            ),
          ),
          findsOneWidget,
        );
        expect(find.byType(InkWell), findsNothing);
        expect(tester.getSize(find.byType(CompletionRewardBadge)).height, 72);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final size in [
    const Size(276, 214.4),
    const Size(560, 214.4),
    const Size(276, 230),
    const Size(560, 230),
    const Size(276, 320),
    const Size(360, 500),
    const Size(560, 620),
  ]) {
    testWidgets(
      'collection fits $size without scroll and only equips earned trails',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final equipped = ValueNotifier(ShipTrail.starlight);
          final calls = <ShipTrail>[];
          await tester.pumpWidget(
            _host(
              width: size.width,
              height: size.height,
              scale: 3,
              child: ValueListenableBuilder<ShipTrail>(
                valueListenable: equipped,
                builder: (context, trail, _) => RewardsPanel(
                  stars: 18,
                  equippedTrail: trail,
                  earnedAchievementIds: const {'first_signal', 'navigator_5'},
                  dailyMedals: 2,
                  weeklyMedals: 1,
                  onEquip: (value) {
                    calls.add(value);
                    equipped.value = value;
                  },
                  reduceMotion: size.height != 500,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final panelBounds = tester.getRect(find.byType(RewardsPanel));
          for (final trail in ShipTrail.values) {
            final target = find.byKey(ValueKey('trail-${trail.name}'));
            final rect = tester.getRect(target);
            expect(target.hitTestable(), findsOneWidget);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(panelBounds.contains(rect.topLeft), isTrue);
            expect(rect.right, lessThanOrEqualTo(panelBounds.right + 0.01));
            expect(rect.bottom, lessThanOrEqualTo(panelBounds.bottom + 0.01));
          }
          await tester.tap(find.byKey(const ValueKey('trail-ion')));
          await tester.pumpAndSettle();
          expect(calls, isEmpty);
          expect(
            find.bySemanticsLabel('Ion rocket trail. Unlocks at 90 stars.'),
            findsOneWidget,
          );
          expect(find.text('90 stars'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('collection-details')));
          await tester.pumpAndSettle();
          final details = await _readAllPages(
            tester,
            'collection-details',
            panelBounds,
          );
          expect(details, contains('72 more stars unlock Ion'));
          expect(details, contains('Aurora is your next unlock at 45 stars'));
          expect(details, contains('You need 27 more'));
          expect(
            details,
            contains('Previewing a locked trail does not equip it'),
          );
          expect(calls, isEmpty);
          await tester.tap(
            find.byKey(const ValueKey('collection-details-return')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('trail-ember')));
          await tester.pumpAndSettle();
          expect(calls, [ShipTrail.ember]);
          expect(
            find.bySemanticsLabel('Ember rocket trail. Equipped.'),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('collection-medals')));
          await tester.pumpAndSettle();
          final medalCopy = await _readAllPages(tester, 'medals', panelBounds);
          for (final achievement in achievementCatalog) {
            expect(medalCopy, contains(achievement.label));
            expect(medalCopy, contains(achievement.description));
          }
          expect(medalCopy, contains('First signal. Earned.'));
          expect(medalCopy, contains('Galaxy navigator. Not earned yet.'));
          expect(
            medalCopy,
            contains('2 daily medals and 1 weekly expedition medals'),
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          equipped.dispose();
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final size in [
    const Size(276, 430),
    const Size(350, 500),
    const Size(560, 700),
  ]) {
    for (final scale in [1.0, 1.2]) {
      testWidgets('all featured achievements fit $size at $scale×', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            width: size.width,
            height: size.height,
            scale: scale,
            child: RewardsPanel(
              stars: 18,
              equippedTrail: ShipTrail.ember,
              earnedAchievementIds: const {'first_signal', 'navigator_5'},
              dailyMedals: 2,
              weeklyMedals: 1,
              onEquip: (_) {},
              reduceMotion: true,
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('collection-medals')));
        await tester.pumpAndSettle();
        final bounds = tester.getRect(find.byType(RewardsPanel));
        for (var index = 0; index < achievementCatalog.length; index++) {
          final item = achievementCatalog[index];
          expect(find.text(item.label), findsOneWidget);
          final title = tester.getRect(find.text(item.label));
          final description = tester.getRect(find.text(item.description));
          expect(title.top, greaterThanOrEqualTo(bounds.top));
          expect(description.bottom, lessThanOrEqualTo(bounds.bottom - 56));
          expect(tester.takeException(), isNull);
          if (index + 1 < achievementCatalog.length) {
            await tester.tap(find.byKey(const ValueKey('medals-next')));
            await tester.pumpAndSettle();
          }
        }
      });
    }
  }
}

Future<String> _readAllPages(
  WidgetTester tester,
  String prefix,
  Rect bounds,
) async {
  final chunks = <String>[];
  for (var step = 0; step < 160; step++) {
    expect(tester.takeException(), isNull);
    final body = find.byKey(ValueKey('$prefix-body'));
    final text = tester.widget<Text>(body);
    chunks.add(text.data!);
    expect(
      MediaQuery.textScalerOf(tester.element(body)).scale(16),
      48,
      reason: 'Collection descriptions must retain the requested3× scale.',
    );
    final paragraph = tester.renderObject<RenderParagraph>(body);
    expect(
      paragraph.getMaxIntrinsicHeight(paragraph.size.width),
      lessThanOrEqualTo(paragraph.size.height + .01),
      reason: 'No clipped description: ${text.data}',
    );
    final next = find.byKey(ValueKey('$prefix-next'));
    final rect = tester.getRect(next);
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + .01));
    final action = tester.widget<Semantics>(
      find.descendant(of: next, matching: find.byType(Semantics)).first,
    );
    if (action.properties.enabled == false) return chunks.join(' ');
    expect(next.hitTestable(), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
  }
  fail('Gallery pagination did not terminate');
}

Widget _host({
  required double width,
  required double height,
  double scale = 1,
  required Widget child,
}) => MaterialApp(
  theme: gameTheme(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  ),
);
