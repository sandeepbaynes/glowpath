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
      await tester.drag(surface, const Offset(-130, 0));
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
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('swiping previews a trail without equipping it', (tester) async {
    final equips = <ShipTrail>[];
    await tester.pumpWidget(_host(onEquip: equips.add));
    final surface = find.byKey(const ValueKey('trail-carousel'));
    await tester.drag(surface, const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(find.text('Ember'), findsOneWidget);
    expect(equips, isEmpty);
    await tester.tap(find.byKey(const ValueKey('trail-ember')));
    await tester.pumpAndSettle();
    expect(equips, [ShipTrail.ember]);
    await tester.drag(surface, const Offset(-140, 0));
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
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    final body = find.byKey(const ValueKey('medals-body'));
    expect(tester.widget<Text>(body).data, isNot(before));
    expect(MediaQuery.textScalerOf(tester.element(body)).scale(16), 48);
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _host({
  bool achievements = false,
  double scale = 1,
  ValueChanged<ShipTrail>? onEquip,
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
            reduceMotion: true,
          ),
        ),
      ),
    ),
  ),
);
