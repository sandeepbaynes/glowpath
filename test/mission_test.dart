import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/mission.dart';

const n = MissionDirection.north;
const e = MissionDirection.east;
const s = MissionDirection.south;
const w = MissionDirection.west;

void main() {
  test('all authored missions are repeatable and have a risk-free reference flight', () {
    for (var number = 1; number <= Mission.campaignCount; number++) {
      final mission = Mission.campaign(number);
      final repeated = Mission.campaign(number);
      expect(_cells(mission), _cells(repeated), reason: 'Mission $number');
      expect(mission.starIndices.length, 3);
      expect(
        mission.referencePath.toSet().length,
        mission.referencePath.length,
      );
      expect(
        mission.launch(ignoreRisk: true).success,
        isFalse,
        reason: 'Mission $number starts playable',
      );
      expect(mission.timeLimitSeconds, number == 1 ? 0 : greaterThan(0));
      final safe = mission.solvedCopy();
      for (final attempt in [1, 2, 3, 10, 65535]) {
        final result = safe.launch(attempt: attempt);
        expect(
          result.success,
          isTrue,
          reason: 'Mission $number, attempt $attempt: ${result.message}',
        );
        expect(
          result.steps.map((step) => step.cellIndex),
          mission.referencePath,
        );
        expect(result.collectedStars, mission.starIndices);
        expect(result.failure, isNull);
        expect(result.failureCell, isNull);
        expect(
          result.steps.any(
            (step) => safe.cells[step.cellIndex].kind == CellKind.asteroid,
          ),
          isFalse,
        );
      }
    }
    expect(() => Mission.campaign(0), throwsArgumentError);
    expect(
      () => Mission.campaign(Mission.campaignCount + 1),
      throwsArgumentError,
    );
  });

  test(
    'mechanics are introduced gradually and disclose their actual rules',
    () {
      const introductions = {
        CellKind.block: 4,
        CellKind.lockedRelay: 5,
        CellKind.oneWay: 6,
        CellKind.wormhole: 7,
        CellKind.blackHole: 8,
        CellKind.whiteHole: 9,
        CellKind.slingshot: 10,
        CellKind.asteroid: 11,
      };
      for (final entry in introductions.entries) {
        for (var number = 1; number < entry.value; number++) {
          expect(
            Mission.campaign(number).cells
                .any((cell) => cell.kind == entry.key),
            isFalse,
          );
        }
        expect(
          Mission.campaign(entry.value).cells
              .any((cell) => cell.kind == entry.key),
          isTrue,
        );
        expect(Mission.campaign(entry.value).rules.length, greaterThan(1));
      }
      expect(Mission.campaign(11).wrapEdges, isFalse);
      expect(Mission.campaign(12).wrapEdges, isTrue);
      expect(Mission.campaign(14).wrapEdges, isTrue);
    },
  );

  test('locked relays and blocks cannot rotate', () {
    final locked = Mission.campaign(5).cells[11];
    final block = Mission.campaign(4).cells[12];
    expect(locked.rotatable, isFalse);
    expect(identical(locked.rotated(), locked), isTrue);
    expect(block.rotatable, isFalse);
    expect(block.connections, 0);
    expect(identical(block.rotated(), block), isTrue);
  });

  test('broken and blocked cells are identified without adding them to the valid trace', () {
    final entrance = Mission.campaign(1).launch();
    expect(entrance.failureCell, 10);
    expect(entrance.steps, isEmpty);
    final mission = Mission.campaign(1).solvedCopy();
    final cells = mission.cells.toList();
    cells[12] = const MissionCell(baseMask: n | s);
    final broken = mission.copyWithCells(cells).launch();
    expect(broken.failure, FlightFailure.brokenConnection);
    expect(broken.failureCell, 12);
    expect(broken.steps.map((step) => step.cellIndex), [10, 11]);
    expect(broken.collectedStars, {11});
    cells[12] = const MissionCell(kind: CellKind.block, baseMask: 0);
    final blocked = mission.copyWithCells(cells).launch();
    expect(blocked.failure, FlightFailure.blocked);
    expect(blocked.failureCell, 12);
    expect(blocked.steps.last.cellIndex, 11);
  });

  test(
    'unmarked exits and slingshots beyond the grid fail at the last valid cell',
    () {
      final mission = Mission.campaign(1).solvedCopy();
      final cells = mission.cells.toList();
      cells[10] = const MissionCell(baseMask: w | n);
      cells[5] = const MissionCell(baseMask: n | s);
      cells[0] = const MissionCell(baseMask: n | s);
      final wrongExit = mission.copyWithCells(cells).launch();
      expect(wrongExit.failure, FlightFailure.wrongExit);
      expect(wrongExit.failureCell, 0);
      expect(wrongExit.steps.last.cellIndex, 0);

      final topLaunch = Mission.campaign(6).solvedCopy();
      final slingCells = topLaunch.cells.toList();
      slingCells[0] = const MissionCell(
        kind: CellKind.slingshot,
        baseMask: w | n,
        baseInput: w,
      );
      final overshoot = topLaunch.copyWithCells(slingCells).launch();
      expect(overshoot.failure, FlightFailure.slingshotMiss);
      expect(overshoot.failureCell, 0);
      expect(overshoot.steps.single.cellIndex, 0);
    },
  );

  test('one-way arrows reject backward flight even when the pipe connects', () {
    final mission = Mission.campaign(14).solvedCopy();
    final cells = mission.cells.toList();
    cells[8] = cells[8].withRotation(2);
    expect(cells[8].connections, mission.cells[8].connections);
    final result = mission.copyWithCells(cells).launch();
    expect(result.failure, FlightFailure.wrongWay);
    expect(result.failureCell, 8);
    expect(result.steps.last.cellIndex, 13);
  });

  test(
    'wormholes jump to the paired exit and then continue through its arrow',
    () {
      final mission = Mission.campaign(7).solvedCopy();
      final result = mission.launch();
      final entry = result.steps.firstWhere((step) => step.cellIndex == 7);
      expect(entry.transition, FlightTransition.wormhole);
      expect(entry.nextCell, 17);
      expect(result.steps.map((step) => step.cellIndex), [5, 6, 7, 17, 18, 19]);
      expect(
        result.steps.firstWhere((step) => step.cellIndex == 17).outgoing,
        e,
      );
      final cells = mission.cells.toList();
      cells[7] = const MissionCell(
        kind: CellKind.wormhole,
        baseMask: w | e,
        baseInput: w,
      );
      expect(
        mission.copyWithCells(cells).launch().failure,
        FlightFailure.unpairedWormhole,
      );
    },
  );

  test('black and white forks make their disclosed opposite turn choices', () {
    final black = Mission.campaign(8).solvedCopy();
    final white = Mission.campaign(9).solvedCopy();
    expect(
      black.launch().steps.firstWhere((step) => step.cellIndex == 6).outgoing,
      s,
    );
    expect(
      white.launch().steps.firstWhere((step) => step.cellIndex == 16).outgoing,
      n,
    );
    final cells = black.cells.toList();
    cells[6] = cells[6].withRotation(2);
    expect(
      black
          .copyWithCells(cells)
          .launch()
          .steps
          .firstWhere((step) => step.cellIndex == 6)
          .outgoing,
      e,
    );
  });

  test(
    'a slingshot clears one blocked cell but requires a connected landing',
    () {
      final mission = Mission.campaign(10).solvedCopy();
      final result = mission.launch();
      final jump = result.steps.firstWhere((step) => step.cellIndex == 11);
      expect(jump.transition, FlightTransition.slingshot);
      expect(jump.nextCell, 13);
      expect(mission.cells[12].kind, CellKind.block);
      expect(result.steps.any((step) => step.cellIndex == 12), isFalse);
      final cells = mission.cells.toList();
      cells[13] = const MissionCell(baseMask: n | s);
      final miss = mission.copyWithCells(cells).launch();
      expect(miss.failureCell, 13);
      expect(miss.failure, FlightFailure.brokenConnection);
      expect(miss.steps.last.cellIndex, 11);
    },
  );

  test(
    'edge wrapping connects opposite gates and loops stop within 25 cells',
    () {
      final mission = Mission.campaign(12).solvedCopy();
      final crossing = mission.launch().steps.firstWhere(
        (step) => step.cellIndex == 1,
      );
      expect(crossing.transition, FlightTransition.wrap);
      expect(crossing.outgoing, n);
      expect(crossing.nextCell, 21);
      final cells = mission.cells.toList();
      cells[10] = const MissionCell(baseMask: w | e);
      cells[11] = const MissionCell(baseMask: w | n);
      cells[6] = const MissionCell(baseMask: s | w);
      for (final index in [5, 9, 8, 7]) {
        cells[index] = const MissionCell(baseMask: w | e);
      }
      final loop = mission.copyWithCells(cells).launch();
      expect(loop.failure, FlightFailure.loop);
      expect(loop.failureCell, 6);
      expect(loop.steps.map((step) => step.cellIndex), [10, 11, 6, 5, 9, 8, 7]);
      expect(loop.steps.length, lessThanOrEqualTo(25));
    },
  );

  test('landing without three signals does not succeed', () {
    final mission = Mission.campaign(3).solvedCopy();
    final cells = mission.cells.toList();
    for (var index = 15; index <= 19; index++) {
      cells[index] = const MissionCell(baseMask: w | e);
    }
    final result = mission.copyWithCells(cells).launch();
    expect(result.failure, FlightFailure.missingStars);
    expect(result.failureCell, 19);
    expect(result.collectedStars.length, lessThan(3));
  });

  test('optional asteroid routes have deterministic attempt risk and safe alternatives', () {
    for (final number in [11, 15]) {
      final mission = Mission.campaign(number);
      final risk = mission.withRotations(mission.riskRouteRotations!);
      expect(risk.launch(ignoreRisk: true).success, isTrue);
      expect(
        risk.launch(ignoreRisk: true).steps.any((step) => step.cellIndex == 12),
        isTrue,
      );
      expect(mission.briefing, contains('${mission.cells[12].riskPercent}%'));
      var collisions = 0;
      var successes = 0;
      for (var attempt = 1; attempt <= 100; attempt++) {
        final first = risk.launch(attempt: attempt);
        final second = risk.launch(attempt: attempt);
        expect(first.success, second.success);
        expect(first.failure, second.failure);
        expect(
          first.steps.map((step) => step.cellIndex),
          second.steps.map((step) => step.cellIndex),
        );
        if (first.success) {
          successes++;
        } else {
          collisions++;
          expect(first.failure, FlightFailure.asteroidCollision);
          expect(first.failureCell, 12);
          expect(first.steps.last.cellIndex, 11);
        }
        expect(mission.solvedCopy().launch(attempt: attempt).success, isTrue);
      }
      expect(collisions, greaterThan(0));
      expect(successes, greaterThan(0));
    }
  });
}

List<Object> _cells(Mission mission) => [
  for (final cell in mission.cells)
    [
      cell.kind,
      cell.baseMask,
      cell.rotation,
      cell.baseInput,
      cell.portalPair,
      cell.riskPercent,
    ],
];
