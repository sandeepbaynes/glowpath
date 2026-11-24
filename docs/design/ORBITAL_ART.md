# Orbital art system

Version 0.7.1 restores the earlier illustrated Voyage direction after the user rejected the realistic 0.7 turntables. This is a visual restoration using the earlier screenshots as references; no historical source snapshot was available for an exact code rollback.

The map, destination medallions and pilot-view approach share `drawOrbitalWorld` in `lib/ui/space_scenery.dart`. It accepts a `VoyageWorld`, center, radius, surface rotation and opacity. Luma has soft craters, Ember has warm fissures, Viridian has mint continents and pale cloud bands, Halo has gold bands and rings, and Veil has a teal/violet accretion disc. The moon, silhouette, lighting and palette stay consistent between views.

Version 0.7.3 preserves these five worlds and expands the catalog to 50 authored destinations across ten illustrated families, adding stars, comets, asteroid fields, spiral galaxies and ice worlds. Palettes, surface variants, moons and tilts distinguish the entries. Beyond 50, names and surface/palette variations extend deterministically; these are not independently authored meshes. Absolute planet indices anchor the map, which paints the current destination and eight ahead instead of stopping at a five-world sector boundary. Only a bounded nearby window is rendered. Catalog changes do not alter puzzle generation or saved route numbers.

Gentle longitude rotation moves the surface while directional lighting stays fixed. Reduced Motion and lifecycle suspension freeze ambient animation. The pilot approach now uses an illustrated orbital canopy from the same palette; its dialogue, independent arrival and Previous/Next behavior remain intact.

The countdown, voyage courier and failure scene share `drawOrbitalCraft`: a ceramic spacecraft with swept wings and an inset canopy. Failure lasts six seconds: two seconds of constant-speed straight flight on an intact route, a structural snap with cool fragments, then continuous off-course momentum while the rocket and both path pieces drift and recede. In 0.7.3 the engine has a tapered ivory/gold flame with restrained length variation; its power fades over 0.7 seconds after the snap. The fracture itself stays fire-free. Retry has a fixed layout footprint and fades in from 4.8–5.5 seconds, becoming interactive halfway through its reveal. The reduced-motion alternative is a static broken route, visible unpowered craft and immediately available Retry. Both preserve the player's edits.

Puzzle pipes again occupy about one eighth of a normal tile, with broad pale-blue surfaces and warm luminous completed paths. Independent crossing lanes and clear START/FINISH markings are retained. Overpass, crossway and gravity-fork badges now use custom lane geometry shared with the briefing/manual, including directional variants; they do not use a generic layers icon.

## Review artifacts

Actual widget captures are in `docs/screenshots/0.7.1-restored-*` and the revised `signal-lost-0.7.3.mp4`. The failure review video can be reproduced from the shipped widget:

```sh
flutter test tools/render_failure_preview_test.dart
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/encode_failure_preview.py
```

The encoder only packages captured frames for review. The app uses live Flutter animation, not a bundled video. The archived Blender turntables and cockpit plate under `assets/worlds/`, plus their render scripts, are retained as design history but are no longer loaded or bundled. No image-generation service, purchased model or subscription was used for this restoration.
