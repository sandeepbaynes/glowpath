import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:glowpath/ui/design.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glowpath/services/flight_league.dart';
import 'package:glowpath/ui/flight_league_panel.dart';

class _DelayedJoin extends FlightLeague {
  _DelayedJoin() : super(mock: true);
  final finish = Completer<void>();
  @override
  Future<void> join() async {
    await finish.future;
    await super.join();
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader('Atkinson')..addFont(
          rootBundle.load(
            'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
          ),
        ))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Rect> showPanel(
    WidgetTester tester,
    FlightLeague league,
    Size size,
    double scale,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final panelSize = Size(
      math.min(560, size.width - 40),
      size.height * .92 - 80,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: gameTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                key: const ValueKey('test-sheet-content'),
                width: panelSize.width,
                height: panelSize.height,
                child: FlightLeaguePanel(league: league, reduceMotion: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getRect(find.byKey(const ValueKey('test-sheet-content')));
  }

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(844, 390),
    const Size(1024, 1366),
    const Size(1366, 1024),
  ]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('league fits $size at ${scale}x before and after join', (
        tester,
      ) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        final league = FlightLeague(mock: true);
        final bounds = await showPanel(tester, league, size, scale);
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Local demo with simulated rivals')),
          findsOneWidget,
        );
        final join = find.byKey(const ValueKey('league-join'));
        expect(bounds.contains(tester.getRect(join).center), isTrue);
        await tester.tap(join);
        await tester.pumpAndSettle();
        expect(league.joined, isTrue);
        expect(tester.takeException(), isNull);
        expect(
          find.bySemanticsLabel(RegExp('Local demo with simulated rivals')),
          findsOneWidget,
        );
        for (final key in [
          'league-daily',
          'league-weekly',
          'league-refresh',
          'league-leave',
          'league-next',
          'league-previous',
        ]) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(
            rect.left,
            greaterThanOrEqualTo(bounds.left - .01),
            reason: key,
          );
          expect(
            rect.right,
            lessThanOrEqualTo(bounds.right + .01),
            reason: key,
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(bounds.bottom + .01),
            reason: key,
          );
          expect(rect.top, greaterThanOrEqualTo(bounds.top - .01), reason: key);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
        }
        // All five ranks must be reachable without scrolling, including You.
        for (
          var page = 0;
          page < 5 && find.text('You').evaluate().isEmpty;
          page++
        ) {
          await tester.tap(find.byKey(const ValueKey('league-next')));
          await tester.pumpAndSettle();
        }
        expect(find.text('You'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('league-weekly')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('league-leave')));
        await tester.pumpAndSettle();
        expect(league.joined, isFalse);
        expect(find.byKey(const ValueKey('league-join')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        league.dispose();
        semantics.dispose();
      });
    }
  }

  testWidgets(
    'closing the panel during join never calls setState after dispose',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final league = _DelayedJoin();
      await showPanel(tester, league, const Size(393, 852), 1);
      await tester.tap(find.byKey(const ValueKey('league-join')));
      await tester.pumpWidget(const SizedBox());
      league.finish.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      league.dispose();
    },
  );
}
