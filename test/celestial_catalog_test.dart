import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('fifty authored destinations retain the original opening worlds', () {
    final worlds = List.generate(50, (i) => VoyageWorld.forLevel(i * 15 + 1));
    expect(VoyageWorld.authoredDestinationCount, 50);
    expect(worlds.take(5).map((world) => world.name), [
      'Luma',
      'Ember',
      'Viridian',
      'Halo',
      'The Veil',
    ]);
    expect(worlds.map((world) => world.name).toSet(), hasLength(50));
    expect(
      worlds.map((world) => world.kind).toSet(),
      containsAll(CelestialKind.values),
    );
    expect(worlds.where((world) => world.isBlackHole), hasLength(5));
    // A new family after the old end of the map is reachable at the same level.
    expect(worlds[5].name, 'Solara');
    expect(worlds[5].kind, CelestialKind.star);
    for (var i = 0; i < worlds.length; i++) {
      final lastRoute = VoyageWorld.forLevel(i * 15 + 15);
      expect(lastRoute.name, worlds[i].name);
      expect(lastRoute.kind, worlds[i].kind);
      expect(lastRoute.routeWithin(i * 15 + 15), 15);
    }
  });

  test(
    'authored catalog extends deterministically beyond every later sector',
    () {
      for (final planet in [49, 50, 51, 499, 524, 999, 999999]) {
        final level = planet * 15 + 1;
        final world = VoyageWorld.forLevel(level);
        final repeated = VoyageWorld.forLevel(level + 14);
        final next = VoyageWorld.forLevel(level + 15);
        expect(world.planetIndex, planet);
        expect(next.planetIndex, planet + 1);
        expect(next.name, isNot(world.name));
        expect(repeated.name, world.name);
        expect(repeated.accent, world.accent);
        expect(repeated.highlight, world.highlight);
        expect(repeated.surfaceVariant, world.surfaceVariant);
        expect(next.routeWithin(level + 15), 1);
      }
      expect(VoyageWorld.forLevel(751).name, 'Luma · 2');
      expect(
        VoyageWorld.forLevel(751).accent,
        isNot(VoyageWorld.forLevel(1).accent),
      );
    },
  );

  testWidgets(
    'all fifty destinations have distinct painted artwork and motion',
    (tester) async {
      final signatures = <int>{};
      await tester.runAsync(() async {
        for (var i = 0; i < 50; i++) {
          final world = VoyageWorld.forLevel(i * 15 + 1);
          final still = await _pixels(world, 0);
          final moved = await _pixels(world, .8);
          final loop = await _pixels(world, math.pi * 2);
          var seamDifference = 0;
          for (var pixel = 0; pixel < still.length; pixel += 4) {
            if ((still[pixel] - loop[pixel]).abs() > 3 ||
                (still[pixel + 1] - loop[pixel + 1]).abs() > 3 ||
                (still[pixel + 2] - loop[pixel + 2]).abs() > 3 ||
                (still[pixel + 3] - loop[pixel + 3]).abs() > 3) {
              seamDifference++;
            }
          }
          expect(
            seamDifference,
            lessThan(8),
            reason:
                '${world.name} must return smoothly at the ambient loop seam.',
          );
          final painted = List.generate(
            still.length ~/ 4,
            (p) => still[p * 4 + 3],
          ).where((alpha) => alpha > 20).length;
          expect(painted, greaterThan(350), reason: world.name);
          expect(painted, lessThan(160 * 160), reason: world.name);
          expect(
            _signature(moved),
            isNot(_signature(still)),
            reason: '${world.name} must have a gently moving surface or field.',
          );
          signatures.add(_signature(still));
        }
      });
      expect(
        signatures,
        hasLength(50),
        reason: 'Names alone must not disguise duplicate destination artwork.',
      );
    },
  );

  if (const bool.fromEnvironment('CAPTURE_CELESTIAL')) {
    testWidgets('capture labeled authored destination contact sheet', (
      tester,
    ) async {
      await (FontLoader('Manrope')..addFont(
            rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
          ))
          .load();
      await tester.runAsync(() async {
        const width = 1500;
        const height = 2800;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFF060B14), BlendMode.src);
        for (var i = 0; i < 50; i++) {
          final world = VoyageWorld.forLevel(i * 15 + 1);
          final x = (i % 5) * 300.0;
          final y = (i ~/ 5) * 280.0;
          drawOrbitalWorld(
            canvas,
            center: Offset(x + 150, y + 125),
            radius: 70,
            world: world,
            rotation: .3,
          );
          for (final (label, dy, size, color) in [
            ('${i + 1}. ${world.name}', 224.0, 18.0, const Color(0xFFF4F2EC)),
            (world.kind.label, 252.0, 12.0, const Color(0xFFA9B8C6)),
          ]) {
            final text = TextPainter(
              text: TextSpan(
                text: label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: size,
                  color: color,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 290);
            text.paint(canvas, Offset(x + (300 - text.width) / 2, y + dy));
          }
        }
        final image = await recorder.endRecording().toImage(width, height);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/screenshots/0.7.3-celestial-catalog.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}

Future<Uint8List> _pixels(VoyageWorld world, double rotation) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  OrbitalPlanetPainter(
    world: world,
    rotation: rotation,
  ).paint(canvas, const Size.square(160));
  final image = await recorder.endRecording().toImage(160, 160);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

int _signature(Uint8List bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash;
}
