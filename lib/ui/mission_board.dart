import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../game/mission.dart';
import 'design.dart';

const hazardGold = Color(0xFFF3C66C);
const hazardRed = Color(0xFFFF987D);
const portalViolet = Color(0xFFB9A1FF);

String cellRole(CellKind kind) => switch (kind) {
  CellKind.relay => 'Rotating route',
  CellKind.lockedRelay => 'Fixed route',
  CellKind.block => 'Blocked sector',
  CellKind.oneWay => 'One-way gate',
  CellKind.wormhole => 'Wormhole',
  CellKind.blackHole => 'Black hole gravity fork',
  CellKind.whiteHole => 'White hole gravity fork',
  CellKind.slingshot => 'Star slingshot',
  CellKind.asteroid => 'Asteroid risk',
};

Color cellAccent(CellKind kind) => switch (kind) {
  CellKind.wormhole => portalViolet,
  CellKind.blackHole || CellKind.whiteHole => const Color(0xFFECABE2),
  CellKind.slingshot => hazardGold,
  CellKind.asteroid || CellKind.block => hazardRed,
  _ => Palette.rust,
};

class MissionBoard extends StatelessWidget {
  const MissionBoard({
    super.key,
    required this.mission,
    required this.onTurn,
    required this.enabled,
    this.result,
    this.preview,
    this.flightProgress = 0,
    this.hintIndex,
    this.teachingIndex,
    this.showFailure = false,
    this.reduceMotion = false,
    this.onInspect,
  });
  final Mission mission;
  final ValueChanged<int> onTurn;
  final ValueChanged<int>? onInspect;
  final bool enabled, showFailure, reduceMotion;
  final FlightResult? result;
  final FlightResult? preview;
  final double flightProgress;
  final int? hintIndex;
  final int? teachingIndex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final extent = box.maxWidth;
      // A 320dp phone retains 48.8dp cells. Edge gates have separate rails.
      const rail = 14.0, gap = 4.0;
      final tile = (extent - rail * 2 - gap * 4) / 5;
      final visibleSteps = result == null
          ? (preview?.steps.map((step) => step.cellIndex).toSet() ?? <int>{})
          : result!.steps
                .take((result!.steps.length * flightProgress).ceil())
                .map((s) => s.cellIndex)
                .toSet();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.rocket_launch_rounded,
                  size: 19,
                  color: Palette.rust,
                ),
                const SizedBox(width: 6),
                const Text(
                  'LAUNCH',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: Palette.rust,
                  ),
                ),
                const Spacer(),
                if (mission.wrapEdges)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.compare_arrows_rounded,
                      size: 20,
                      color: portalViolet,
                    ),
                  ),
                const Text(
                  'DOCK',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: Palette.light,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.radio_button_checked,
                  size: 19,
                  color: Palette.light,
                ),
              ],
            ),
          ),
          SizedBox(
            key: const ValueKey('mission-board'),
            height: extent - rail * 2,
            width: extent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < mission.cells.length; index++)
                  Positioned(
                    left: rail + index % 5 * (tile + gap),
                    top: index ~/ 5 * (tile + gap),
                    width: tile,
                    height: tile,
                    child: _MissionCell(
                      key: ValueKey('mission-cell-$index'),
                      cell: mission.cells[index],
                      boardIdentity: mission.number,
                      reduceMotion:
                          reduceMotion ||
                          MediaQuery.disableAnimationsOf(context) ||
                          MediaQuery.reduceMotionOf(context),
                      index: index,
                      star: mission.starIndices.contains(index),
                      lit: visibleSteps.contains(index),
                      highlighted: hintIndex == index || teachingIndex == index,
                      teaching: teachingIndex == index,
                      failed: showFailure && result?.failureCell == index,
                      enabled:
                          enabled &&
                          (mission.cells[index].rotatable || onInspect != null),
                      onTap: () => mission.cells[index].rotatable
                          ? onTurn(index)
                          : onInspect?.call(index),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _MissionRoutePainter(
                        mission: mission,
                        result: result,
                        progress: flightProgress,
                        tile: tile,
                        failure: showFailure,
                        rail: rail,
                        gap: gap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _MissionCell extends StatefulWidget {
  const _MissionCell({
    super.key,
    required this.cell,
    required this.boardIdentity,
    required this.reduceMotion,
    required this.index,
    required this.star,
    required this.lit,
    required this.highlighted,
    this.teaching = false,
    required this.failed,
    required this.enabled,
    required this.onTap,
  });
  final MissionCell cell;
  final int index, boardIdentity;
  final bool star, lit, highlighted, failed, enabled, reduceMotion, teaching;
  final VoidCallback onTap;
  @override
  State<_MissionCell> createState() => _MissionCellState();
}

class _MissionCellState extends State<_MissionCell>
    with SingleTickerProviderStateMixin {
  bool focus = false;
  late final AnimationController _turn;
  late double _fromTurns, _targetTurns;

  double get _visibleTurns =>
      _fromTurns +
      (_targetTurns - _fromTurns) * Curves.easeOutCubic.transform(_turn.value);

  @override
  void initState() {
    super.initState();
    _fromTurns = _targetTurns = widget.cell.rotation.toDouble();
    _turn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _MissionCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final freshGeometry =
        oldWidget.boardIdentity != widget.boardIdentity ||
        oldWidget.cell.baseMask != widget.cell.baseMask ||
        oldWidget.cell.baseInput != widget.cell.baseInput ||
        oldWidget.cell.kind != widget.cell.kind;
    if (freshGeometry || !widget.cell.rotatable) {
      _turn.stop();
      _fromTurns = _targetTurns = widget.cell.rotation.toDouble();
      _turn.value = 1;
      return;
    }
    if (oldWidget.cell.rotation != widget.cell.rotation) {
      final visible = _visibleTurns;
      final delta = (widget.cell.rotation - oldWidget.cell.rotation) % 4;
      // Preserve an unwrapped target across 3→0 and interrupted animations.
      // Reverse a single undo instead of making it spin through three turns.
      _targetTurns += delta == 3 ? -1 : delta;
      _fromTurns = visible;
      if (widget.reduceMotion) {
        _turn.stop();
        _fromTurns = _targetTurns;
        _turn.value = 1;
      } else {
        _turn.forward(from: 0);
      }
    } else if (widget.reduceMotion && _turn.isAnimating) {
      _turn.stop();
      _fromTurns = _targetTurns;
      _turn.value = 1;
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cell;
    final portalLabel = String.fromCharCode(
      65 + math.min(widget.index, c.portalPair ?? widget.index),
    );
    const directionNames = {1: 'north', 2: 'east', 4: 'south', 8: 'west'};
    final dirs = [
      for (final entry in {1: 'up', 2: 'right', 4: 'down', 8: 'left'}.entries)
        if (c.connections & entry.key != 0) entry.value,
    ].join(', ');
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label:
          'Sector ${widget.index ~/ 5 + 1}, ${widget.index % 5 + 1}. ${cellRole(c.kind)}${c.kind == CellKind.wormhole ? ' $portalLabel' : ''}${widget.star ? '. Star beacon' : ''}',
      value:
          'Connections: $dirs${c.input != 0 ? '. Enter from ${directionNames[c.input]}; exit ${directionNames[c.output]}' : ''}${c.riskPercent > 0 ? '. Collision risk ${c.riskPercent} percent' : ''}${widget.failed ? '. Flight stopped here' : ''}',
      hint: widget.teaching
          ? 'Tutorial launch relay. Turn clockwise'
          : widget.highlighted
          ? 'Suggested route. Turn clockwise'
          : c.rotatable
          ? 'Turn clockwise'
          : 'Inspect flight rule',
      onTap: widget.enabled ? widget.onTap : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: widget.enabled,
          onShowFocusHighlight: (v) => setState(() => focus = v),
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? widget.onTap : null,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _turn,
                builder: (context, _) => CustomPaint(
                  painter: _CellPainter(
                    c,
                    widget.star,
                    widget.lit,
                    widget.highlighted || focus,
                    widget.failed,
                    (_visibleTurns - _targetTurns) * math.pi / 2,
                    portalLabel,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  const _CellPainter(
    this.cell,
    this.star,
    this.lit,
    this.highlight,
    this.failed,
    this.rotationOffset,
    this.portalLabel,
  );
  final MissionCell cell;
  final bool star, lit, highlight, failed;
  final double rotationOffset;
  final String portalLabel;
  @override
  void paint(Canvas c, Size s) {
    final r = s.shortestSide, center = s.center(Offset.zero);
    final accent = failed ? hazardRed : cellAccent(cell.kind);
    final panel = RRect.fromRectAndRadius(
      (Offset.zero & s).deflate(.5),
      const Radius.circular(6),
    );
    c.drawRRect(
      panel,
      Paint()..color = lit ? const Color(0xFF193D45) : const Color(0xED102237),
    );
    c.drawRRect(
      panel,
      Paint()
        ..color = highlight || failed
            ? accent
            : Palette.line.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlight || failed ? 2 : .7,
    );
    for (final p in [const Offset(4, 4), Offset(s.width - 4, s.height - 4)]) {
      c.drawCircle(
        p,
        1,
        Paint()..color = Palette.secondary.withValues(alpha: .28),
      );
    }
    if (cell.kind == CellKind.block) {
      for (var i = 0; i < 4; i++) {
        final a = i * 2.1;
        final pos = center + Offset(math.cos(a) * r * .2, math.sin(a) * r * .2);
        _rock(c, pos, r * (.09 + i * .013), hazardRed.withValues(alpha: .6));
      }
      c.drawLine(
        Offset(r * .22, r * .78),
        Offset(r * .78, r * .22),
        Paint()
          ..color = hazardRed.withValues(alpha: .55)
          ..strokeWidth = 1.5,
      );
      return;
    }
    // Rotate route geometry only. Labels, star badges, focus and failure
    // outlines are painted after restoring the canvas, so they stay upright.
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(rotationOffset);
    c.translate(-center.dx, -center.dy);
    final ink = Paint()
      ..color = lit ? Palette.rust : Palette.pipe
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const vectors = {
      1: Offset(0, -1),
      2: Offset(1, 0),
      4: Offset(0, 1),
      8: Offset(-1, 0),
    };
    for (final d in vectors.entries) {
      if (cell.connections & d.key != 0) {
        c.drawLine(
          center,
          center + d.value * r * .46,
          Paint()
            ..color = Palette.rust.withValues(alpha: lit ? .2 : .035)
            ..strokeWidth = r * .2,
        );
        c.drawLine(center, center + d.value * r * .46, ink);
      }
    }
    switch (cell.kind) {
      case CellKind.block:
        break;
      case CellKind.relay:
        if (!star) {
          c.drawCircle(center, r * .045, Paint()..color = Palette.paper);
        }
      case CellKind.lockedRelay:
        c.drawRect(
          Rect.fromCenter(center: center, width: r * .2, height: r * .17),
          Paint()..color = Palette.board,
        );
        c.drawRect(
          Rect.fromCenter(center: center, width: r * .15, height: r * .12),
          Paint()
            ..color = hazardGold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        c.drawArc(
          Rect.fromCenter(
            center: center - Offset(0, r * .06),
            width: r * .1,
            height: r * .12,
          ),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = hazardGold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case CellKind.oneWay:
        final out = vectors[cell.output] ?? const Offset(1, 0);
        final side = Offset(-out.dy, out.dx);
        c.drawCircle(center, r * .18, Paint()..color = Palette.board);
        c.drawPath(
          Path()
            ..moveTo((center + out * r * .13).dx, (center + out * r * .13).dy)
            ..lineTo(
              (center - out * r * .09 + side * r * .1).dx,
              (center - out * r * .09 + side * r * .1).dy,
            )
            ..lineTo(
              (center - out * r * .09 - side * r * .1).dx,
              (center - out * r * .09 - side * r * .1).dy,
            )
            ..close(),
          Paint()..color = Palette.rust,
        );
      case CellKind.wormhole:
        c.drawCircle(center, r * .22, Paint()..color = Palette.paper);
        for (var i = 0; i < 3; i++) {
          c.drawOval(
            Rect.fromCenter(
              center: center,
              width: r * (.42 - i * .1),
              height: r * (.28 - i * .06),
            ),
            Paint()
              ..color = portalViolet.withValues(alpha: 1 - i * .2)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      case CellKind.blackHole || CellKind.whiteHole:
        c.drawCircle(
          center,
          r * .2,
          Paint()
            ..color = cell.kind == CellKind.blackHole
                ? Colors.black
                : Palette.white,
        );
        c.drawOval(
          Rect.fromCenter(center: center, width: r * .53, height: r * .26),
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        c.drawArc(
          Rect.fromCircle(center: center, radius: r * .29),
          -.8,
          2.4,
          false,
          Paint()
            ..color = accent.withValues(alpha: .6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case CellKind.slingshot:
        c.drawArc(
          Rect.fromCircle(center: center, radius: r * .31),
          -.7,
          4.6,
          false,
          Paint()
            ..color = hazardGold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
      case CellKind.asteroid:
        break;
    }
    if (cell.kind == CellKind.wormhole || cell.kind == CellKind.slingshot) {
      final heading = vectors[cell.output] ?? const Offset(1, 0);
      final side = Offset(-heading.dy, heading.dx);
      final arrow = center + heading * r * .38;
      c.drawPath(
        Path()
          ..moveTo(
            (arrow + heading * r * .09).dx,
            (arrow + heading * r * .09).dy,
          )
          ..lineTo(
            (arrow - heading * r * .06 + side * r * .07).dx,
            (arrow - heading * r * .06 + side * r * .07).dy,
          )
          ..lineTo(
            (arrow - heading * r * .06 - side * r * .07).dx,
            (arrow - heading * r * .06 - side * r * .07).dy,
          )
          ..close(),
        Paint()..color = cellAccent(cell.kind),
      );
    }
    c.restore();
    if (cell.kind == CellKind.wormhole) {
      _label(
        c,
        portalLabel,
        center + Offset(r * .29, -r * .28),
        r * .17,
        portalViolet,
      );
    } else if (cell.kind == CellKind.slingshot) {
      _star(c, center, r * .18, hazardGold);
    } else if (cell.kind == CellKind.asteroid) {
      _rock(c, center + Offset(r * .23, -r * .23), r * .09, hazardRed);
      _label(
        c,
        '${cell.riskPercent}%',
        center + Offset(0, r * .28),
        r * .16,
        hazardRed,
      );
    }
    if (star && cell.kind != CellKind.slingshot) {
      final badge = cell.kind == CellKind.relay
          ? center
          : center + Offset(-r * .29, -r * .28);
      final badgeSize = cell.kind == CellKind.relay ? r * .13 : r * .105;
      c.drawCircle(badge, badgeSize * 1.25, Paint()..color = Palette.board);
      _star(c, badge, badgeSize, lit ? hazardGold : Palette.secondary);
    }
    if (failed) {
      c.drawCircle(
        center,
        r * .38,
        Paint()
          ..color = hazardRed
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _rock(Canvas c, Offset center, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = i / 6 * math.pi * 2;
      final p =
          center + Offset(math.cos(a), math.sin(a)) * r * (i.isEven ? 1 : .72);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  void _star(Canvas c, Offset center, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final p =
          center + Offset(math.cos(a), math.sin(a)) * r * (i.isEven ? 1 : .46);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  void _label(Canvas c, String label, Offset center, double size, Color color) {
    final t = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Atkinson',
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, center - Offset(t.width / 2, t.height / 2));
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      cell != old.cell ||
      star != old.star ||
      lit != old.lit ||
      highlight != old.highlight ||
      failed != old.failed ||
      portalLabel != old.portalLabel ||
      rotationOffset != old.rotationOffset;
}

class _MissionRoutePainter extends CustomPainter {
  const _MissionRoutePainter({
    required this.mission,
    required this.result,
    required this.progress,
    required this.tile,
    required this.rail,
    required this.gap,
    required this.failure,
  });
  final Mission mission;
  final FlightResult? result;
  final double progress, tile, rail, gap;
  final bool failure;
  Offset point(int i) => Offset(
    rail + i % 5 * (tile + gap) + tile / 2,
    i ~/ 5 * (tile + gap) + tile / 2,
  );
  @override
  void paint(Canvas c, Size s) {
    final start = Offset(rail / 2, point(mission.startRow * 5).dy);
    final end = Offset(s.width - rail / 2, point(mission.endRow * 5 + 4).dy);
    c.drawPath(
      Path()
        ..moveTo(start.dx + 6, start.dy)
        ..lineTo(start.dx - 5, start.dy - 5)
        ..lineTo(start.dx - 3, start.dy)
        ..lineTo(start.dx - 5, start.dy + 5)
        ..close(),
      Paint()..color = Palette.rust,
    );
    c.drawCircle(
      end,
      4,
      Paint()
        ..color = Palette.light
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    if (mission.wrapEdges) {
      final p = Paint()
        ..color = portalViolet.withValues(alpha: .7)
        ..strokeWidth = 1.5;
      for (var i = 0; i < 5; i++) {
        if (i != mission.startRow) {
          c.drawLine(
            Offset(0, point(i * 5).dy - 4),
            Offset(0, point(i * 5).dy + 4),
            p,
          );
        }
        if (i != mission.endRow) {
          c.drawLine(
            Offset(s.width, point(i * 5).dy - 4),
            Offset(s.width, point(i * 5).dy + 4),
            p,
          );
        }
        c.drawLine(Offset(point(i).dx - 4, -3), Offset(point(i).dx + 4, -3), p);
        c.drawLine(
          Offset(point(i).dx - 4, s.height + 3),
          Offset(point(i).dx + 4, s.height + 3),
          p,
        );
      }
    }
    if (result == null || result!.steps.isEmpty || progress <= 0) return;
    final steps = result!.steps;
    final legs = steps.length + (result!.success ? 1 : 0);
    final distance = progress.clamp(0.0, 1.0) * legs;
    final segment = math.min(distance.floor(), legs - 1);
    final t = distance - segment;
    final a = segment == 0 ? start : point(steps[segment - 1].cellIndex);
    final b = segment == steps.length ? end : point(steps[segment].cellIndex);
    final special =
        segment > 0 &&
        steps[segment - 1].transition != FlightTransition.adjacent;
    final pos = special ? (t < .5 ? a : b) : Offset.lerp(a, b, t)!;
    final direction = (b - a).direction;
    for (var i = 0; i < segment; i++) {
      if (steps[i].transition == FlightTransition.adjacent &&
          i + 1 < steps.length) {
        c.drawLine(
          point(steps[i].cellIndex),
          point(steps[i + 1].cellIndex),
          Paint()
            ..color = Palette.rust.withValues(alpha: .2)
            ..strokeWidth = 3,
        );
      }
    }
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(direction);
    final r = tile * .25;
    if (!failure) {
      c.drawPath(
        Path()
          ..moveTo(-r * .5, -r * .2)
          ..quadraticBezierTo(-r * 1.7, 0, -r * .5, r * .2)
          ..close(),
        Paint()..color = hazardGold,
      );
      c.drawCircle(
        Offset.zero,
        r * .7,
        Paint()
          ..color = Palette.rust.withValues(alpha: .13)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    c.drawPath(
      Path()
        ..moveTo(r * .8, 0)
        ..quadraticBezierTo(0, -r * .6, -r * .6, -r * .3)
        ..lineTo(-r * .6, r * .3)
        ..quadraticBezierTo(0, r * .6, r * .8, 0)
        ..close(),
      Paint()..color = failure ? hazardRed : Palette.white,
    );
    c.drawCircle(Offset(r * .1, 0), r * .18, Paint()..color = Palette.board);
    c.restore();
    if (failure) {
      c.drawCircle(
        pos,
        tile * .36,
        Paint()
          ..color = hazardRed
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_MissionRoutePainter old) =>
      mission != old.mission ||
      result != old.result ||
      progress != old.progress ||
      failure != old.failure;
}
