import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/game/puzzle.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/flight_pace_choice.dart';
import 'package:glowpath/ui/flight_settings.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:glowpath/ui/space_controls.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'pace cards restart only changed Voyage choices and leave challenges untouched',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      final game = (await tester.runAsync(() async {
        final value = GameController(
          preferences: prefs,
          snapshotWriter: (_) async => true,
        );
        await value.load();
        return value;
      }))!;
      addTearDown(game.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: Scaffold(
            body: OrbitPanelFrame(
              title: 'FLIGHT CONTROLS',
              fit: true,
              onClose: () {},
              child: FlightSettings(
                game: game,
                onRestart: () {},
                onSupport: () {},
                onLeague: () {},
                onRewards: () {},
                onLicenses: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(OrbitMode),
        findsNWidgets(3),
        reason: 'Only Flight, Feel and About are section tabs.',
      );
      expect(find.byType(FlightPaceChoice), findsNWidgets(3));
      expect(find.text('Alternate route · 30s'), findsOneWidget);
      expect(find.text('Default route · 30s'), findsOneWidget);
      expect(find.text('Faster clock · 27s'), findsOneWidget);
      final title = tester.getRect(find.text('Voyage pace'));
      final nav = tester.getRect(
        find.byKey(const ValueKey('settings-section-0')),
      );
      expect(
        title.top - nav.bottom,
        inInclusiveRange(0, 24),
        reason: 'Roomy desktop content follows section navigation immediately.',
      );

      bool checked(String name) => tester
          .widget<Semantics>(
            find
                .descendant(
                  of: find.byKey(ValueKey('pace-$name')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .checked!;
      expect(checked('balanced'), isTrue);
      expect(checked('gentle'), isFalse);
      expect(checked('bright'), isFalse);
      final seed = game.puzzle.seed;
      game.rotate(game.puzzle.tiles.indexWhere((tile) => !tile.isLocked));
      final moves = game.moves;
      await tester.tap(find.byKey(const ValueKey('pace-balanced')));
      await tester.pumpAndSettle();
      expect(
        game.moves,
        moves,
        reason: 'Choosing the current pace does not restart a route.',
      );
      await tester.tap(find.byKey(const ValueKey('pace-bright')));
      await tester.pumpAndSettle();
      expect(game.difficulty, Difficulty.bright);
      expect(game.puzzle.seed, isNot(seed));
      expect(game.moves, 0);
      expect(checked('balanced'), isFalse);
      expect(checked('bright'), isTrue);
      game.setMode(GameMode.daily);
      await tester.pumpAndSettle();
      final daily = game.puzzle;
      await tester.tap(find.byKey(const ValueKey('pace-gentle')));
      await tester.pumpAndSettle();
      expect(game.difficulty, Difficulty.gentle);
      expect(game.puzzle, same(daily));
      expect(game.isDaily, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'pace cards have a keyboard-selectable checked state without text fitting',
    (tester) async {
      var selected = false;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: Focus(
                  focusNode: focus,
                  child: StatefulBuilder(
                    builder: (context, setState) => FlightPaceChoice(
                      label: 'Bright',
                      description: 'Faster clock · 27s',
                      selected: selected,
                      reduceMotion: true,
                      onPressed: () => setState(() => selected = true),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final focusable = find.descendant(
        of: find.byType(FlightPaceChoice),
        matching: find.byType(FocusableActionDetector),
      );
      Focus.of(
        tester.element(
          find.descendant(
            of: focusable,
            matching: find.byType(GestureDetector),
          ),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(
        find.descendant(
          of: find.byType(FlightPaceChoice),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
