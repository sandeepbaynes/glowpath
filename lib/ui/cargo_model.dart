import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../game/cargo.dart';
import 'design.dart';

/// A small, real mesh renderer for the specimen cabinet. Geometry is shared,
/// while every view has its own orientation. The board's original cargo art is
/// deliberately independent of this viewer.
class CargoModelView extends StatefulWidget {
  const CargoModelView({super.key, required this.kind, this.discovered = true});
  final CargoKind kind;
  final bool discovered;
  @override
  State<CargoModelView> createState() => _CargoModelViewState();
}

class _CargoModelViewState extends State<CargoModelView> {
  double _yaw = -.22, _pitch = -.12;
  bool _focused = false;
  Offset? _lastDrag;
  void _beginDrag(DragStartDetails details) =>
      _lastDrag = details.localPosition;
  void _dragModel(DragUpdateDetails details) {
    final previous = _lastDrag;
    _lastDrag = details.localPosition;
    if (previous == null) return;
    final delta = details.localPosition - previous;
    _turn(delta.dx * .012, delta.dy * .01);
  }

  void _turn(double horizontal, double vertical) => setState(() {
    _yaw = (_yaw + horizontal) % (math.pi * 2);
    _pitch = (_pitch + vertical).clamp(-1.2, 1.2);
  });
  void _reset() => setState(() {
    _yaw = -.22;
    _pitch = -.12;
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${widget.kind.label}, rotatable 3D specimen',
    hint: 'Drag to turn. Double tap to reset the view. Swipe below to browse cargo.',
    customSemanticsActions: {
      const CustomSemanticsAction(label: 'Rotate left'): () => _turn(-.45, 0),
      const CustomSemanticsAction(label: 'Rotate right'): () => _turn(.45, 0),
      const CustomSemanticsAction(label: 'Tilt up'): () => _turn(0, -.3),
      const CustomSemanticsAction(label: 'Tilt down'): () => _turn(0, .3),
      const CustomSemanticsAction(label: 'Reset view'): _reset,
    },
    child: Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _turn(-.18, 0);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _turn(.18, 0);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _turn(0, -.15);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _turn(0, .15);
        } else if (event.logicalKey == LogicalKeyboardKey.home) {
          _reset();
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onHorizontalDragStart: _beginDrag,
          onHorizontalDragUpdate: _dragModel,
          onVerticalDragStart: _beginDrag,
          onVerticalDragUpdate: _dragModel,
          onDoubleTap: _reset,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: CargoModelPainter(
                kind: widget.kind,
                yaw: _yaw,
                pitch: _pitch,
                discovered: widget.discovered,
                focused: _focused,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Camera orientation is explicit, which also makes geometry checks and
/// still-image reviews possible without altering the player's inventory.
class CargoModelPainter extends CustomPainter {
  const CargoModelPainter({
    required this.kind,
    this.yaw = -.22,
    this.pitch = -.12,
    this.discovered = true,
    this.focused = false,
  });
  final CargoKind kind;
  final double yaw, pitch;
  final bool discovered, focused;
  static final _models = {
    for (final kind in CargoKind.values) kind: _buildModel(kind),
  };
  static final _light = _V(-.45, .7, 1).unit;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height * .49);
    final radius = math.min(size.width * .33, size.height * .39);
    final tint = Color(kind.colorValue);
    final halo = Rect.fromCircle(center: center, radius: radius * 1.65);
    canvas.drawCircle(
      center,
      radius * 1.65,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: discovered ? .09 : .045),
            tint.withValues(alpha: 0),
          ],
        ).createShader(halo),
    );
    final orbit = Rect.fromCenter(
      center: center + Offset(0, radius * 1.12),
      width: radius * 2.2,
      height: radius * .23,
    );
    canvas.drawOval(
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 1.3 : .7
        ..color = tint.withValues(alpha: focused ? .65 : .16),
    );
    for (final x in [-1.0, 1.0]) {
      canvas.drawCircle(
        orbit.center + Offset(x * radius * 1.1, 0),
        1.4,
        Paint()..color = tint.withValues(alpha: .45),
      );
    }
    final transformed = _models[kind]!.map((face) {
      final points = face.vertices
          .map((p) => p.rotateY(yaw).rotateX(pitch))
          .toList();
      return _Face(
        points,
        face.color,
        glow: face.glow,
        edge: face.edge,
        smoothCenter: face.smoothCenter?.rotateY(yaw).rotateX(pitch),
      );
    }).toList()..sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in transformed) {
      final normal = (face.vertices[1] - face.vertices[0])
          .cross(face.vertices[2] - face.vertices[0])
          .unit;
      // Back surfaces are painted too: rings and hollow lenses remain correct
      // from the rear. Painter's depth ordering gives opaque, solid volumes.
      final brightness = .37 + .63 * math.max(0, normal.dot(_light));
      final lit = Color.lerp(
        const Color(0xFF071422),
        face.color,
        face.glow ? .92 : brightness,
      )!;
      final color = discovered ? lit : Color.lerp(Palette.paper, lit, .62)!;
      final path = Path();
      final projected = <Offset>[];
      for (var i = 0; i < face.vertices.length; i++) {
        final p = face.vertices[i];
        final perspective = 4.8 / (4.8 - p.z);
        final point = center + Offset(p.x, -p.y) * radius * perspective;
        projected.add(point);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      if (face.smoothCenter case final smoothCenter?) {
        final colors = face.vertices.map((p) {
          final normal = (p - smoothCenter).unit;
          final diffuse = .37 + .63 * math.max(0, normal.dot(_light));
          final shine =
              math
                  .pow(
                    math.max(0, normal.dot((_light + const _V(0, 0, 1)).unit)),
                    38,
                  )
                  .toDouble() *
              .24;
          final lit = Color.lerp(
            Color.lerp(const Color(0xFF071422), face.color, diffuse),
            const Color(0xFFFFFFFF),
            shine,
          )!;
          return discovered ? lit : Color.lerp(Palette.paper, lit, .62)!;
        }).toList();
        final vertices = ui.Vertices(
          ui.VertexMode.triangleFan,
          projected,
          colors: colors,
        );
        canvas.drawVertices(vertices, BlendMode.srcOver, Paint());
        vertices.dispose();
        continue;
      }
      canvas.drawPath(path, Paint()..color = color);
      // Matching seams prevent hairline raster gaps between mesh polygons.
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = .45
          ..strokeJoin = StrokeJoin.round,
      );
      if (face.edge) {
        canvas.drawPath(
          path,
          Paint()
            ..color = tint.withValues(alpha: .23)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .65,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CargoModelPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.discovered != discovered ||
      oldDelegate.focused != focused;
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V other) => _V(x + other.x, y + other.y, z + other.z);
  _V operator -(_V other) => _V(x - other.x, y - other.y, z - other.z);
  _V operator *(double scale) => _V(x * scale, y * scale, z * scale);
  double dot(_V p) => x * p.x + y * p.y + z * p.z;
  _V cross(_V p) => _V(y * p.z - z * p.y, z * p.x - x * p.z, x * p.y - y * p.x);
  _V get unit {
    final length = math.sqrt(dot(this));
    return length < .00001 ? const _V(0, 0, 1) : this * (1 / length);
  }

  _V rotateX(double angle) => _V(
    x,
    y * math.cos(angle) - z * math.sin(angle),
    y * math.sin(angle) + z * math.cos(angle),
  );
  _V rotateY(double angle) => _V(
    x * math.cos(angle) + z * math.sin(angle),
    y,
    -x * math.sin(angle) + z * math.cos(angle),
  );
  _V rotateZ(double angle) => _V(
    x * math.cos(angle) - y * math.sin(angle),
    x * math.sin(angle) + y * math.cos(angle),
    z,
  );
}

class _Face {
  const _Face(
    this.vertices,
    this.color, {
    this.glow = false,
    this.edge = false,
    this.smoothCenter,
  });
  final List<_V> vertices;
  final Color color;
  final bool glow, edge;
  final _V? smoothCenter;
  double get depth =>
      vertices.fold(0.0, (sum, vertex) => sum + vertex.z) / vertices.length;
}

class _Mesh {
  final faces = <_Face>[];
  void face(
    List<_V> points,
    Color color, {
    bool glow = false,
    bool edge = false,
    _V? outward,
    _V? smoothCenter,
  }) {
    if (outward != null &&
        (points[1] - points[0]).cross(points[2] - points[0]).dot(outward) < 0) {
      points = points.reversed.toList();
    }
    faces.add(
      _Face(points, color, glow: glow, edge: edge, smoothCenter: smoothCenter),
    );
  }

  void sphere(
    _V center,
    double radius,
    Color color, {
    int segments = 48,
    int rows = 28,
    double stretch = 1,
  }) {
    _V point(int row, int column) {
      final latitude = math.pi * row / rows;
      final longitude = 2 * math.pi * column / segments;
      return center +
          _V(
            math.sin(latitude) * math.cos(longitude) * radius,
            math.cos(latitude) * radius * stretch,
            math.sin(latitude) * math.sin(longitude) * radius,
          );
    }

    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < segments; i++) {
        final a = point(j, i),
            b = point(j + 1, i),
            c = point(j + 1, i + 1),
            d = point(j, i + 1);
        if (j == 0) {
          face(
            [a, b, c],
            color,
            outward: (a + b + c) * (1 / 3) - center,
            smoothCenter: center,
          );
        } else if (j == rows - 1) {
          face(
            [a, b, d],
            color,
            outward: (a + b + d) * (1 / 3) - center,
            smoothCenter: center,
          );
        } else {
          face(
            [a, b, c, d],
            color,
            outward: (a + b + c + d) * .25 - center,
            smoothCenter: center,
          );
        }
      }
    }
  }

  void torus(
    double radius,
    double tube,
    Color color, {
    double tilt = 0,
    double roll = 0,
    double z = 0,
    bool glow = false,
    int segments = 64,
  }) {
    _V point(int i, int j) {
      final u = i * math.pi * 2 / segments, v = j * math.pi * 2 / 8;
      return _V(
            (radius + tube * math.cos(v)) * math.cos(u),
            (radius + tube * math.cos(v)) * math.sin(u),
            tube * math.sin(v),
          ).rotateX(tilt).rotateZ(roll) +
          _V(0, 0, z);
    }

    for (var i = 0; i < segments; i++) {
      for (var j = 0; j < 8; j++) {
        face(
          [point(i, j), point(i + 1, j), point(i + 1, j + 1), point(i, j + 1)],
          color,
          glow: glow,
        );
      }
    }
  }

  void gem(
    List<(double, double)> rings,
    int sides,
    Color color, {
    double twist = 0,
    double depth = .8,
  }) {
    _V point(int row, int side) {
      final (y, r) = rings[row];
      final angle = side * 2 * math.pi / sides + twist;
      return _V(math.cos(angle) * r, y, math.sin(angle) * r * depth);
    }

    for (var row = 0; row < rings.length - 1; row++) {
      for (var side = 0; side < sides; side++) {
        final a = point(row, side),
            b = point(row + 1, side),
            c = point(row + 1, side + 1),
            d = point(row, side + 1);
        final tone = Color.lerp(
          color,
          const Color(0xFFF4F8F2),
          (side % 3) * .08,
        )!;
        if (rings[row].$2 == 0) {
          face([a, b, c], tone, outward: a + b + c, edge: true);
        } else if (rings[row + 1].$2 == 0) {
          face([a, b, d], tone, outward: a + b + d, edge: true);
        } else {
          face([a, b, c, d], tone, outward: a + b + c + d, edge: true);
        }
      }
    }
  }

  void tube(
    _V start,
    _V end,
    double radius,
    Color color, {
    bool glow = false,
    int divisions = 1,
  }) {
    final axis = (end - start).unit;
    final first = axis
        .cross(axis.y.abs() < .8 ? const _V(0, 1, 0) : const _V(1, 0, 0))
        .unit;
    final second = axis.cross(first).unit;
    _V point(_V center, int n) =>
        center +
        first * (radius * math.cos(n * math.pi / 6)) +
        second * (radius * math.sin(n * math.pi / 6));
    for (var section = 0; section < divisions; section++) {
      final from = start + (end - start) * (section / divisions);
      final to = start + (end - start) * ((section + 1) / divisions);
      for (var n = 0; n < 12; n++) {
        face(
          [point(from, n), point(from, n + 1), point(to, n + 1), point(to, n)],
          color,
          glow: glow,
          outward:
              first * math.cos((n + .5) * math.pi / 6) +
              second * math.sin((n + .5) * math.pi / 6),
        );
      }
    }
  }
}

List<_Face> _buildModel(CargoKind kind) {
  final mesh = _Mesh(), color = Color(kind.colorValue);
  final pale = Color.lerp(color, const Color(0xFFFFFFFF), .55)!;
  switch (kind) {
    case CargoKind.moonPearl:
      mesh.sphere(const _V(0, 0, 0), .77, pale);
      mesh.torus(1.04, .026, color, tilt: 1.16, roll: -.35);
      mesh.torus(1.12, .009, color, tilt: 1.16, roll: -.35);
    case CargoKind.cometShard:
      mesh.gem(
        [(-1.1, 0), (-.47, .52), (.3, .76), (.97, .21), (1.18, 0)],
        5,
        color,
        twist: -.23,
      );
    case CargoKind.dawnPrism:
      mesh.gem(
        [(-1.08, 0), (-.61, .65), (.5, .65), (1.04, 0)],
        6,
        color,
        twist: .2,
      );
      mesh.torus(1.17, .012, pale, tilt: .55, roll: .24);
    case CargoKind.nightOpal:
      mesh.gem(
        [(-1, 0), (-.64, .55), (-.08, .78), (.48, .65), (.89, .31), (1.02, 0)],
        7,
        color,
        twist: .12,
        depth: .93,
      );
      mesh.torus(1.16, .012, pale, tilt: .55, roll: -.3);
    case CargoKind.chronoCell:
      final shape = [
        const Offset(-.52, 1),
        const Offset(.52, 1),
        const Offset(.74, .77),
        const Offset(.74, -.77),
        const Offset(.52, -1),
        const Offset(-.52, -1),
        const Offset(-.74, -.77),
        const Offset(-.74, .77),
      ];
      for (final z in [-.25, .25]) {
        // Subdivide the broad face so the raised hourglass sorts correctly
        // against it at oblique viewing angles, without a texture overlay.
        const bands = [
          -1.0,
          -.885,
          -.77,
          -.66,
          -.55,
          -.44,
          -.33,
          -.22,
          -.11,
          0.0,
          .11,
          .22,
          .33,
          .44,
          .55,
          .66,
          .77,
          .885,
          1.0,
        ];
        double widthAt(double y) =>
            .74 - math.max(0, y.abs() - .77) * (.22 / .23);
        for (var row = 0; row < bands.length - 1; row++) {
          for (var column = 0; column < 18; column++) {
            final left = column / 9 - 1, right = (column + 1) / 9 - 1;
            final y = bands[row], nextY = bands[row + 1];
            mesh.face(
              [
                _V(left * widthAt(y), y, z),
                _V(right * widthAt(y), y, z),
                _V(right * widthAt(nextY), nextY, z),
                _V(left * widthAt(nextY), nextY, z),
              ],
              Color.lerp(color, Palette.paper, .5)!,
              outward: _V(0, 0, z),
            );
          }
        }
        for (var i = 0; i < shape.length; i++) {
          final p = shape[i], q = shape[(i + 1) % shape.length];
          mesh.tube(
            _V(p.dx, p.dy, z),
            _V(q.dx, q.dy, z),
            .026,
            color,
            divisions: 6,
          );
        }
        final front = z * 1.6;
        final hour = [
          const Offset(-.32, .61),
          const Offset(.32, .61),
          const Offset(-.32, -.61),
          const Offset(.32, -.61),
          const Offset(-.32, .61),
        ];
        for (var i = 0; i < hour.length - 1; i++) {
          mesh.tube(
            _V(hour[i].dx, hour[i].dy, front),
            _V(hour[i + 1].dx, hour[i + 1].dy, front),
            .028,
            pale,
            glow: true,
            divisions: 10,
          );
        }
        mesh.sphere(_V(0, 0, front), .084, pale, segments: 16, rows: 10);
      }
      for (var i = 0; i < shape.length; i++) {
        final p = shape[i], q = shape[(i + 1) % shape.length];
        mesh.face(
          [
            _V(p.dx, p.dy, -.25),
            _V(q.dx, q.dy, -.25),
            _V(q.dx, q.dy, .25),
            _V(p.dx, p.dy, .25),
          ],
          color,
          outward: _V(p.dx + q.dx, p.dy + q.dy, 0),
          edge: true,
        );
      }
    case CargoKind.routeLens:
      mesh.torus(.93, .055, color);
      mesh.torus(.72, .035, color, z: .09);
      mesh.torus(.51, .03, pale, z: .17);
      final route = [
        const _V(-.5, -.15, .18),
        const _V(-.1, -.15, .18),
        const _V(-.1, .35, .18),
        const _V(.44, .35, .18),
      ];
      for (var i = 0; i < route.length - 1; i++) {
        mesh.tube(route[i], route[i + 1], .052, pale, glow: true);
      }
      for (final p in route) {
        mesh.sphere(p, .052, pale, segments: 12, rows: 8);
      }
      mesh.sphere(
        route.last,
        .085,
        const Color(0xFFF6FDFF),
        segments: 16,
        rows: 10,
      );
      for (final angle in [0.0, math.pi * 2 / 3, math.pi * 4 / 3]) {
        mesh.tube(
          _V(math.cos(angle) * .52, math.sin(angle) * .52, 0),
          _V(math.cos(angle) * .92, math.sin(angle) * .92, 0),
          .016,
          color,
        );
      }
  }
  return mesh.faces;
}
