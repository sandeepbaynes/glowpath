import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../game/voyage_records.dart';
import 'design.dart';
import 'space_controls.dart';

/// A finite, paged flight log. Every route stays reachable without a scrolling
/// panel or reducing the system's text scale.
class VoyageArchive extends StatefulWidget {
  const VoyageArchive({
    super.key,
    required this.planetIndex,
    required this.frontierLevel,
    required this.records,
    required this.onReplay,
    this.reduceMotion = false,
  });

  final int planetIndex, frontierLevel;
  final Map<int, RouteRecord> records;
  final ValueChanged<int> onReplay;
  final bool reduceMotion;

  @override
  State<VoyageArchive> createState() => _VoyageArchiveState();
}

class _VoyageArchiveState extends State<VoyageArchive> {
  int _first = 0;

  @override
  void didUpdateWidget(VoyageArchive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planetIndex != widget.planetIndex) _first = 0;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final large = MediaQuery.textScalerOf(context).scale(1) > 1.6;
      final horizontal = bounds.maxWidth >= 480 && bounds.maxHeight < 170;
      final rowHeight = large ? 92.0 : 62.0;
      final count = ((bounds.maxHeight - 52) / rowHeight).floor().clamp(1, 5);
      final page = (_first ~/ count).clamp(0, (14 ~/ count));
      final first = page * count;
      final end = math.min(15, first + count);
      return Column(
        children: [
          Expanded(
            child: Column(
              children: [
                for (var route = first; route < end; route++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: _ReplayCard(
                        level: widget.planetIndex * 15 + route + 1,
                        route: route + 1,
                        record:
                            widget.records[widget.planetIndex * 15 + route + 1],
                        unlocked:
                            widget.planetIndex * 15 + route + 1 <
                            widget.frontierLevel,
                        isFrontier:
                            widget.planetIndex * 15 + route + 1 ==
                            widget.frontierLevel,
                        large: large,
                        horizontal: horizontal,
                        onReplay: widget.onReplay,
                        reduceMotion: widget.reduceMotion,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                OrbitUtility(
                  key: const ValueKey('archive-previous-routes'),
                  label: 'Previous routes',
                  width: 48,
                  icon: Icons.chevron_left_rounded,
                  reduceMotion: widget.reduceMotion,
                  onPressed: () =>
                      setState(() => _first = math.max(0, first - count)),
                ),
                Expanded(
                  child: Text(
                    '${first + 1}–$end / 15',
                    semanticsLabel: 'Showing routes ${first + 1} to $end of 15',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Palette.secondary,
                    ),
                  ),
                ),
                OrbitUtility(
                  key: const ValueKey('archive-next-routes'),
                  label: 'Next routes',
                  width: 48,
                  icon: Icons.chevron_right_rounded,
                  reduceMotion: widget.reduceMotion,
                  onPressed: () =>
                      setState(() => _first = end < 15 ? end : first),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _ReplayCard extends StatefulWidget {
  const _ReplayCard({
    required this.level,
    required this.route,
    required this.record,
    required this.unlocked,
    required this.isFrontier,
    required this.large,
    required this.horizontal,
    required this.onReplay,
    required this.reduceMotion,
  });

  final int level, route;
  final RouteRecord? record;
  final bool unlocked, isFrontier, large, horizontal, reduceMotion;
  final ValueChanged<int> onReplay;

  @override
  State<_ReplayCard> createState() => _ReplayCardState();
}

class _ReplayCardState extends State<_ReplayCard> {
  bool _pressed = false, _focused = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final time = record?.bestTime;
    final timeLabel = time == null
        ? '—'
        : '${(time.inMilliseconds / 1000).toStringAsFixed(1)}s';
    final detail = !widget.unlocked
        ? widget.isFrontier
              ? 'Current route'
              : 'Not reached'
        : record == null
        ? 'Set your first best'
        : '${record.bestScore} pts · $timeLabel';
    final label = !widget.unlocked
        ? 'Route ${widget.route}. $detail.'
        : 'Replay route ${widget.route}, level ${widget.level}. '
              '${record == null ? 'No personal best recorded.' : 'Best score ${record.bestScore}${record.bestScoreAssisted ? ', assisted' : ''}. ${time == null ? 'No time recorded.' : 'Best time ${(time.inMilliseconds / 1000).toStringAsFixed(1)} seconds${record.bestTimeAssisted ? ', assisted' : ''}.'}'}';
    void activate() {
      if (widget.unlocked) widget.onReplay(widget.level);
    }

    final affordance = Icon(
      widget.unlocked ? Icons.replay_rounded : Icons.lock_outline_rounded,
      size: widget.large ? 18 : 22,
      color: widget.unlocked
          ? Palette.rust
          : Palette.secondary.withValues(alpha: .5),
    );

    return Semantics(
      key: ValueKey('replay-route-${widget.level}'),
      button: true,
      enabled: widget.unlocked,
      label: label,
      onTap: widget.unlocked ? activate : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: widget.unlocked,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                activate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.unlocked ? activate : null,
            onTapDown: widget.unlocked
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? .985 : 1,
              duration: widget.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Palette.rust.withValues(
                        alpha: widget.unlocked ? .09 : .025,
                      ),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: Palette.rust.withValues(
                      alpha: _focused
                          ? .8
                          : widget.unlocked
                          ? .24
                          : .07,
                    ),
                  ),
                ),
                child: widget.horizontal
                    ? Row(
                        children: [
                          SizedBox(
                            width: 68,
                            child: Text(
                              widget.route.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: widget.large ? 11 : 16,
                                color: Palette.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              record != null && widget.unlocked
                                  ? '${record.bestScore} pts'
                                  : widget.unlocked
                                  ? 'Replay'
                                  : widget.isFrontier
                                  ? 'Current'
                                  : 'Locked',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: widget.large ? 9 : 14,
                                color: Palette.white,
                              ),
                            ),
                          ),
                          if (record != null && widget.unlocked)
                            Expanded(
                              child: Text(
                                timeLabel,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: widget.large ? 9 : 14,
                                  color: Palette.secondary,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          affordance,
                        ],
                      )
                    : widget.large
                    ? Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              widget.route.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.unlocked
                                    ? Palette.white
                                    : Palette.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (record != null && widget.unlocked) ...[
                                  Row(
                                    children: [
                                      Text(
                                        '${record.bestScore}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Palette.white,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'pts',
                                        style: TextStyle(
                                          fontSize: 6,
                                          color: Palette.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    timeLabel,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Palette.secondary,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    widget.unlocked
                                        ? 'Replay'
                                        : widget.isFrontier
                                        ? 'Current'
                                        : 'Locked',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Palette.secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          affordance,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Route ${widget.route}',
                                  style: TextStyle(
                                    fontSize: widget.large ? 11 : 15,
                                    color: widget.unlocked
                                        ? Palette.white
                                        : Palette.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  detail,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: widget.large ? 9 : 12,
                                    color: Palette.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          affordance,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
