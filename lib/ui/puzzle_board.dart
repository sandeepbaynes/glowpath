import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/puzzle.dart';
import '../game/cargo.dart';
import 'cargo_art.dart';
import 'cargo_pickup.dart';
import 'design.dart';
import 'route_drag_surface.dart';
import 'wormhole_transfer.dart';

class PuzzleBoard extends StatelessWidget {
  const PuzzleBoard({
    super.key,
    required this.puzzle,
    required this.status,
    required this.onTurn,
    this.onTraceStart,
    this.onTraceUpdate,
    this.onTraceEnd,
    this.onTraceCancel,
    this.onTraceRejected,
    required this.reduceMotion,
    required this.highContrast,
    this.teachEntrance = false,
    this.enabled = true,
    this.hintedIndex,
    this.teachingIndex,
    this.completionProgress = 0,
    this.compact = false,
    this.showLabels = true,
    this.trailColor = Palette.light,
    this.cargoKind,
    this.collectCargo = false,
  });
  final Puzzle puzzle;
  final PuzzleStatus status;
  final ValueChanged<int> onTurn;
  final bool Function()? onTraceStart;
  final bool Function(List<int>)? onTraceUpdate;
  final VoidCallback? onTraceEnd, onTraceCancel, onTraceRejected;
  final bool reduceMotion, highContrast, teachEntrance, enabled;
  final int? hintedIndex, teachingIndex;
  final double completionProgress;
  final bool compact, showLabels;
  final Color trailColor;
  final CargoKind? cargoKind;
  final bool collectCargo;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final extent = constraints.maxWidth;
      final rail = compact ? 11.0 : 15.0;
      const gap = 3.0;
      final tileExtent =
          (extent - 2 - rail * 2 - gap * (puzzle.size - 1)) / puzzle.size;
      final wormholeHops = activeWormholeHops(puzzle, status);
      final wormholePorts = <int, int>{
        for (final hop in wormholeHops) hop.entrance: hop.inlet,
        for (final hop in wormholeHops) hop.exit: hop.outlet,
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLabels) PuzzleLegend(status: status, compact: compact),
          RepaintBoundary(
            child: Container(
              key: const ValueKey('puzzle-board'),
              width: extent,
              height: extent,
              decoration: BoxDecoration(
                color: Palette.board,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: highContrast
                      ? Palette.secondary
                      : Palette.secondary.withValues(alpha: .14),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x45000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: _PortRailPainter(
                          startRow: puzzle.startRow,
                          endRow: puzzle.endRow,
                          tile: tileExtent,
                          rail: rail,
                          solved: status.solved,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(rail),
                    child: RouteDragSurface(
                      gridSize: puzzle.size,
                      enabled: enabled,
                      reduceMotion: reduceMotion,
                      accent: trailColor,
                      onStart: onTraceStart,
                      onUpdate: onTraceUpdate,
                      onEnd: onTraceEnd,
                      onCancel: onTraceCancel,
                      onRejected: onTraceRejected,
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: puzzle.tiles.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: puzzle.size,
                                crossAxisSpacing: gap,
                                mainAxisSpacing: gap,
                              ),
                          itemBuilder: (context, index) => PipeTile(
                            key: ValueKey('tile-$index'),
                            tile: puzzle.visualTileAt(index),
                            index: index,
                            gridSize: puzzle.size,
                            lit: status.litCells.contains(index),
                            weaponArmed: status.route
                                .where(
                                  (cell) =>
                                      puzzle.tiles[cell].kind ==
                                          TileKind.disarm &&
                                      puzzle.tiles[cell].circuit ==
                                          puzzle.tiles[index].circuit,
                                )
                                .length
                                .isEven,
                            litPorts: status.litPorts[index] ?? 0,
                            wormholePorts: wormholePorts[index],
                            wormholeExit: wormholeHops.any(
                              (hop) => hop.exit == index,
                            ),
                            couplingSize: puzzle.tiles
                                .where(
                                  (tile) =>
                                      tile.couplingGroup > 0 &&
                                      tile.couplingGroup ==
                                          puzzle.tiles[index].couplingGroup,
                                )
                                .length,
                            star: puzzle.starIndices.contains(index),
                            cargo: puzzle.cargoCell == index ? cargoKind : null,
                            hideCargo:
                                status.solved && collectCargo && !reduceMotion,
                            entrance: index == puzzle.startRow * puzzle.size,
                            exit:
                                index ==
                                puzzle.endRow * puzzle.size + puzzle.size - 1,
                            teach:
                                teachEntrance &&
                                index ==
                                    (teachingIndex ??
                                        puzzle.startRow * puzzle.size),
                            hinted: index == hintedIndex,
                            enabled: enabled && !status.solved,
                            reduceMotion: reduceMotion,
                            highContrast: highContrast,
                            onTurn: () => onTurn(index),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: WormholeTransfer(
                      key: ValueKey((
                        'wormhole-links',
                        puzzle.seed,
                        puzzle.levelNumber,
                        puzzle.label,
                        puzzle.size,
                      )),
                      hops: wormholeHops,
                      tileExtent: tileExtent,
                      rail: rail,
                      gridSize: puzzle.size,
                      reduceMotion: reduceMotion,
                      highContrast: highContrast,
                    ),
                  ),
                  if (status.solved &&
                      !reduceMotion &&
                      completionProgress > 0 &&
                      completionProgress < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            painter: RouteArrivalPainter(
                              cells: status.route.isNotEmpty
                                  ? status.route
                                  : status.litCells.toList(),
                              tile: tileExtent,
                              rail: rail,
                              progress: completionProgress,
                              gridSize: puzzle.size,
                              trailColor: trailColor,
                              cargoKind: collectCargo ? cargoKind : null,
                              cargoCell: puzzle.cargoCell,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Board orientation and progress can sit alongside the grid in a short
/// landscape viewport without duplicating its screen-reader announcements.
class PuzzleLegend extends StatelessWidget {
  const PuzzleLegend({super.key, required this.status, this.compact = false});
  final PuzzleStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final largeText =
        !compact && MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final stars = Semantics(
      key: const ValueKey('star-status'),
      liveRegion: true,
      label: '${status.collectedStars.length} of 3 stars collected',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: StarMark(
                size: compact ? 16 : 21,
                filled: i < status.collectedStars.length,
                color: i < status.collectedStars.length
                    ? Palette.light
                    : Palette.secondary,
              ),
            ),
          ),
        ),
      ),
    );
    final row = Row(
      children: [
        Expanded(child: _PortLabel(start: true, compact: compact)),
        if (!largeText) stars,
        Expanded(child: _PortLabel(start: false, compact: compact)),
      ],
    );
    if (compact) {
      // Instrument labels keep a single line; their complete meanings remain
      // available in semantics. Game tiles retain their original touch sizes.
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: 1.25),
        ),
        child: SizedBox(
          height: 24,
          child: Padding(padding: const EdgeInsets.only(bottom: 4), child: row),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 10), child: row),
        if (largeText)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Center(child: stars),
          ),
      ],
    );
  }
}

class _PortLabel extends StatelessWidget {
  const _PortLabel({required this.start, this.compact = false});
  final bool start, compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: start ? 'Start. Cyan START tile on the left edge.' : 'Finish. Gold FINISH beacon on the right edge after collecting all three stars.',
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: start
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (start) ...[
            Icon(
              Icons.rocket_launch_rounded,
              color: Palette.rust,
              size: compact ? 16 : 21,
            ),
            SizedBox(width: compact ? 4 : 6),
          ],
          Flexible(
            child: Text(
              start ? 'START' : 'FINISH',
              style: TextStyle(
                fontSize: compact ? 12 : 15,
                height: compact ? 1.1 : null,
                fontWeight: FontWeight.w600,
                color: start ? Palette.rust : Palette.light,
              ),
            ),
          ),
          if (!start) ...[
            SizedBox(width: compact ? 4 : 6),
            Icon(
              Icons.adjust_rounded,
              color: Palette.light,
              size: compact ? 16 : 22,
            ),
          ],
        ],
      ),
    ),
  );
}

class _PortRailPainter extends CustomPainter {
  const _PortRailPainter({
    required this.startRow,
    required this.endRow,
    required this.tile,
    required this.solved,
    required this.rail,
  });
  final int startRow, endRow;
  final double tile, rail;
  final bool solved;
  @override
  void paint(Canvas canvas, Size size) {
    final startY = rail + 1 + startRow * (tile + 3) + tile / 2;
    final endY = rail + 1 + endRow * (tile + 3) + tile / 2;
    void gateway(double x, double y, Color color, bool arrival) {
      final center = Offset(x, y);
      final aperture = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 7, height: 22),
        const Radius.circular(3.5),
      );
      canvas.drawCircle(
        center,
        10,
        Paint()
          ..color = color.withValues(alpha: .09)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawRRect(aperture, Paint()..color = Palette.paper);
      canvas.drawRRect(
        aperture,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color,
      );
      canvas.drawLine(
        Offset(arrival ? size.width - rail - 1 : x + 4, y),
        Offset(arrival ? x - 4 : rail + 1, y),
        Paint()
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: .7),
      );
      if (!arrival || solved) {
        canvas.drawCircle(center, 1.5, Paint()..color = Palette.white);
      }
    }

    gateway(rail / 2, startY, Palette.rust, false);
    gateway(size.width - rail / 2, endY, Palette.light, true);
  }

  @override
  bool shouldRepaint(_PortRailPainter old) =>
      startRow != old.startRow ||
      endRow != old.endRow ||
      tile != old.tile ||
      rail != old.rail ||
      solved != old.solved;
}

class PipeTile extends StatefulWidget {
  const PipeTile({
    super.key,
    required this.tile,
    required this.index,
    this.gridSize = 5,
    required this.lit,
    this.litPorts = 0,
    this.couplingSize = 0,
    this.weaponArmed = true,
    this.wormholePorts,
    this.wormholeExit = false,
    required this.star,
    this.cargo,
    this.hideCargo = false,
    required this.entrance,
    required this.exit,
    required this.teach,
    this.hinted = false,
    required this.enabled,
    required this.reduceMotion,
    required this.highContrast,
    required this.onTurn,
  });
  final Tile tile;
  final CargoKind? cargo;
  final bool hideCargo;
  final int index;
  final int gridSize;
  final int litPorts, couplingSize;
  final bool weaponArmed;
  final int? wormholePorts;
  final bool wormholeExit;
  final bool lit,
      star,
      entrance,
      exit,
      teach,
      enabled,
      reduceMotion,
      highContrast;
  final bool hinted;
  final VoidCallback onTurn;
  @override
  State<PipeTile> createState() => _PipeTileState();
}

class _PipeTileState extends State<PipeTile> {
  late double _turns = widget.tile.routeRotation / 4;
  bool _focused = false;

  @override
  void didUpdateWidget(PipeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    var delta = widget.tile.routeRotation - oldWidget.tile.routeRotation;
    if (delta > 2) delta -= 4;
    if (delta < -2) delta += 4;
    _turns += delta / 4;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !widget.tile.isLocked;
    // Numbered gravity/defense marks need the top corner to themselves on a
    // 48px tile; their coupled-group identifier uses the opposite corner.
    final lowerGroupTag =
        !widget.entrance &&
        !widget.exit &&
        const [
          TileKind.blackHole,
          TileKind.whiteHole,
          TileKind.weapon,
          TileKind.disarm,
        ].contains(widget.tile.kind);
    final showFocus =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final visiblePorts = widget.wormholePorts ?? widget.tile.connections;
    final directions = [
      if (visiblePorts & north != 0) 'up',
      if (visiblePorts & east != 0) 'right',
      if (visiblePorts & south != 0) 'down',
      if (visiblePorts & west != 0) 'left',
    ].join(' and ');
    final rule = widget.wormholeExit && widget.tile.portalPeer != null
        ? 'Arrives from row ${widget.tile.portalPeer! ~/ widget.gridSize + 1}, column ${widget.tile.portalPeer! % widget.gridSize + 1}. Follow the exit arrow.'
        : _tileRule(widget.tile, widget.gridSize, widget.couplingSize);
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label:
          'Tile ${widget.index ~/ widget.gridSize + 1}, ${widget.index % widget.gridSize + 1}${widget.entrance ? ', entrance, START rocket' : ''}${widget.exit ? ', exit, FINISH dock' : ''}${widget.star ? ', star' : ''}${widget.cargo == null ? '' : ', optional ${widget.cargo!.label}, not required to win'}, ${widget.tile.mechanicLabel}${widget.tile.isLocked ? ', fixed relay' : ''}${widget.tile.isOneWay ? ', one-way relay' : ''}',
      value:
          'Connects $directions. $rule ${widget.tile.kind == TileKind.weapon
              ? widget.lit
                    ? 'Weapon passed safely. '
                    : !widget.weaponArmed
                    ? 'Weapon disabled by its switch. '
                    : 'Weapon is armed. '
              : ''}${widget.tile.isOneWay && !widget.wormholeExit ? 'Light must enter from ${_directionName(widget.tile.entryDirection)}. ' : ''}${widget.lit ? 'Light is flowing' : 'Unlit'}${widget.tile.kind == TileKind.wormhole && widget.wormholePorts != null
              ? widget.wormholeExit
                    ? '. Light emerges here from the paired hole'
                    : '. Light enters this hole and travels to its pair'
              : ''}${widget.star && widget.lit ? '. Star collected' : ''}',
      hint: widget.tile.isLocked
          ? 'Fixed relay. Plan the route around its orientation.'
          : enabled
          ? (widget.hinted
                ? 'Suggested relay. Turn clockwise'
                : widget.teach
                ? 'Tutorial relay. Turn clockwise'
                : 'Turn clockwise')
          : 'Route complete',
      onTap: enabled ? widget.onTurn : null,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? widget.onTurn : null,
              autofocus: false,
              canRequestFocus: enabled,
              onFocusChange: (value) => setState(() => _focused = value),
              borderRadius: BorderRadius.circular(12),
              splashFactory: NoSplash.splashFactory,
              hoverColor: Palette.rust.withValues(alpha: .055),
              focusColor: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: widget.lit ? 1 : 0),
                duration: widget.reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                builder: (context, light, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: widget.highContrast ? Palette.paper : Palette.tile,
                    gradient: widget.highContrast
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(
                                Palette.tile,
                                Palette.rust,
                                .025 + light * .035,
                              )!,
                              Color.lerp(
                                Palette.board,
                                Palette.rust,
                                light * .025,
                              )!,
                            ],
                          ),
                    border: Border.all(
                      color: showFocus || widget.teach || widget.hinted
                          ? Palette.rust
                          : Palette.secondary.withValues(
                              alpha: .055 + light * .07,
                            ),
                      width: showFocus || widget.teach || widget.hinted ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedRotation(
                            turns: _turns,
                            duration: widget.reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 270),
                            curve: Curves.easeOutBack,
                            child: CustomPaint(
                              painter: PipePainter(
                                mask: widget.tile.baseMask,
                                light: light,
                                highContrast: widget.highContrast,
                                oneWayEntry: widget.tile.oneWayEntry,
                                kind: widget.tile.kind,
                                wormholePorts: widget.wormholePorts == null
                                    ? null
                                    : _localMask(
                                        widget.wormholePorts!,
                                        widget.tile.routeRotation,
                                      ),
                                litMask: widget.litPorts == 0
                                    ? (widget.lit ? widget.tile.baseMask : 0)
                                    : _localMask(
                                        widget.litPorts,
                                        widget.tile.routeRotation,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.cargo != null && !widget.hideCargo)
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, bounds) => Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Palette.paper.withValues(alpha: .8),
                                  shape: BoxShape.circle,
                                ),
                                child: CargoMark(
                                  kind: widget.cargo!,
                                  size: (bounds.maxWidth * .46).clamp(
                                    28.0,
                                    54.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.star)
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, bounds) => Align(
                              alignment: widget.tile.kind == TileKind.wormhole
                                  ? Alignment.bottomLeft
                                  : Alignment.center,
                              child: Padding(
                                padding: EdgeInsets.all(
                                  widget.tile.kind == TileKind.wormhole ? 2 : 0,
                                ),
                                child: SizedBox.square(
                                  key: ValueKey('tile-star-${widget.index}'),
                                  dimension:
                                      widget.tile.kind == TileKind.wormhole
                                      ? (bounds.maxWidth * .20).clamp(
                                          14.0,
                                          22.0,
                                        )
                                      : (bounds.maxWidth * .26).clamp(
                                          25.0,
                                          38.0,
                                        ),
                                  child: CustomPaint(
                                    painter: _StarPickupPainter(
                                      light: light,
                                      highContrast: widget.highContrast,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.highContrast && widget.lit)
                        const Positioned(
                          right: 4,
                          bottom: 4,
                          child: Icon(
                            Icons.circle,
                            size: 5,
                            color: Palette.light,
                          ),
                        ),
                      if (widget.entrance || widget.exit)
                        Positioned(
                          left: 3,
                          right: 3,
                          bottom: 3,
                          child: _EndpointBadge(start: widget.entrance),
                        ),
                      if (widget.tile.couplingGroup > 0)
                        Positioned(
                          left: 3,
                          top: lowerGroupTag ? null : 3,
                          bottom: lowerGroupTag ? 3 : null,
                          child: _MechanicTag(
                            icon: Icons.link_rounded,
                            label:
                                '${widget.couplingSize}${String.fromCharCode(64 + widget.tile.couplingGroup)}',
                            color: const Color(0xFFD6AEFF),
                          ),
                        ),
                      if (widget.tile.kind != TileKind.relay ||
                          widget.tile.isLocked)
                        Positioned(
                          right: 3,
                          top: 3,
                          child: _MechanicTag.forTile(
                            widget.tile,
                            widget.index,
                            armed: widget.weaponArmed,
                            cleared: widget.lit,
                          ),
                        ),
                      if (widget.tile.gravityPeer != null)
                        Positioned(
                          left: 3,
                          bottom: 3,
                          child: _MechanicTag(
                            icon: Icons.rotate_right_rounded,
                            label: 'G${widget.tile.gravityPeer! + 1}',
                            color: const Color(0xFFD6AEFF),
                          ),
                        ),
                    ],
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

class _StarPickupPainter extends CustomPainter {
  const _StarPickupPainter({required this.light, required this.highContrast});
  final double light;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .46;
    final disc = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.5),
          colors: [
            Color.lerp(Palette.tile, Palette.light, light * .12)!,
            Palette.paper,
          ],
        ).createShader(disc),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highContrast ? 1.4 : .8
        ..color = Palette.light.withValues(alpha: .25 + light * .5),
    );
    final star = Path();
    for (var point = 0; point < 10; point++) {
      final angle = -math.pi / 2 + point * math.pi / 5;
      final r = radius * (point.isEven ? .66 : .3);
      final position = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (point == 0) {
        star.moveTo(position.dx, position.dy);
      } else {
        star.lineTo(position.dx, position.dy);
      }
    }
    star.close();
    canvas.drawPath(
      star,
      Paint()
        ..color = Palette.light.withValues(alpha: .12 + light * .88)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      star,
      Paint()
        ..color = Color.lerp(Palette.light, Palette.white, light * .65)!
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = highContrast ? 1.5 : 1.15,
    );
  }

  @override
  bool shouldRepaint(_StarPickupPainter old) =>
      light != old.light || highContrast != old.highContrast;
}

class _EndpointBadge extends StatelessWidget {
  const _EndpointBadge({required this.start});
  final bool start;

  @override
  Widget build(BuildContext context) {
    final color = start ? Palette.rust : Palette.light;
    return LayoutBuilder(
      builder: (context, bounds) {
        final extent = bounds.maxWidth;
        final font = (extent * .11).clamp(8.0, 13.0);
        final glyph = (extent * .15).clamp(10.0, 19.0);
        return Align(
          alignment: start ? Alignment.centerLeft : Alignment.centerRight,
          child: DecoratedBox(
            key: ValueKey(start ? 'launch-marker' : 'dock-marker'),
            decoration: BoxDecoration(
              color: Palette.paper.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: .28),
                width: .75,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      start
                          ? Icons.rocket_launch_outlined
                          : Icons.adjust_rounded,
                      size: glyph,
                      color: color,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      start ? 'START' : 'FINISH',
                      style: TextStyle(
                        color: color,
                        fontSize: font,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        letterSpacing: .7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MechanicTag extends StatelessWidget {
  const _MechanicTag({
    required this.icon,
    required this.label,
    required this.color,
    this.tile,
  });
  factory _MechanicTag.forTile(
    Tile tile,
    int index, {
    bool armed = true,
    bool cleared = false,
  }) {
    final kind = tile.kind;
    final icon = tile.isLocked
        ? Icons.lock_rounded
        : switch (kind) {
            TileKind.bridge || TileKind.crossway || TileKind.fork => null,
            TileKind.blackHole => Icons.blur_circular_rounded,
            TileKind.whiteHole => Icons.flare_rounded,
            TileKind.wormhole => Icons.all_inclusive_rounded,
            TileKind.weapon =>
              cleared || !armed
                  ? Icons.verified_user_rounded
                  : Icons.gps_fixed_rounded,
            TileKind.disarm => Icons.power_settings_new_rounded,
            TileKind.shield => Icons.shield_rounded,
            TileKind.relay => Icons.lock_rounded,
          };
    final color = switch (kind) {
      TileKind.blackHole || TileKind.fork => const Color(0xFFD6AEFF),
      TileKind.whiteHole => Palette.white,
      TileKind.weapon =>
        cleared || !armed ? Palette.rust : const Color(0xFFFFAD97),
      TileKind.wormhole || TileKind.disarm || TileKind.shield => Palette.rust,
      _ => Palette.light,
    };
    final label = switch (kind) {
      TileKind.blackHole || TileKind.whiteHole => 'G${index + 1}',
      TileKind.wormhole =>
        tile.portalPeer == null
            ? '?'
            : 'W${math.min(index, tile.portalPeer!) + 1}',
      TileKind.weapon || TileKind.disarm => '${tile.circuit}',
      _ => '',
    };
    return _MechanicTag(
      icon: icon,
      label: label,
      color: color,
      tile: icon == null ? tile : null,
    );
  }
  final IconData? icon;
  final Tile? tile;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
    decoration: BoxDecoration(
      color: Palette.paper.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: .22), width: .65),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tile != null)
          RouteMechanicGlyph(
            kind: tile!.kind,
            color: color,
            size: 14,
            quarterTurns: tile!.routeRotation,
            inlet: tile!.oneWayEntry,
            ports: tile!.baseMask,
          )
        else
          Icon(icon, size: 11, color: color),
        if (label.isNotEmpty)
          Text(
            label,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: color,
              fontSize: 8,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    ),
  );
}

/// Glowpath's own channel symbols, matching the lanes on the board. These are
/// used at tile-badge size and in the field guide rather than system icons.
class RouteMechanicGlyph extends StatelessWidget {
  const RouteMechanicGlyph({
    super.key,
    required this.kind,
    this.color = Palette.light,
    this.size = 22,
    this.quarterTurns = 0,
    this.inlet = 0,
    this.ports = north | east | west,
  });
  final TileKind kind;
  final Color color;
  final double size;
  final int quarterTurns, inlet, ports;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: RouteMechanicPainter(
          kind: kind,
          color: color,
          quarterTurns: quarterTurns,
          inlet: inlet,
          ports: ports,
        ),
      ),
    ),
  );
}

class RouteMechanicPainter extends CustomPainter {
  const RouteMechanicPainter({
    required this.kind,
    required this.color,
    this.quarterTurns = 0,
    this.inlet = 0,
    this.ports = north | east | west,
  });
  final TileKind kind;
  final Color color;
  final int quarterTurns, inlet, ports;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.translate(12, 12);
    canvas.rotate(quarterTurns * math.pi / 2);
    canvas.translate(-12, -12);
    final lane = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const ends = {
      north: Offset(12, 2),
      east: Offset(22, 12),
      south: Offset(12, 22),
      west: Offset(2, 12),
    };
    switch (kind) {
      case TileKind.bridge:
        // One unbroken deck crosses above the other. The dark separation
        // belongs to the glyph, so it remains legible on any background.
        canvas.drawLine(ends[north]!, ends[south]!, lane);
        canvas.drawLine(
          ends[west]!,
          ends[east]!,
          Paint()
            ..color = Palette.paper
            ..strokeWidth = 6.5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(ends[west]!, ends[east]!, lane);
        break;
      case TileKind.crossway:
        final upper = Path()
          ..moveTo(12, 2)
          ..lineTo(12, 5)
          ..quadraticBezierTo(12, 12, 19, 12)
          ..lineTo(22, 12);
        final lower = Path()
          ..moveTo(12, 22)
          ..lineTo(12, 19)
          ..quadraticBezierTo(12, 12, 5, 12)
          ..lineTo(2, 12);
        canvas.drawPath(upper, lane);
        canvas.drawPath(lower, lane);
        break;
      case TileKind.fork:
        for (final entry in ends.entries) {
          if (ports & entry.key != 0) {
            canvas.drawLine(entry.value, const Offset(12, 12), lane);
          }
        }
        canvas.drawCircle(const Offset(12, 12), 2.6, Paint()..color = color);
        break;
      default:
        break;
    }
    if (inlet != 0 && ends.containsKey(inlet)) {
      final outside = ends[inlet]!;
      final toward = (const Offset(12, 12) - outside) / 10;
      final side = Offset(-toward.dy, toward.dx);
      final tip = outside + toward * 5;
      final left = tip - toward * 2.5 + side * 2;
      final right = tip - toward * 2.5 - side * 2;
      // An arrow at the entry distinguishes directional crossings
      // while the full-size channel retains its own matching flow arrow.
      canvas.drawPath(
        Path()
          ..moveTo(left.dx, left.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(right.dx, right.dy),
        Paint()
          ..color = Palette.paper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        Path()
          ..moveTo(left.dx, left.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(right.dx, right.dy),
        lane..strokeWidth = 1.7,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RouteMechanicPainter old) =>
      kind != old.kind ||
      color != old.color ||
      quarterTurns != old.quarterTurns ||
      inlet != old.inlet ||
      ports != old.ports;
}

String _tileRule(Tile tile, int size, int couplingSize) {
  final rule = switch (tile.kind) {
    TileKind.bridge =>
      'Two independent straight lanes cross at different heights.',
    TileKind.crossway =>
      'Two separate bends join adjacent edges; they never join each other.',
    TileKind.fork => 'The marked gravity source selects the fork branch.',
    TileKind.blackHole =>
      'Pull fork: prefer a right turn, then straight, then left.',
    TileKind.whiteHole =>
      'Push fork: prefer a left turn, then straight, then right.',
    TileKind.wormhole =>
      tile.portalPeer == null
          ? 'Wormhole has no matching exit.'
          : 'Teleports to row ${tile.portalPeer! ~/ size + 1}, column ${tile.portalPeer! % size + 1}. Follow the exit arrow.',
    TileKind.weapon =>
      'Weapon circuit ${tile.circuit}. Cross its matching switch first, or collect a shield.',
    TileKind.disarm =>
      'Toggles weapon circuit ${tile.circuit}. Route through this switch before the weapon.',
    TileKind.shield =>
      'Charges a shield that protects against one armed weapon.',
    TileKind.relay => '',
  };
  return '$rule${tile.couplingGroup > 0 ? ' Linked group ${tile.couplingGroup}: all $couplingSize matching tiles turn together.' : ''}${tile.gravityPeer != null ? ' Gravity link G${tile.gravityPeer! + 1}. Turning that gravity well also turns this lane and arrow.' : ''}';
}

int _localMask(int mask, int turns) {
  final shift = (4 - turns % 4) % 4;
  return ((mask << shift) | (mask >> (4 - shift))) & 15;
}

/// Draw independent channels rather than treating four exits as a junction.
/// litMask is in the same unrotated coordinates as mask.
class PipePainter extends CustomPainter {
  const PipePainter({
    required this.mask,
    required this.light,
    required this.highContrast,
    this.oneWayEntry = 0,
    this.kind = TileKind.relay,
    this.litMask = 15,
    this.wormholePorts,
  });
  final int mask, oneWayEntry, litMask;
  final int? wormholePorts;
  final double light;
  final bool highContrast;
  final TileKind kind;

  /// Each physical channel stops at the outer lip of the hole. The active
  /// traversal exposes only the inlet at entry and the outlet at its peer.
  Map<int, Path> wormholeChannels(Size size) {
    final middle = size.center(Offset.zero);
    final radius = (size.shortestSide * .14).clamp(8.0, 20.0);
    final width = (size.shortestSide * .125).clamp(
      highContrast ? 8.0 : 6.0,
      highContrast ? 40.0 : 36.0,
    );
    final edges = <int, Offset>{
      north: Offset(middle.dx, -2),
      east: Offset(size.width + 2, middle.dy),
      south: Offset(middle.dx, size.height + 2),
      west: Offset(-2, middle.dy),
    };
    return {
      for (final edge in edges.entries)
        if ((wormholePorts ?? mask) & edge.key != 0)
          edge.key: Path()
            ..moveTo(edge.value.dx, edge.value.dy)
            ..lineTo(
              (middle +
                      (edge.value - middle) /
                          (edge.value - middle).distance *
                          (radius + 4 + width / 2))
                  .dx,
              (middle +
                      (edge.value - middle) /
                          (edge.value - middle).distance *
                          (radius + 4 + width / 2))
                  .dy,
            ),
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.center(Offset.zero);
    final edges = <int, Offset>{
      north: Offset(middle.dx, -2),
      east: Offset(size.width + 2, middle.dy),
      south: Offset(middle.dx, size.height + 2),
      west: Offset(-2, middle.dy),
    };
    // Broad, luminous routes are the board's primary shapes. They grow with
    // tablet tiles instead of becoming thin wires in a larger board.
    final width =
        (size.shortestSide * (kind == TileKind.crossway ? .105 : .125)).clamp(
          highContrast ? 8.0 : 6.0,
          highContrast ? 40.0 : 36.0,
        );
    Path lane(int ports, {bool wideBend = false}) {
      final ends = edges.entries
          .where((entry) => ports & entry.key != 0)
          .map((entry) => entry.value)
          .toList();
      final path = Path()..moveTo(ends.first.dx, ends.first.dy);
      if (ends.length == 1) return path..lineTo(middle.dx, middle.dy);
      final straight = ports == (north | south) || ports == (east | west);
      if (!straight) {
        final fraction = wideBend ? .38 : .65;
        final before = Offset.lerp(ends.first, middle, fraction)!;
        final after = Offset.lerp(ends.last, middle, fraction)!;
        path.lineTo(before.dx, before.dy);
        path.quadraticBezierTo(middle.dx, middle.dy, after.dx, after.dy);
      }
      return path..lineTo(ends.last.dx, ends.last.dy);
    }

    void drawChannel(Path route, int ports, {bool overpass = false}) {
      final intensity = ports & litMask == ports ? light : 0.0;
      final bounds = Offset.zero & size;
      Paint stroke(double thickness) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (overpass) {
        canvas.drawPath(route, stroke(width + 9)..color = Palette.board);
      }
      canvas.drawPath(
        route,
        stroke(width + 4.5)..color = Palette.paper.withValues(alpha: .9),
      );
      canvas.drawPath(
        route,
        stroke(width + 2)
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Palette.secondary.withValues(alpha: .28),
              Palette.pipe.withValues(alpha: .09),
            ],
          ).createShader(bounds),
      );
      if (intensity > .01 && !highContrast) {
        canvas.drawPath(
          route,
          stroke(width + 8)
            ..color = Palette.light.withValues(alpha: .30 * intensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawPath(
        route,
        stroke(width)
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                highContrast ? Palette.white : const Color(0xFFB9CBE0),
                const Color(0xFFFFDF95),
                intensity,
              )!,
              Color.lerp(
                highContrast ? Palette.white : const Color(0xFFAABDD5),
                Palette.light,
                intensity,
              )!,
            ],
          ).createShader(bounds),
      );
      if (intensity > .01) {
        canvas.drawPath(
          route,
          stroke(width * .68)
            ..color = const Color(0xFFFFF0C7).withValues(alpha: .4 * intensity),
        );
      }
    }

    if (kind == TileKind.wormhole) {
      for (final channel in wormholeChannels(size).entries) {
        drawChannel(channel.value, channel.key);
      }
    } else if (kind == TileKind.bridge) {
      drawChannel(lane(north | south), north | south);
      drawChannel(lane(east | west), east | west, overpass: true);
      for (final sign in [-1, 1]) {
        final x = middle.dx + sign * width;
        canvas.drawLine(
          Offset(x, middle.dy - width * .6),
          Offset(x, middle.dy + width * .6),
          Paint()
            ..color = Palette.paper.withValues(alpha: .4)
            ..strokeWidth = 1,
        );
      }
    } else if (kind == TileKind.crossway) {
      drawChannel(lane(north | east, wideBend: true), north | east);
      drawChannel(lane(south | west, wideBend: true), south | west);
    } else {
      final ports = edges.keys.where((port) => mask & port != 0).toList();
      if (ports.length <= 2) {
        drawChannel(lane(mask), mask);
      } else {
        for (final port in ports) {
          drawChannel(lane(port), port);
        }
        canvas.drawCircle(
          middle,
          width * .58,
          Paint()
            ..color = Color.lerp(
              const Color(0xFFB9CBE0),
              const Color(0xFFFFDF95),
              light,
            )!,
        );
      }
    }
    if (oneWayEntry != 0) {
      final exitMask = kind == TileKind.bridge
          ? ((oneWayEntry << 2) | (oneWayEntry >> 2)) & 15
          : kind == TileKind.crossway
          ? switch (oneWayEntry) {
              north => east,
              east => north,
              south => west,
              _ => south,
            }
          : mask & ~oneWayEntry;
      final fork =
          kind == TileKind.fork ||
          kind == TileKind.blackHole ||
          kind == TileKind.whiteHole;
      final ports = kind == TileKind.wormhole
          ? edges.keys.where((port) => (wormholePorts ?? mask) & port != 0)
          : fork
          ? [oneWayEntry]
          : edges.keys.where((port) => exitMask & port != 0);
      for (final port in ports) {
        final exit = edges[port]!;
        final inward =
            fork || (kind == TileKind.wormhole && port == oneWayEntry);
        final direction =
            (exit - middle) / (exit - middle).distance * (inward ? -1 : 1);
        final normal = Offset(-direction.dy, direction.dx);
        final point = Offset.lerp(middle, exit, .68)!;
        final length = (size.shortestSide * .085).clamp(3.5, 7.0);
        final arrow = Path()
          ..moveTo(
            (point + direction * length).dx,
            (point + direction * length).dy,
          )
          ..lineTo(
            (point - direction * length * .55 + normal * length * .65).dx,
            (point - direction * length * .55 + normal * length * .65).dy,
          )
          ..lineTo(
            (point - direction * length * .55 - normal * length * .65).dx,
            (point - direction * length * .55 - normal * length * .65).dy,
          )
          ..close();
        canvas.drawPath(
          arrow,
          Paint()
            ..color = Palette.paper
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        canvas.drawPath(arrow, Paint()..color = Palette.white);
      }
    }
    if (kind == TileKind.wormhole ||
        kind == TileKind.blackHole ||
        kind == TileKind.whiteHole) {
      final color = kind == TileKind.wormhole
          ? Color.lerp(Palette.secondary, Palette.rust, .25 + light * .75)!
          : kind == TileKind.whiteHole
          ? Palette.white
          : const Color(0xFFD6AEFF);
      final radius = (size.shortestSide * .14).clamp(8.0, 20.0);
      canvas.drawCircle(middle, radius, Paint()..color = Palette.paper);
      if (kind == TileKind.wormhole && light > .01) {
        canvas.drawCircle(
          middle,
          radius * .58,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    Palette.rust.withValues(alpha: .68 * light),
                    Palette.rust.withValues(alpha: 0),
                  ],
                ).createShader(
                  Rect.fromCircle(center: middle, radius: radius * .58),
                ),
        );
      }
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: middle, radius: radius + i * 2),
          i * .7,
          math.pi * 1.55,
          false,
          Paint()
            ..color = color.withValues(alpha: .95 - i * .2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PipePainter old) =>
      mask != old.mask ||
      light != old.light ||
      oneWayEntry != old.oneWayEntry ||
      highContrast != old.highContrast ||
      kind != old.kind ||
      litMask != old.litMask ||
      wormholePorts != old.wormholePorts;
}

String _directionName(int direction) => switch (direction) {
  north => 'above',
  east => 'the right',
  south => 'below',
  west => 'the left',
  _ => 'either end',
};
