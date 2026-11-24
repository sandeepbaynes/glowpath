# Device and spatial release strategy

This document records interaction decisions and what is actually built. A store listing requires a playable, device-tested package; a layout mock or simulator run alone is not a release.

## Shared game, distinct interfaces

The puzzle generator, route rules, scoring, progression and replay format are the common game specification. Flutter currently renders mobile and web. watchOS has an experimental SwiftUI implementation. TV needs remote navigation. XR needs a native spatial scene and input system; placing the Flutter board on a floating flat panel would miss the intended interaction.

Use a versioned level/replay contract for any native edition. A route action should identify its tile, orientation, lane and timestamp; the rules engine should verify the final path and optional cargo independently of the renderer. Before sharing scores across editions, test that native clients produce the same result from the same level seed and action sequence. No cross-platform service is deployed yet.

## Mobile, folds and watch

| Form | Intended behavior | Verification still needed |
| --- | --- | --- |
| Phone, including narrow cover screen | Portrait board; finger drag and tap; reachable controls; launch clock remains legible around camera and safe areas. | Physical Android range and cover-screen devices. |
| Tablet / wide desktop | Board and mission panel side by side at a comfortable scale; no oversized game tiles or empty half-screen. | iPad Pro and additional tablet sizes. |
| Book fold, partly open | Two deliberate surfaces divided at the hinge: one stable puzzle surface and one map/timer/control surface. | Real hinge geometry, posture transitions and reach. |
| Book fold, fully open | Preserve board position and progress as the second surface expands. | Device-specific window metrics and transition smoothness. |
| Flip fold, partly open | Puzzle on the touch-friendly half; timer/map on the other. | Real flip device and exterior display policy. |
| watchOS / Wear OS | Short independent routes without ads or purchases; phone discovery can be optional. | watchOS simulator/device playtest; Wear OS implementation and test. |

Desktop web is built. Native macOS, Windows and Linux, including a Steam Deck layout, are distribution candidates using Flutter desktop targets. They need keyboard/controller navigation, performance QA and signed platform packages; there is no native desktop release today. Console distribution would additionally require platform access and dev hardware, so it is a separate evaluation rather than an assumed release.

The current Flutter mobile baseline is iOS 15 and Android API 24, the oldest versions supported by Flutter 3.50. Store upload rules and runtime support are separate questions. Lowering below these versions would require an older or unsupported Flutter runtime, or a native port, and a separate QA matrix. [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms).

## Television

Apple TV and Android TV should use a selected tile with directional moves and Select to rotate/confirm, plus Back to reverse. Every screen must be operable with only a D-pad. The timer should be tuned against actual remote completion times rather than using the 30-second phone window; increase it for each route until playtesting shows fair pressure. Use readable text and visible focus at viewing distance. Do not carry phone banner placements onto TV by default. [Android TV controller requirements](https://developer.android.com/training/tv/get-started/controllers), [Apple game input guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-games).

Android TV can potentially share an Android package after a remote-first layout, Leanback launcher entry, and TV testing. Apple TV requires a tvOS target. Neither target currently exists.

## Spatial interaction

**Target experience.** The puzzle is a reachable assembly floating at a comfortable distance. The player traces a route by touching or pinching adjacent path segments. A valid segment visibly aligns; an invalid connection resists and briefly signals why. Planets occupy the surrounding space and can be grabbed, spun and flicked; their motion loses energy and settles back to an authored orientation. The rocket launch and route failure happen in the same scene so the player can follow the result. Keep essential controls within a seated reach, offer recentering and a reduced-motion mode, and do not force prolonged arm elevation.

**Input contract.** `hover` previews a tile; `select` begins a route or grabs a planet; `move` extends the route or rotates the object; `release` commits or springs back; `cancel` restores the last stable state. Hand input and controllers map to these same actions. The game must remain playable when tracking is poor or hand input is unavailable. Optional eye aim only chooses a candidate target; it must not activate a route on gaze alone. Hand and eye data stay on-device for interaction unless the player explicitly opts into a separate feature.

| Runtime / storefront | Verified capabilities and proposed implementation | Release evidence needed |
| --- | --- | --- |
| **Apple Vision Pro / visionOS** | RealityKit/SwiftUI scene with direct and indirect gestures; ARKit hand tracking for custom reach. Implement the planet's elastic angular motion in RealityKit. | visionOS simulator for layout, then Vision Pro for real reach, hand tracking, comfort and performance. [Apple hand tracking](https://developer.apple.com/documentation/visionos/tracking-and-visualizing-hand-movement). |
| **Meta Quest / Horizon Store** | Quest headsets provide hand tracking; Unity OpenXR and Meta Interaction SDK can support poke, pinch, grab and controller fallback. Tune art/performance per headset rather than assuming one quality tier. | XR simulator prototype followed by Quest 3/3S and an older supported headset for hand occlusion, controller parity and frame rate. [Meta device comparison](https://developers.meta.com/horizon/essentials/compare-devices/). |
| **Android XR / Google Play** | OpenXR supports hand gestures and optional high-fidelity joint tracking; request sensitive hand-tracking permission only if that data is required. Share a Unity OpenXR scene with device-specific adapters where feasible. | Android XR emulator plus a physical headset for spatial reach, permissions and graphics. [Android XR OpenXR](https://developer.android.com/develop/xr/openxr/get-started). |
| **PICO / PICO Store** | PICO Neo3, PICO 4 and PICO 4 Ultra support hand tracking with the documented OS minimum; the richer Hand Interaction Profile is limited to PICO 4 Ultra. Use a feature-gated Unity OpenXR adapter and controllers as fallback. | PICO 4 Ultra and an older target device, with store package review. [PICO hand tracking](https://developer.picoxr.com/document/unity-openxr/hand-tracking/). |
| **PC VR / SteamVR and VIVE** | OpenXR controller actions are the baseline. Some VIVE devices expose hand tracking, but availability varies by headset and runtime, so hands are an enhancement rather than a requirement. | Windows PC VR build, tested input bindings and at least one compatible headset before a Steam listing. [SteamVR OpenXR settings](https://partner.steamgames.com/doc/features/steamvr/settings), [VIVE hand tracking](https://developer.vive.com/resources/openxr/unreal/unreal-tutorials/handtracking/). |

The first spatial prototype should prove one route can be completed by reach and by controller, a planet can be grabbed and elastically released, and the same seed/replay is scored identically to mobile. Only then expand the authored scene and distribution targets. Each storefront needs its own developer account, package, metadata, accessibility and device QA. There are no XR binaries or store submissions in this repository yet.
