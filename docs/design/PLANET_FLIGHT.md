# Planet approach and mission dialogue

`PlanetFlight` is one full-screen transition, combining a seven-second pilot-view approach with one Mission Control or Pilot message at a time. The destination is the exact `VoyageWorld` from the map, drawn through the shared `drawOrbitalWorld` renderer: identical illustrated surfaces, palette, galaxy phase and lighting. It does not play the former generic ocean-world movie.

The moving scene uses perspective-projected stars, restrained banking, an eased approach and the restored illustrated Voyage planets. Their visual language is the earlier soft-gradient spheres: Luma's craters, Ember's warm fissures, Viridian's mint polygon continents and cloud bands, Halo's striped rings, and the teal/violet Veil. Surface patches turn in longitude with fixed lighting and stable silhouettes. A simple drawn canopy and low instrument rim share the same orbital palette.

This restores the earlier visual style, not an exact source rollback: the prior surface routines were not available in version history. The rejected realistic planet atlas and Blender cockpit plate are no longer loaded. There is no image decoding, movie or 3D asset cache in this scene.

## Interaction and accessibility

- The flight runs behind the dialogue and arrives on its own. Arrival never advances or dismisses a message.
- Previous and Next move through the messages. The final **Let's fly** action completes the transition, including when the player finishes reading before arrival.
- **Arrive now** shortens travel without skipping any dialogue. It disappears after arrival.
- Reduced Motion displays the destination immediately. Backgrounding pauses travel. Neither behavior dismisses dialogue.
- Text is measured and paginated at the user's text scale without scrolling or omitting rules. Phone and tablet arrangements preserve 48-pixel action targets. The compact bubble fits its current text and resizes smoothly when motion is allowed.
- The parent pauses the puzzle timer for the entire transition and marks introduced rules only after completion. The separate first-flight introduction still uses a single start action.

## Artwork and implementation

`lib/ui/space_scenery.dart` owns the shared illustrated planets; `lib/ui/planet_flight.dart` owns the perspective approach and minimal cockpit frame. All artwork is native Canvas geometry. No image-generation service, purchase, soundtrack or network request is used. Earlier Blender source scripts and rendered exports remain historical source assets only; they are not used by this transition.

## Verification

Fourteen focused flight widget tests cover independent arrival/dialogue, Previous/Next, one-shot completion, lifecycle pause, shortened arrival, reduced motion, reading-position preservation across rotation, complete rule text and action bounds at 320×568, 393×852, 844×390, 1024×1366 and 1366×1024 at 1× and 3× text. `test/secondary_design_gallery_test.dart` also renders the actual bundled Manrope font and shared illustrated artwork at phone and tablet sizes in portrait and landscape.

To reproduce the focused checks and optional visual captures:

```sh
flutter test test/planet_flight_test.dart test/flight_manual_test.dart
flutter test test/secondary_design_gallery_test.dart --dart-define=CAPTURE_DESIGN=true
```

The gallery writes PNGs under `/tmp/glowpath-secondary-polish/`. Native-device frame pacing and the feel of the revised approach require further physical-device review; passing widget tests do not establish device performance.
