# Immersive Glowpath across headsets

Design contract updated 26 November 2026. This document describes the intended spatial edition and the verified platform capabilities supporting it. It is not a claim that all headset builds are complete. The previous Vision Pro iPad compatibility window was only a rendering check; it does not meet this design. The [native visionOS prototype](../../spatial/README.md) now compiles for Simulator Debug and unsigned physical-device Release, with twelve worlds and one eighteen-piece surrounding route. Simulator hover works, but automated taps have not activated the buttons or pipe targets. Simulator playthrough, physical hands and walking remain unverified. Debug-only route/solved previews test composition and rocket motion, not input or full-game parity.

## The player is inside the game

Voyage is a surrounding galaxy. Planets occupy different distances, heights and directions, including behind the player. Nearby worlds are distinct, detailed objects; distant worlds become smaller and quieter. Turning the head reveals the rest of the system. The selected planet remains a clear landmark, with a route ribbon and a recognizable launch beacon.

The puzzle is a three-dimensional assembly surrounding the player, initially shaped as a rounded cylindrical or spherical shell. START is on the left and FINISH on the right at the initial orientation. The valid route can travel around the back, above and below the player's comfortable eye line before reaching the destination. Tubes have depth, connection collars and illuminated interiors. They are not images on a rectangular board.

A player can hold a segment and rotate it to a permitted orientation, or poke it for one quarter-turn. A valid connection lights progressively from START. The solution depends on all connections, not just the portion visible in front. Directional sound and a small edge beacon identify a disconnected section without drawing a full-screen arrow over the scene. The rocket flies through the same physical-looking route after completion; stars and optional cargo react where the rocket actually crosses them.

The same world works seated. A dedicated orbit handle rotates the puzzle or galaxy around the player, so no level requires turning the body, kneeling or reaching overhead. Optional discrete angle steps provide an alternative to continuous environment rotation. Rotation preserves the world relationship between START, FINISH and every tile; it does not change puzzle state or scoring. A recenter action returns to the initial left/right presentation. The player can stop rotation immediately, and critical controls remain accessible.

These are product decisions. Initial prototypes should validate readable geometry and precise interaction before adding denser scenery, advanced obstacles or short timed challenges.

## Walking and elastic exploration

Real head translation and rotation must remain mapped one-to-one to the tracked camera. We do not slow, spring or secretly redirect the player's physical movement. Elasticity belongs to the **virtual galaxy navigation offset**, independent of headset tracking.

Walking a small distance can reveal parallax and browse nearby worlds. Beyond a comfortable exploration range, additional virtual travel has diminishing returns; future planets appear progressively farther away. When browsing ends, the virtual selection offset settles gently toward the selected accessible planet. This return moves distant map content, not the player's camera, floor reference or system boundary. Completed planets remain selectable for replay.

Long-distance travel uses an explicit navigation action: pull the route toward you, select a visible destination, or use a controller axis. A small room must offer the same progress as a large room. The walking feature is an optional enhancement, not an instruction to walk endlessly forward or backward in a headset.

Apple currently documents an approximately 1.5-metre system boundary around the starting head position for fully immersive experiences; leaving it ends immersion. This makes long physical walks unsuitable as the primary Voyage mechanic on Vision Pro. Keep platform boundaries and passthrough interruption intact. [Apple fully immersive experiences](https://developer.apple.com/documentation/visionos/creating-fully-immersive-experiences).

## One interaction vocabulary

| Intent | Hands | Tracked controllers | Common game action |
| --- | --- | --- | --- |
| Inspect | Hover near a piece or aim at it | Aim a ray or approach with the controller | Highlight a candidate; no state mutation. |
| Turn one step | Poke or pinch-select | Trigger/select | Commit one allowed quarter-turn. |
| Hold and turn | Grab and rotate | Grip and rotate | Preview a turn; snap to a legal orientation on release. |
| Explore a planet | Grab/spin, then release | Grip/spin, then release | Apply damped visual spin; preserve its map position. |
| Rotate the surrounding world | Drag an orbit handle | Grip the handle or use a turning action | Rotate content around the player; retain puzzle state. |
| Browse the galaxy | Pull the route or select a destination | Navigation axis or select a destination | Change the bounded virtual map offset. |
| Recover | Accessible recenter/exit controls | Recenter/exit action | Restore orientation or leave immersion without losing the route. |

Input adapters emit semantic actions rather than writing directly into the rules engine. Hand tracking loss cancels an unfinished grab and restores its last committed orientation. An object is not activated by gaze alone. Timer behavior must account for tracking interruption, app focus and recentering. Gesture names, haptic strength and selection distance are adjusted per runtime without changing route validity.

## Platform capability and implementation matrix

| Platform | Verified capability | Proposed Glowpath implementation | What must be verified before release |
| --- | --- | --- | --- |
| **Apple Vision Pro** | SwiftUI `ImmersiveSpace` presents unbounded content. RealityKit renders the scene; system direct/indirect gestures and ARKit support object interaction and custom hand input. | Native SwiftUI/RealityKit scene. Use entity input targets for select/turn, direct manipulation for grabs, and ARKit only where joint-level data is necessary. A small entry/exit interface may be a window; the galaxy and puzzle are immersive entities. | Simulator interaction, then physical reach, tracking loss, seated play, system boundary, frame time and comfort. [ImmersiveSpace](https://developer.apple.com/documentation/swiftui/immersivespace), [Apple input guidance](https://developer.apple.com/visionos/get-started/). |
| **Meta Quest / Oculus Quest family** | Meta's Unity XR integration reads headset, hands and controllers through OpenXR. Its interaction rig supports poke, ray, grabs and locomotion; the Unity XR route does not expose every Meta Core SDK feature. | Shared OpenXR scene with Meta Interaction SDK adapter. Quest 3/3S are the first physical test targets. Retain controllers alongside hands and tune scene detail for standalone GPU limits. | Hand/controller parity, pinch and poke reliability, boundary interruption, sustained frame time and Quest-specific store package. [Meta Unity XR integration](https://developers.meta.com/vr/documentation/unity/unity-isdk-getting-started-unityxr/). |
| **Android XR headsets** | OpenXR supports hand interaction and 6DoF controllers; Google's Unity guidance treats hands as the default because controllers may not be included. Basic hand interaction poses differ from permission-gated joint data. | Same OpenXR scene and semantic actions, with Android XR input profile/extension adapter. Support hands without requiring controller hardware. | Physical headset interaction and rendering. The Android XR emulator currently does **not** support Unity/OpenXR applications, so emulator availability is not proof of this build. [Unity input](https://developer.android.com/develop/xr/unity), [OpenXR support](https://developer.android.com/develop/xr/openxr). |
| **PICO** | The Unity OpenXR hand-tracking guide lists Neo3, PICO 4 and PICO 4 Ultra families. Its richer Hand Interaction Profile extensions are listed for the Ultra family, not all models. | OpenXR scene with runtime capability checks. Use joint-based interaction adaptation where required and tracked controllers as an alternative. Do not assume identical extensions on every PICO. | One supported Ultra and each older claimed model, tested against the chosen SDK/OS combination. [PICO Unity OpenXR hand tracking](https://developer.picoxr.com/document/unity-openxr/hand-tracking/). |
| **SteamVR / PC VR, including compatible Rift and VIVE configurations** | SteamVR maps OpenXR controller bindings, but Valve calls out custom bindings for Vive wands, Index and Windows Mixed Reality controllers. VIVE provides separate hand-tracking integrations; hands are not universal across PC VR. | Windows OpenXR scene with controller-first defaults and optional hand adapters where available. Use explicit action bindings and headset/runtime capability reporting. | Physical runtime/controller combinations, Windows build, seated/standing behavior and correct store requirements. [Valve OpenXR bindings](https://partner.steamgames.com/doc/features/steamvr/settings), [VIVE hands](https://developer.vive.com/resources/openxr/unity/tutorials/hand-tracking/). |

“Same on all VR headsets” means the same surrounding galaxy, spatial puzzle, rules and seated alternative on each supported target. It does not mean one binary, identical tracking capabilities, or an untested promise for every historical headset.

Legacy support needs a deliberate cutoff. Meta no longer accepts new Quest 1 apps; its announced update cutoff was May 2025. Quest 2 and Quest Pro remain conditional targets: Meta's November 2026 announcement allows new submissions through December 2027, with a final feature release in March 2027. They require a tested older-device quality tier and a pinned compatible SDK. Go/Gear VR and other legacy 3DoF-only devices are outside this six-degree-of-freedom design. [Quest 1 changes](https://developers.meta.com/vr/blog/changes-coming-quest-1-2023-meta/), [Quest 2/Pro transition](https://developers.meta.com/vr/blog/meta-quest-2-quest-pro-end-of-feature-development-what-to-know/).

## Shared data, native presentation

The implementation path is a native RealityKit client for visionOS and an OpenXR client for the other headset families. Unity with XR Interaction Toolkit/XR Hands and small vendor adapters is the proposed OpenXR engine path. This is an architecture choice, not an installed, built or licensed Unity project on this Mac yet. Do not introduce an engine subscription without checking the project's eligibility and the user's approval.

Share a versioned level and replay format: stable tile IDs, 3D placements, ports, legal rotations, connections, stars, cargo and start/finish endpoints. Pure route validation and test fixtures are independent of the renderer. Export matching reference replays and verify the result in Swift and the OpenXR client before sharing scores. A new native geometry experiment does not automatically have parity with every mobile obstacle.

Keep head pose, hand joints and physical room information local to interaction. Cross-platform analytics should record coarse game events such as route completion and input mode; raw biometrics, room scans or movement trails are not required to measure engagement.

## First acceptance milestone

1. Enter the galaxy and see authored objects ahead, behind and to both sides; no rectangular game container remains.
2. Move the head and take a small step: parallax is stable, physical movement is tracked normally, and map browsing respects the platform boundary.
3. Start one spatial route that uses the front, back, upper and lower areas, with visible START and FINISH beacons.
4. Complete it using hands, and repeat with the supported controller/indirect alternative. A hold rotates a piece; a poke turns one step; released pieces snap accurately.
5. Solve the same route while seated using environment rotation, without needing an overhead reach or body turn.
6. Follow the rocket through the actual 3D route and collect the same stars as the rules engine predicts.
7. Interrupt tracking, recenter and return from a system interruption without losing committed progress or consuming unfair timer time.

A simulator proves scene composition and some software behavior. Real hand reach, physical walking, comfort and performance require the corresponding headset. Release notes must identify which of these checks actually passed for each target.
