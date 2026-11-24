import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A continuous touch trace over the existing tap/keyboard tile controls.
/// The owner previews legal orientations and commits them only on lift.
class RouteDragSurface extends StatefulWidget {
  const RouteDragSurface({
    super.key,
    required this.gridSize,
    required this.enabled,
    required this.reduceMotion,
    required this.accent,
    required this.child,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
    this.onRejected,
  });
  final int gridSize;
  final bool enabled, reduceMotion;
  final Color accent;
  final Widget child;
  final bool Function()? onStart;
  final bool Function(List<int>)? onUpdate;
  final VoidCallback? onEnd, onCancel, onRejected;

  @override
  State<RouteDragSurface> createState() => _RouteDragSurfaceState();
}

class _RouteDragSurfaceState extends State<RouteDragSurface> {
  final _pointers = <int>{};
  List<int> _cells = [];
  Offset? _down, _previous;
  int? _rejected;
  bool _tracing = false, _interrupted = false;
  double _extent = 0;

  @override
  void didUpdateWidget(RouteDragSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.enabled || oldWidget.gridSize != widget.gridSize) &&
        _tracing) {
      _tracing = false;
      _cells = [];
      _rejected = null;
      // The owner cancels its model before disabling the board. No callback
      // from build: a timeout/page transition must not re-enter setState.
    }
  }

  int? _cellAt(Offset point, {bool inner = true}) {
    if (point.dx < 0 ||
        point.dy < 0 ||
        point.dx >= _extent ||
        point.dy >= _extent) {
      return null;
    }
    final pitch = (_extent + 3) / widget.gridSize;
    final tile = pitch - 3;
    final column = (point.dx / pitch).floor();
    final row = (point.dy / pitch).floor();
    final x = point.dx - column * pitch;
    final y = point.dy - row * pitch;
    final inset = inner ? tile * .13 : 0.0;
    if (x < inset || y < inset || x > tile - inset || y > tile - inset) {
      return null;
    }
    return row * widget.gridSize + column;
  }

  void _start(DragStartDetails details) {
    if (!widget.enabled || _interrupted || _pointers.length > 1) return;
    final down = _down ?? details.localPosition;
    final first = _cellAt(down, inner: false);
    if (first == null || widget.onStart?.call() != true) return;
    _tracing = true;
    _cells = [first];
    _previous = down;
    widget.onUpdate?.call(List.unmodifiable(_cells));
    _walk(details.localPosition);
    setState(() {});
  }

  void _walk(Offset position) {
    if (!_tracing || !widget.enabled) return;
    final from = _previous ?? position;
    _previous = position;
    // Sample the actual pointer segment, not a guessed Manhattan shortcut.
    // Fast swipes still visit every crossed cell; diagonals cannot skip tiles.
    final step = math.max(4.0, _extent / widget.gridSize * .20);
    final count = math.max(1, ((position - from).distance / step).ceil());
    for (var i = 1; i <= count; i++) {
      final cell = _cellAt(Offset.lerp(from, position, i / count)!);
      if (cell == null) continue;
      if (cell == _cells.last) {
        _rejected = null;
        continue;
      }
      // After a blocked turn, return to the last valid tile before rerouting.
      if (_rejected != null) continue;
      final last = _cells.last;
      final distance =
          (cell ~/ widget.gridSize - last ~/ widget.gridSize).abs() +
          (cell % widget.gridSize - last % widget.gridSize).abs();
      if (distance != 1) {
        _reject(cell);
        break;
      }
      final backtracking =
          _cells.length > 1 && cell == _cells[_cells.length - 2];
      final candidate = backtracking
          ? _cells.sublist(0, _cells.length - 1)
          : [..._cells, cell];
      if (widget.onUpdate?.call(List.unmodifiable(candidate)) == true) {
        _cells = candidate;
      } else {
        _reject(cell);
        break;
      }
    }
  }

  void _reject(int cell) {
    _rejected = cell;
    widget.onRejected?.call();
  }

  void _finish({bool cancel = false}) {
    if (!_tracing) return;
    _tracing = false;
    _cells = [];
    _rejected = null;
    _down = _previous = null;
    if (cancel || !widget.enabled) {
      widget.onCancel?.call();
    } else {
      widget.onEnd?.call();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      _extent = bounds.maxWidth;
      return Listener(
        onPointerDown: (event) {
          _pointers.add(event.pointer);
          if (_pointers.length > 1) {
            _interrupted = true;
            _finish(cancel: true);
          }
        },
        onPointerUp: (event) {
          _pointers.remove(event.pointer);
          if (_pointers.isEmpty) _interrupted = false;
        },
        onPointerCancel: (event) {
          _pointers.remove(event.pointer);
          _finish(cancel: true);
          if (_pointers.isEmpty) _interrupted = false;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onPanDown: widget.enabled && widget.onStart != null
              ? (details) {
                  _down = details.localPosition;
                }
              : null,
          onPanStart: widget.enabled && widget.onStart != null ? _start : null,
          onPanUpdate: widget.enabled && widget.onStart != null
              ? (details) {
                  _walk(details.localPosition);
                  if (_tracing) setState(() {});
                }
              : null,
          onPanEnd: widget.onStart != null ? (_) => _finish() : null,
          onPanCancel: widget.onStart != null
              ? () => _finish(cancel: true)
              : null,
          child: Stack(
            children: [
              widget.child,
              if (_tracing)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: _TracePainter(
                          cells: _cells,
                          rejected: _rejected,
                          gridSize: widget.gridSize,
                          accent: widget.accent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _TracePainter extends CustomPainter {
  const _TracePainter({
    required this.cells,
    required this.rejected,
    required this.gridSize,
    required this.accent,
  });
  final List<int> cells;
  final int? rejected;
  final int gridSize;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final pitch = (size.width + 3) / gridSize;
    final tile = pitch - 3;
    Rect cellRect(int index) => Rect.fromLTWH(
      index % gridSize * pitch,
      index ~/ gridSize * pitch,
      tile,
      tile,
    );
    for (final cell in cells.toSet()) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          cellRect(cell).deflate(2),
          const Radius.circular(11),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent.withValues(alpha: cell == cells.last ? .8 : .22),
      );
    }
    if (rejected case final int cell) {
      final rect = cellRect(cell).deflate(3);
      const warning = Color(0xFFE5A18D);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()..color = warning.withValues(alpha: .12),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = warning,
      );
      // A stop mark is readable even without color or physical haptics.
      final mark = rect.topRight + const Offset(-10, 10);
      canvas.drawCircle(mark, 6, Paint()..color = warning);
      canvas.drawLine(
        mark + const Offset(-3, 0),
        mark + const Offset(3, 0),
        Paint()
          ..color = const Color(0xFF060B14)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.cells != cells ||
      old.rejected != rejected ||
      old.gridSize != gridSize ||
      old.accent != accent;
}
