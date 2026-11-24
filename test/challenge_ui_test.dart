import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/challenge_instruments.dart';
import 'package:glowpath/ui/challenge_result.dart';
import 'package:glowpath/ui/design.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
  });

  for (final size in [const Size(276, 60), const Size(560, 60)]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('signal rail fits shared slot $size at $scale', (
        tester,
      ) async {
        for (final count in [3, 5]) {
          await tester.pumpWidget(
            _host(
              size,
              scale,
              ChallengeStageRail(
                stageCount: count,
                activeStage: 2,
                completedStages: const {1},
                points: 941,
                cleanStreak: 1,
                instruction: 'Follow the arrows. Light three stars.',
                reduceMotion: true,
              ),
            ),
          );
          expect(find.text('941 pts · Clean streak 1'), findsOneWidget);
          expect(find.byType(Scrollable), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final size in [
    const Size(320, 430),
    const Size(375, 568),
    const Size(390, 650),
    const Size(768, 900),
    const Size(1024, 620),
    const Size(844, 250),
    const Size(560, 214),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'challenge result fits $size at $scale with working actions',
        (tester) async {
          tester.view.physicalSize = const Size(1600, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var voyage = 0, collection = 0;
          await tester.pumpWidget(
            _host(
              size,
              scale,
              _result(
                onVoyage: () => voyage++,
                onCollection: () => collection++,
              ),
            ),
          );
          await tester.pump();
          expect(find.text('Weekly Gauntlet complete'), findsOneWidget);
          expect(find.text('4198'), findsOneWidget);
          expect(find.text('1m 22.4s'), findsOneWidget);
          expect(find.text('4/5'), findsOneWidget);
          expect(find.byType(Scrollable), findsNothing);
          expect(tester.takeException(), isNull);
          for (final key in [
            'challenge-return-voyage',
            'challenge-open-collection',
          ]) {
            final action = find.byKey(ValueKey(key));
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
            await tester.tap(action);
          }
          expect(voyage, 1);
          expect(collection, 1);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('result distinguishes unknown legacy timing and partial points', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Size(375, 568),
        1,
        _result(hasCompleteTiming: false, hasCompleteScore: false),
      ),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Time not recorded'), findsOneWidget);
    expect(find.text('5 signals secured · recorded points'), findsOneWidget);
    expect(find.text('1m 22.4s'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('new period action never invokes the Voyage callback', (
    tester,
  ) async {
    var started = 0, voyage = 0;
    await tester.pumpWidget(
      _host(
        const Size(375, 568),
        1,
        _result(
          hasNewChallenge: true,
          onNewChallenge: () => started++,
          onVoyage: () => voyage++,
        ),
      ),
    );
    expect(find.text('Start new gauntlet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('challenge-return-voyage')));
    expect(started, 1);
    expect(voyage, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('UTC reset crosses midnight without abandoning the run', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 23, 23, 59, 59);
    await tester.pumpWidget(
      _host(
        const Size(340, 56),
        3,
        ChallengeResetInstrument(
          weekly: false,
          periodDate: '2026-11-23',
          now: () => now,
        ),
      ),
    );
    expect(find.text('00:00:01'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('New sprint ready'), findsOneWidget);
    expect(find.text('UTC window open'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('weekly reset uses Monday midnight UTC', (tester) async {
    var now = DateTime.utc(2026, 11, 29, 23, 59, 59);
    await tester.pumpWidget(
      _host(
        const Size(340, 56),
        1,
        ChallengeResetInstrument(
          weekly: true,
          periodDate: '2026-11-23',
          now: () => now,
        ),
      ),
    );
    expect(find.text('Next gauntlet · Monday 00:00 UTC'), findsOneWidget);
    expect(find.text('00:00:01'), findsOneWidget);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('New gauntlet ready'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('retry blocks touches on the covered game', (tester) async {
    var backgroundTouches = 0;
    await tester.pumpWidget(
      _host(
        const Size(375, 568),
        1,
        Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => backgroundTouches++,
              onPanUpdate: (_) => backgroundTouches++,
              child: const SizedBox.expand(),
            ),
            ChallengeRetryOverlay(
              stage: 2,
              stageCount: 3,
              onRetry: () {},
              reduceMotion: true,
            ),
          ],
        ),
      ),
    );
    final bounds = tester.getRect(find.byType(ChallengeRetryOverlay));
    await tester.tapAt(bounds.topLeft + const Offset(8, 8));
    await tester.dragFrom(
      bounds.topLeft + const Offset(8, 8),
      const Offset(0, 80),
    );
    expect(backgroundTouches, 0);
  });

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('challenge retry covers $size at 3x and has one clear action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retried = 0;
      await tester.pumpWidget(
        _host(
          size,
          3,
          ChallengeRetryOverlay(
            stage: 2,
            stageCount: 3,
            onRetry: () => retried++,
            reduceMotion: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 175));
      final opacity = tester
          .widget<Opacity>(find.byType(Opacity).first)
          .opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('Signal interrupted'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChallengeRetryOverlay),
          matching: find.byType(BlockSemantics),
        ),
        findsOneWidget,
      );
      expect(find.byType(Scrollable), findsNothing);
      final retry = find.byKey(const ValueKey('retry-flight'));
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      await tester.tap(retry);
      expect(retried, 1);
      expect(tester.takeException(), isNull);
    });
  }
}

ChallengeResult _result({
  VoidCallback? onVoyage,
  VoidCallback? onCollection,
  VoidCallback? onNewChallenge,
  bool hasNewChallenge = false,
  bool hasCompleteTiming = true,
  bool hasCompleteScore = true,
}) => ChallengeResult(
  weekly: true,
  stageCount: 5,
  points: 4198,
  activeElapsed: const Duration(milliseconds: 82400),
  cleanStreak: 4,
  medalEarned: true,
  starsEarned: 15,
  coinsEarned: 85,
  periodDate: '2026-11-23',
  onVoyage: onVoyage ?? () {},
  onCollection: onCollection ?? () {},
  now: () => DateTime.utc(2026, 11, 23, 20, 15),
  reduceMotion: true,
  hasNewChallenge: hasNewChallenge,
  onNewChallenge: onNewChallenge,
  hasCompleteTiming: hasCompleteTiming,
  hasCompleteScore: hasCompleteScore,
);

Widget _host(Size size, double scale, Widget child) => MaterialApp(
  theme: gameTheme(),
  home: Scaffold(
    body: Center(
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  ),
);
