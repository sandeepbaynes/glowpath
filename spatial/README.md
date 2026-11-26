# Glowpath Spatial

A native **visionOS immersive prototype** built with SwiftUI, RealityKit and ARKit. The galaxy and puzzle occupy the space around the player. They are not hosted inside an iPad window or a rectangular game panel. A small in-world instrument provides navigation, hints and recentering; it does not contain the game scene.

The visionOS Simulator Debug build and physical-device Release build both compile; the device build is unsigned and has not been installed on a headset. Simulator hover works, but automated taps have not activated either the instrument buttons or pipe targets. A simulator playthrough, physical hand interactions and walking are **not yet verified**. This is an interaction and rendering prototype, not a complete Vision Pro release or a port of the full mobile game.

## Current scene

- **Surrounding Voyage:** twelve worlds at different directions, elevations and distances. Six procedural surface styles supply the current variations, including bands, rings and moons. These are native 3D prototype meshes, not exact reproductions of all fifty mobile destinations.
- **Surrounding route:** eighteen independent pipe pieces in three elevation bands around a full cylindrical shell. Shared port positions make neighbouring tubes meet in 3D, including across the rear seam. The authored route uses front, rear, upper and lower areas; START is initially on the left and FINISH on the right.
- **Route interaction:** a spatial tap turns one piece; dragging or rotating previews a turn and commits a legal quarter-turn on release. Valid connections light from START and the route must collect all three stars.
- **World interaction:** planets can be selected and turned; an orbit ring rotates the surrounding content. Turn, Up, Down and Recenter controls offer a seated alternative to turning the body or looking far overhead.
- **Walking response:** the device build contains ARKit world tracking and a compressed virtual-map travel response. The operating system owns the tracked viewpoint. Simulator builds use orbit controls instead of claiming to simulate physical walking.
- **Completion:** the rocket follows the same sampled 3D pipe centreline that the scene renders. Reduced-motion settings disable ambient planet drift and shorten content orientation settling.

All twelve map selections currently open the same authored test route. The prototype is untimed and has no saved progression, scores, ads, purchases, backend or phone sync. There are no locked pieces, linked tiles, gravity, wormholes, cargo rewards, failure cinematic or daily/weekly content in this target yet. Real reach, direct poke behaviour, gesture conflicts, tracking interruption, comfort and frame time remain part of headset testing.

## Build and launch

Use Xcode with the visionOS SDK and an installed Vision Pro simulator runtime. The current deployment target is **visionOS 2.0**; compilation uses the installed SDK, not proof that an older runtime has been tested. No developer signing team is embedded.

Run from the repository root:

```sh
xcodebuild \
  -project spatial/visionOS/GlowpathSpatial.xcodeproj \
  -scheme GlowpathSpatial \
  -configuration Debug \
  -sdk xrsimulator \
  -destination 'generic/platform=visionOS Simulator' \
  -derivedDataPath build/spatial-preview \
  CODE_SIGNING_ALLOWED=NO build
```

To compile the physical-device target without signing or installing it:

```sh
xcodebuild \
  -project spatial/visionOS/GlowpathSpatial.xcodeproj \
  -scheme GlowpathSpatial \
  -configuration Release \
  -sdk xros \
  -destination 'generic/platform=visionOS' \
  -derivedDataPath build/spatial-device-preview \
  CODE_SIGNING_ALLOWED=NO build
```

Choose a booted Vision Pro simulator's UDID from `xcrun simctl list devices available`, then install and launch:

```sh
xcrun simctl install VISION_UDID \
  build/spatial-preview/Build/Products/Debug-xrsimulator/GlowpathSpatial.app
xcrun simctl launch VISION_UDID app.glowpath.spatialpreview
```

Debug builds also accept `--preview-route` to open the route composition or `--preview-solved` to open its solved flight. For example:

```sh
xcrun simctl launch VISION_UDID app.glowpath.spatialpreview --preview-route
```

These flags bypass normal interaction for composition and rocket-motion checks. They are not substitutes for completing the puzzle through gestures and are not enabled in Release builds.

The application launches directly into its full immersive scene. Use the platform's standard system controls to leave immersion. The built-in instrument can return from the route to Voyage. A refined entry/exit flow and accessibility review remain release work.

## Rules and cross-engine data

`Shared/SpatialPuzzle.swift` is a renderer-independent Foundation implementation. `levels/first-orbit.json` exports the same versioned level contract: eighteen tile masks, route order, stars, start/finish indices and endpoint ports. Horizontal columns wrap; elevation rows are bounded. Input changes masks and the evaluator traces legal connections independently of the graphics.

Run the focused checks:

```sh
sh spatial/Tests/check_rules.sh
```

They verify seam neighbours, external endpoints, an unsolved initial arrangement, the complete eighteen-piece route, required stars, disconnected prefixes, four-turn identity, hint convergence, reset, malformed input handling and equality between the native level and exported JSON.

To deliberately regenerate the reference JSON after changing the authored level:

```sh
sh spatial/Tests/check_rules.sh --export > spatial/levels/first-orbit.json
```

The shared format is a starting point for matching native and OpenXR implementations. It does not establish score or obstacle parity with Flutter or a second engine.

## Other VR headsets

The same **surrounding galaxy and route** is the intended experience for Meta Quest/Oculus Quest, Android XR, PICO and supported PC VR configurations. Hand input and tracked controllers will map to the same game actions; a headset without equivalent hand tracking still needs a complete controller interaction path.

The proposed second renderer uses Unity/OpenXR with headset-specific input adapters. **Unity is not installed for this project, and no Quest, Android XR, PICO or PC VR binary is built.** This Swift/RealityKit target cannot be installed on those headsets. New platforms require their own builds, capability checks and physical playtests; support is not promised for every historical headset.

See the [immersive design and capability contract](../docs/platforms/IMMERSIVE_XR.md) for the current platform matrix, movement rules, seated controls and acceptance checks. The [device strategy](../docs/platforms/DEVICE_STRATEGY.md) tracks the broader release plan. The [25 November simulator review](../docs/platforms/SIMULATOR_REVIEW_2026_11_25.md) describes the earlier flat iPad compatibility check and should not be confused with this native target.
