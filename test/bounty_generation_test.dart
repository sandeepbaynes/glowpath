import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/cargo.dart';
import 'package:glowpath/game/puzzle.dart';

void main() {
  test(
    'salvage always offers winning routes with and without optional cargo',
    () {
      for (final level in [
        31,
        36,
        41,
        61,
        76,
        91,
        106,
        121,
        136,
        151,
        166,
        181,
        196,
        211,
        751,
        7861,
      ]) {
        for (var seed = 0; seed < 64; seed++) {
          final puzzle = Puzzle.bountyPlanet(
            seed: seed * 7919 + 7,
            levelNumber: level,
            difficulty: Difficulty.values[seed % 3],
          );
          final cargo = puzzle.cargoCell!;
          final detour = puzzle.solvedCopy().evaluate();
          final shortcut = puzzle.copyWithTiles([
            for (var i = 0; i < puzzle.tiles.length; i++)
              puzzle.tiles[i].withRotation(puzzle.bountyShortcutRotations![i]),
          ]).evaluate();
          expect(puzzle.size, 5);
          expect(puzzle.starIndices, hasLength(3));
          expect(puzzle.starIndices.contains(cargo), isFalse);
          expect(puzzle.evaluate().solved, isFalse);
          expect(detour.solved, isTrue, reason: '$level/$seed detour');
          expect(shortcut.solved, isTrue, reason: '$level/$seed shortcut');
          expect(detour.collectedStars, puzzle.starIndices);
          expect(shortcut.collectedStars, puzzle.starIndices);
          expect(detour.route, contains(cargo));
          expect(shortcut.route, isNot(contains(cargo)));
          expect(detour.route.length, greaterThan(shortcut.route.length));
          expect(detour.route.length, greaterThanOrEqualTo(19));
          expect(puzzle.solvedCopy().cargoCell, cargo);
          expect(puzzle.rotateAt(0).cargoCell, cargo);
          var legalReplay = puzzle;
          for (final action in puzzle.solutionActions) {
            legalReplay = legalReplay.rotateAt(action);
          }
          expect(legalReplay.evaluate().solved, isTrue);
          expect(legalReplay.evaluate().route, contains(cargo));
          if (seed < 8) {
            final held = puzzle.planTrace(detour.route);
            expect(held.accepted, isTrue, reason: '$level/$seed drag detour');
            expect(held.puzzle.evaluate().solved, isTrue);
            final direct = puzzle.planTrace(shortcut.route);
            expect(
              direct.accepted,
              isTrue,
              reason: '$level/$seed drag shortcut',
            );
            expect(direct.puzzle.evaluate().solved, isTrue);
          }
        }
      }
    },
  );

  test('ordinary v6 routes retain every v5 board orientation and rule', () {
    for (final level in [
      1,
      2,
      15,
      16,
      30,
      32,
      37,
      42,
      75,
      105,
      210,
      749,
      7862,
    ]) {
      for (final difficulty in Difficulty.values) {
        final old = Puzzle.strategicPlanet(
          seed: 731 + level * 97,
          levelNumber: level,
          difficulty: difficulty,
        );
        final current = Puzzle.bountyPlanet(
          seed: 731 + level * 97,
          levelNumber: level,
          difficulty: difficulty,
        );
        expect(current.cargoCell, isNull);
        expect(current.size, old.size);
        expect(current.startRow, old.startRow);
        expect(current.endRow, old.endRow);
        expect(current.starIndices, old.starIndices);
        expect(current.solutionRotations, old.solutionRotations);
        expect(current.solutionActions, old.solutionActions);
        expect(
          current.tiles.map(
            (t) => (
              t.baseMask,
              t.rotation,
              t.kind,
              t.isLocked,
              t.oneWayEntry,
              t.couplingGroup,
              t.portalPeer,
              t.gravityPeer,
              t.gravityTurn,
              t.circuit,
            ),
          ),
          old.tiles.map(
            (t) => (
              t.baseMask,
              t.rotation,
              t.kind,
              t.isLocked,
              t.oneWayEntry,
              t.couplingGroup,
              t.portalPeer,
              t.gravityPeer,
              t.gravityTurn,
              t.circuit,
            ),
          ),
        );
      }
    }
  });

  test(
    'cargo windows are recurring, explicit and pinned through serialization',
    () {
      CargoEncounter at(int hour, {int day = 23, int level = 31}) =>
          CargoEncounter.forRound(
            level: level,
            cell: 12,
            now: DateTime(2026, 11, day, hour),
          );
      expect(at(5).kind, CargoKind.moonPearl);
      expect(at(6).kind, CargoKind.dawnPrism);
      expect(at(9).kind, CargoKind.dawnPrism);
      expect(at(10).kind, CargoKind.moonPearl);
      expect(at(18).kind, CargoKind.nightOpal);
      expect(at(21).kind, CargoKind.nightOpal);
      expect(at(22).kind, CargoKind.moonPearl);
      expect(at(6).claimKey, at(9).claimKey);
      expect(at(6).claimKey, isNot(at(6, day: 24).claimKey));
      expect(at(12).claimKey, at(12, day: 24).claimKey);
      expect(
        CargoEncounter.fromJson(at(6).toJson())!.kind,
        CargoKind.dawnPrism,
      );
      expect(CargoEncounter.fromJson(at(6).toJson())!.claimKey, at(6).claimKey);
      expect(at(12, level: 41).kind.power, CargoPower.time);
      expect(at(12, level: 46).kind.power, CargoPower.lens);
      expect(CargoEncounter.fromJson({...at(6).toJson(), 'cell': -1}), isNull);
      expect(
        CargoEncounter.fromJson({
          ...at(6).toJson(),
          'claimKey': 'cargo/31/dawnPrism/2026-02-31',
        }),
        isNull,
      );
    },
  );
}
