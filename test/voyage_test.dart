import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/ui/space_scenery.dart';

void main() {
  test('fifteen-route planets and 75-route galaxies change at the right boundaries', () {
    const cases = [
      (level: 1, name: 'Luma', planet: 0, galaxy: 0, route: 1),
      (level: 15, name: 'Luma', planet: 0, galaxy: 0, route: 15),
      (level: 16, name: 'Ember', planet: 1, galaxy: 0, route: 1),
      (level: 75, name: 'The Veil', planet: 4, galaxy: 0, route: 15),
      (level: 76, name: 'Solara', planet: 0, galaxy: 1, route: 1),
    ];
    for (final entry in cases) {
      final world = VoyageWorld.forLevel(entry.level);
      final context = 'Journey level ${entry.level}';
      expect(world.name, entry.name, reason: context);
      expect(world.index, entry.planet, reason: context);
      expect(world.galaxyIndex, entry.galaxy, reason: context);
      expect(world.routeWithin(entry.level), entry.route, reason: context);
    }
  });

  test(
    'the first thousand planets have distinct stable names and palettes',
    () {
      final worlds = List.generate(
        1000,
        (i) => VoyageWorld.forLevel(i * 15 + 1),
      );
      expect(worlds.map((world) => world.name).toSet().length, 1000);
      for (var i = 0; i < worlds.length; i++) {
        final repeat = VoyageWorld.forLevel(i * 15 + 15);
        expect(repeat.name, worlds[i].name);
        expect(repeat.accent, worlds[i].accent);
        expect(repeat.planetIndex, i);
        expect(repeat.index, inInclusiveRange(0, 4));
      }
      expect(worlds[5].accent, isNot(worlds[0].accent));
    },
  );

  test(
    'repeated planets and galaxy names remain distinguishable on later voyages',
    () {
      final first = VoyageWorld.forLevel(1);
      final second = VoyageWorld.forLevel(76);
      final repeatedGalaxy = VoyageWorld.forLevel(301);
      expect(second.name, isNot(first.name));
      expect(repeatedGalaxy.name, isNot(first.name));
      expect(first.galaxyName, 'Aster Reach');
      expect(second.galaxyName, 'Meridian Drift · 2');
      expect(repeatedGalaxy.galaxyName, 'Aster Reach · 5');
      expect(
        {first.galaxyName, second.galaxyName, repeatedGalaxy.galaxyName}.length,
        3,
      );
      expect(repeatedGalaxy.galaxyIndex, 4);
      expect(repeatedGalaxy.routeWithin(301), 1);
      expect(VoyageWorld.forLevel(315).routeWithin(315), 15);
      expect(VoyageWorld.forLevel(316).routeWithin(316), 1);
    },
  );
}
