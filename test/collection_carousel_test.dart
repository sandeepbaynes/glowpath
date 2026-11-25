import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/rewards.dart';
import 'package:glowpath/ui/achievement_art.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/rewards_panel.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'achievement carousel swipes, respects bounds and retains award state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(achievements: true));
      expect(find.text('First signal'), findsOneWidget);
      expect(
        tester
            .widget<AchievementArtwork>(find.byType(AchievementArtwork))
            .earned,
        isTrue,
      );
      final surface = find.byKey(const ValueKey('achievement-carousel'));
      await tester.drag(surface, const Offset(130, 0));
      await tester.pumpAndSettle();
      expect(find.text('First signal'), findsOneWidget);
      await tester.drag(surface, const Offset(-230, 0));
      await tester.pumpAndSettle();
      expect(find.text('Planet finder'), findsOneWidget);
      expect(
        tester
            .widget<AchievementArtwork>(find.byType(AchievementArtwork))
            .earned,
        isFalse,
      );
      expect(
        find.bySemanticsLabel(RegExp('Planet finder. Not earned yet.')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('medals-previous')));
      await tester.pumpAndSettle();
      expect(find.text('First signal'), findsOneWidget);
      _expectNoVerticalScroll();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  for (final achievements in [false, true]) {
    testWidgets(
      '${achievements ? 'achievement' : 'trail'} pages follow the finger with both specimens visible',
      (tester) async {
        await tester.pumpWidget(
          _host(achievements: achievements, reduceMotion: false),
        );
        final surface = find.byKey(
          ValueKey(achievements ? 'achievement-carousel' : 'trail-carousel'),
        );
        final current = find.byKey(
          ValueKey(
            achievements
                ? 'achievement-page-first_signal'
                : 'trail-page-starlight',
          ),
        );
        final next = find.byKey(
          ValueKey(
            achievements ? 'achievement-page-navigator_5' : 'trail-page-ember',
          ),
        );
        final initial = tester.getRect(current);
        final gesture = await tester.startGesture(tester.getCenter(surface));
        await gesture.moveBy(const Offset(-24, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(-100, 0));
        await tester.pump();
        final outgoing = tester.getRect(current);
        final incoming = tester.getRect(next);
        expect(outgoing.left, lessThan(initial.left - 80));
        expect(outgoing.right, greaterThan(initial.left));
        expect(incoming.left, lessThan(initial.right));
        expect(incoming.left, closeTo(outgoing.right, .1));
        expect(incoming.width, closeTo(initial.width, .1));
        // A short, stationary drag returns the same full page, not a swapped state.
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.getRect(current).left, closeTo(initial.left, .1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('chevrons slide both achievement pages and remain fixed', (
    tester,
  ) async {
    await tester.pumpWidget(_host(achievements: true, reduceMotion: false));
    final nextButton = find.byKey(const ValueKey('medals-next'));
    final buttonRect = tester.getRect(nextButton);
    final first = find.byKey(const ValueKey('achievement-page-first_signal'));
    final origin = tester.getRect(first);
    await tester.tap(nextButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 190));
    final next = find.byKey(const ValueKey('achievement-page-navigator_5'));
    expect(tester.getRect(first).left, lessThan(origin.left));
    expect(tester.getRect(next).left, lessThan(origin.right));
    expect(tester.getRect(nextButton), buttonRect);
    await tester.pumpAndSettle();
    expect(find.text('Planet finder'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mouse drag previews trails without equipping them', (
    tester,
  ) async {
    final equips = <ShipTrail>[];
    await tester.pumpWidget(_host(onEquip: equips.add));
    await tester.drag(
      find.byKey(const ValueKey('trail-carousel')),
      const Offset(-230, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ember'), findsOneWidget);
    expect(equips, isEmpty);
  });

  testWidgets('reversing a chevron transition returns to the requested page', (
    tester,
  ) async {
    await tester.pumpWidget(_host(achievements: true, reduceMotion: false));
    final first = find.byKey(const ValueKey('achievement-page-first_signal'));
    final origin = tester.getRect(first);
    await tester.tap(find.byKey(const ValueKey('medals-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('medals-previous')));
    await tester.pumpAndSettle();
    expect(tester.getRect(first).left, closeTo(origin.left, .1));
    expect(find.text('First signal'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('swiping previews a trail without equipping it', (tester) async {
    final equips = <ShipTrail>[];
    await tester.pumpWidget(_host(onEquip: equips.add));
    final surface = find.byKey(const ValueKey('trail-carousel'));
    await tester.drag(surface, const Offset(-230, 0));
    await tester.pumpAndSettle();
    expect(find.text('Ember'), findsOneWidget);
    expect(equips, isEmpty);
    await tester.tap(find.byKey(const ValueKey('trail-ember')));
    await tester.pumpAndSettle();
    expect(equips, [ShipTrail.ember]);
    await tester.drag(surface, const Offset(-230, 0));
    await tester.pumpAndSettle();
    expect(find.text('Aurora'), findsOneWidget);
    expect(equips, [ShipTrail.ember]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large-type reading pages swipe without shrinking text', (
    tester,
  ) async {
    await tester.pumpWidget(_host(achievements: true, scale: 3));
    final before = tester
        .widget<Text>(find.byKey(const ValueKey('medals-body')))
        .data;
    await tester.drag(
      find.byKey(const ValueKey('medals-carousel')),
      const Offset(-230, 0),
    );
    await tester.pumpAndSettle();
    final body = find.byKey(const ValueKey('medals-body'));
    expect(tester.widget<Text>(body).data, isNot(before));
    expect(MediaQuery.textScalerOf(tester.element(body)).scale(16), 48);
    _expectNoVerticalScroll();
    expect(tester.takeException(), isNull);
  });
}

Widget _host({
  bool achievements = false,
  double scale = 1,
  ValueChanged<ShipTrail>? onEquip,
  bool reduceMotion = true,
}) => MaterialApp(
  theme: gameTheme(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 350,
          height: 500,
          child: RewardsPanel(
            stars: 18,
            equippedTrail: ShipTrail.starlight,
            earnedAchievementIds: const {'first_signal'},
            dailyMedals: 1,
            weeklyMedals: 0,
            onEquip: onEquip ?? (_) {},
            initialAchievements: achievements,
            reduceMotion: reduceMotion,
          ),
        ),
      ),
    ),
  ),
);

void _expectNoVerticalScroll() => expect(
  find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        (widget.axisDirection == AxisDirection.down ||
            widget.axisDirection == AxisDirection.up),
  ),
  findsNothing,
);
