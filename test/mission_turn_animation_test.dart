import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/mission.dart';
import 'package:glowpath/ui/design.dart';
import 'package:glowpath/ui/mission_board.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('relay visibly turns while its star badge stays upright', (
    tester,
  ) async {
    final key = GlobalKey<_BoardHarnessState>();
    await _show(tester, key);
    final before = await _pixels(tester, key.currentState!.index);
    key.currentState!.turn();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final halfway = await _pixels(tester, key.currentState!.index);
    await tester.pump(const Duration(milliseconds: 120));
    final settled = await _pixels(tester, key.currentState!.index);
    expect(_difference(before.bytes, halfway.bytes), greaterThan(.5));
    expect(_difference(halfway.bytes, settled.bytes), greaterThan(.5));
    expect(
      _centerPatch(halfway),
      orderedEquals(_centerPatch(before)),
      reason: 'The center star is a fixed badge, not part of the rotation.',
    );
    expect(
      key.currentState!.mission.cells[key.currentState!.index].rotation,
      1,
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid turns continue from the visible angle and wrap correctly',
    (tester) async {
      final key = GlobalKey<_BoardHarnessState>();
      await _show(tester, key);
      final initial = await _pixels(tester, key.currentState!.index);
      key.currentState!.turn();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final interrupted = await _pixels(tester, key.currentState!.index);
      key.currentState!.turn();
      await tester.pump();
      final continued = await _pixels(tester, key.currentState!.index);
      expect(
        _difference(interrupted.bytes, continued.bytes),
        lessThan(.7),
        reason: 'A second input must not snap the displayed path backwards.',
      );
      await tester.pump(const Duration(milliseconds: 40));
      key.currentState!.turn();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      key.currentState!.turn();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      final finalFrame = await _pixels(tester, key.currentState!.index);
      expect(
        key.currentState!.mission.cells[key.currentState!.index].rotation,
        0,
      );
      expect(_difference(initial.bytes, finalFrame.bytes), lessThan(.7));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final setting in ['app', 'system', 'disabled animations']) {
    testWidgets('$setting reduced motion changes orientation immediately', (
      tester,
    ) async {
      final key = GlobalKey<_BoardHarnessState>();
      await _show(
        tester,
        key,
        reduceMotion: setting == 'app',
        systemReduced: setting == 'system',
        disableAnimations: setting == 'disabled animations',
      );
      final before = await _pixels(tester, key.currentState!.index);
      key.currentState!.turn();
      await tester.pump();
      final immediate = await _pixels(tester, key.currentState!.index);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(milliseconds: 220));
      final later = await _pixels(tester, key.currentState!.index);
      expect(_difference(before.bytes, immediate.bytes), greaterThan(.5));
      expect(later.bytes, orderedEquals(immediate.bytes));
      expect(tester.takeException(), isNull);
    });
  }
}

class _BoardHarness extends StatefulWidget {
  const _BoardHarness({super.key, this.reduceMotion = false});
  final bool reduceMotion;
  @override
  State<_BoardHarness> createState() => _BoardHarnessState();
}

class _BoardHarnessState extends State<_BoardHarness> {
  late Mission mission;
  late int index;
  @override
  void initState() {
    super.initState();
    mission = Mission.campaign(3).solvedCopy();
    index = mission.starIndices.first;
    final cells = mission.cells.toList();
    cells[index] = const MissionCell(baseMask: 1 | 2);
    mission = mission.copyWithCells(cells);
  }

  void turn() => setState(() {
    final cells = mission.cells.toList();
    cells[index] = cells[index].rotated();
    mission = mission.copyWithCells(cells);
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: MissionBoard(
      mission: mission,
      enabled: true,
      reduceMotion: widget.reduceMotion,
      onTurn: (_) => turn(),
    ),
  );
}

Future<void> _show(
  WidgetTester tester,
  GlobalKey<_BoardHarnessState> key, {
  bool reduceMotion = false,
  bool systemReduced = false,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: gameTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          reduceMotion: systemReduced,
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Center(
            child: _BoardHarness(key: key, reduceMotion: reduceMotion),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _Frame {
  const _Frame(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width, height;
}

Future<_Frame> _pixels(WidgetTester tester, int index) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .descendant(
          of: find.byKey(ValueKey('mission-cell-$index')),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return _Frame(
        Uint8List.fromList(bytes!.buffer.asUint8List()),
        image.width,
        image.height,
      );
    } finally {
      image.dispose();
    }
  }))!;
}

double _difference(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference += (a[i] - b[i]).abs();
  }
  return difference / a.length;
}

List<int> _centerPatch(_Frame frame) => [
  for (var y = frame.height ~/ 2 - 4; y <= frame.height ~/ 2 + 4; y++)
    for (var x = frame.width ~/ 2 - 4; x <= frame.width ~/ 2 + 4; x++)
      for (var channel = 0; channel < 4; channel++)
        frame.bytes[(y * frame.width + x) * 4 + channel],
];
