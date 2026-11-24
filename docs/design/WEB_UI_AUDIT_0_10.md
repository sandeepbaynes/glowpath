# Glowpath 0.10 web and app review

Reviewed 23 November 2026. Source version: **0.10.0+22**. This is a review build, not a published or monetized release.

## Changes

- Cargo: six original projected 3D meshes with perspective, depth ordering and lighting. Drag the specimen to rotate/tilt; swipe the description/footer area to browse. Matching orbital chevrons, keyboard controls, screen-reader rotation actions and double-tap reset remain available. There is no continuous model spin. Original board pickup art and inventory semantics are unchanged.
- Removed the dark gradient strip in both Cargo and Trails. Increased specimen title/inventory space at large text sizes after the browser audit caught captions shrinking too far.
- Achievements: twelve distinct original illustrations tied to the real achievement registry, including an antenna, planet, galaxy, precision route, expedition, cargo cabinet and dawn window. Swipe navigation also works for Trails and reading pages. A swipe previews a trail; it does not silently equip it.
- Flight Notes: titled lessons and original diagrams for routing, stars, timing, fixed/one-way/linked relays, crossings, portals, gravity and defense. Swipe/keyboard paging and a clear return-to-flight action.
- Flight Controls: Flight/Feel/About sections, route and sensory previews, and swipe navigation. Existing controls, persistence, restart confirmation and service actions remain intact.
- Tablet/desktop secondary panels are centered and rounded on all corners. Phone panels remain bottom sheets. Keyboard focus stays within the active panel; timer pause, nested panel replacement and reduced-motion dismissal are retained.
- Board legend now consistently says START and FINISH. Web metadata matches the current game and bundled artwork/fonts require no third-party font host.

No AI-generated raster imagery, stock achievement icon pack or new paid asset service was added. The new artwork consists of code-drawn diagrams, illustrations and geometric meshes in the existing palette.

## Browser coverage

The isolated review entry point uses temporary preferences and labelled mock services. Most scene clocks are frozen for visual inspection; the explicit live-clock check below uses real elapsed time.

| Viewport | Scope |
| --- | --- |
| 320 × 568 | All 22 scene states |
| 393 × 852 | All 22 scene states |
| 844 × 390 | All 22 scene states |
| 1024 × 1366 | All 22 scene states |
| 1440 × 900 | All 22 scene states |

The 22 states are onboarding, opening puzzle, advanced puzzle, Daily, Weekly, arrival, Voyage landing, Trails, flight support, league, controls, notes, failure, splash, planet approach, optional-cargo route, Cargo, earned supplies, Daily result, Weekly result, achievements and route records. Captures were inspected in contact sheets, with full-size inspection of the redesigned screens. Changed scenes were recaptured after integration. There were no captured browser console errors.

Additional browser checks cover 3× text for Cargo, achievements, controls and notes; Feel/About and credits; model rotation; carousel swipes; and restored control states. Large text uses explicit reading pages where needed. The third-party license catalogue retains its standard scrollable legal reader; gameplay and collection panels do not rely on scrolling.

Evidence: screen captures (local review artifact: `web-audit-0.10`), redesigned surfaces (local review artifact: `0.10-gallery-review.png`). Capture dimensions are CSS pixels. Browser resizing is not equivalent to testing physical mobile Safari or touch hardware.

## Interaction and game verification

- Completed the opening route through browser drag gestures: all three stars, 14 scored quarter-turns, successful dock and 30 coins/3 stars. That solve used the frozen review clock and is not a difficulty/retention study.
- A separate live-clock route counted down from 30 seconds through timeout, showed the full-screen loss scene, and exposed Retry. Retry restored the puzzle and a fresh clock. Opening Controls and its nested license page paused the attempt until dismissal.
- Dragging the Cargo model changed its 3D orientation without selecting a different specimen. Swiping below advanced Moon pearl to Comet shard. Swiping achievements advanced to the distinct Planet finder artwork. Flight Notes and Controls swipes changed pages/sections.
- The complete regression suite passed **688 tests** with clean static analysis. After the final Cargo caption adjustment, all **21 cargo/gesture/supply checks** passed again. Coverage includes 14 gameplay viewport/safe-area cases through 1920 × 1080, challenge handoffs, replay/undo, saved progress, 3× reading, reduced motion, modal focus and timer behavior.

## Build and release boundaries

Portable root and `/glowpath/` static web bundles are produced by `tools/package_web.py`, with checksum manifests under `build/review/`. The repository-subpath build loaded its bundled fonts, rendering assets and first-flight screen successfully at `/glowpath/`, with no browser console errors. It is a free noncommercial preview, with real ads and purchases off. The root review build uses labelled local mocks. The main iOS update was installed in place using `devicectl`; no uninstall or store submission was involved. The final large-text Cargo caption fix was built and signed but was not reinstalled during that review.

Native frame pacing, rotation feel, VoiceOver, battery/heat and haptics still need physical-device review. Shared scores, account sync and live ad/purchase services are not activated. Browser checks confirmed that existing stars and the active route survived the update.

See [web hosting and H5 ad requirements](../WEB_RELEASE.md). GitHub Pages is not assumed to permit an ad-funded commercial game. Publishing and monetization require a separate deployment review. These checks establish the tested behavior; they do not establish perfection, retention, revenue or Apple editorial selection.

## 0.10.1 desktop and controls refinement

- First-planet backward drags now use a resistance curve sized to the available backward travel, rather than saturating at a hard clamp. Forward exploration, completed-route access and the return spring remain intact. Focused checks cover progressive movement, release velocity, re-grabbing and return to Planet 1.
- Desktop gameplay uses a centered foreground area up to 1100 × 840 CSS pixels (600px wide in narrow laptop windows), with a 520/540px board cap. The universe remains edge to edge. The Voyage landing remains full-screen; iOS/Android tablet boards keep their larger touch sizing.
- Gentle, Steady and Bright are explicit radio choices with checked states and route/time descriptions. Only Flight, Feel and About use underlined section navigation. Content starts 16px beneath the tabs at normal text sizes; the desktop controls panel is 620px tall. Dense and large-text layouts keep focused pages and full text.
- All **700 integrated tests** passed before the final spacing refinement. After that refinement, **30 settings/pace/carousel/adaptive-panel checks** passed; static analysis remained clean. Six desktop sizes from 668 × 862 to 1920 × 1080 verify Voyage/Daily/Weekly bounds, usable targets and no scroll extent. A portrait-iPad check confirms its larger board remains unchanged.
- Browser checks at 832 × 1194 and 1728 × 1117 show the narrower desktop board. Phone-size review confirms Bright selects immediately as a radio option. A backward drag at the first destination returns to Planet 1.

Evidence: narrow laptop (local review artifact: `0.10.1-after-narrow-desktop.png`), wide laptop (local review artifact: `0.10.1-after-wide-desktop.png`). Physical haptics and device frame pacing remain unverified in this patch.

The final 620px desktop Flight Controls panel, phone top alignment and 3× pace-choice page were verified in the browser. Desktop controls (local review artifact: `0.10.1-pace-desktop.png`), phone controls (local review artifact: `0.10.1-pace-phone.png`), large-text choice (local review artifact: `0.10.1-pace-large-text.png`). Version 0.10.1+23 release web and iOS builds succeeded; the iOS signature verifies. ZIP integrity and its SHA-256 manifest were checked. Packaged scripts now use content hashes to prevent the observed stale-review cache issue. The signed native patch has not been installed on a device.

The final main preview loaded the hashed scripts, retained Viridian route 2/15 with 105 stars and 21 coins, and is paused on Flight Controls. No browser console errors were captured. Live controls (local review artifact: `0.10.1-pace-live.png`).

## 0.10.2 landscape panel and loss state

- The right panel groups destination, launch clock, guidance and controls. START/stars/FINISH sits above the board in roomy landscape views. Hint is a full-width action; Undo and a labelled Skip share the next row. Route performance and banked rewards have separate readable rows. Short landscape screens retain their compact arrangement.
- Fixed guidance/action/stat slots preserve the same header, clock, board and control bounds when switching Voyage, Daily and Weekly. The first regression run caught a 3px shift; the correction passes the existing exact-geometry test and the phone/tablet/desktop viewport suite.
- Landscape failure no longer reserves an empty illustration column. The rocket film uses the centered stage and fades into a stationary centered title, explanation and Retry. Portrait layout, reduced motion and retry gating are retained. Twelve new center checks cover six wide viewports with normal/reduced motion.
- **30 layout/mode-flow checks and 38 failure/launch checks pass; analysis is clean.** Browser review confirms centered failure at 1440 × 900 and 1180 × 820, and Retry returns to the puzzle. Browser dimensions are not physical-device verification.

Evidence: right panel (local review artifact: `0.10.2-flight-panel-desktop.png`), centered loss (local review artifact: `0.10.2-signal-lost-desktop.png`), tablet-size loss (local review artifact: `0.10.2-signal-lost-tablet.png`).

Final 0.10.2+24 release web and signed iOS builds succeeded. The web ZIP and SHA-256 manifest were verified before refreshing localhost. The playable preview retains 105 stars and Viridian route 2/15, paused on the Voyage landing. The native patch is built but not installed. Daily alignment (local review artifact: `0.10.2-flight-panel-daily.png`). No browser errors were captured during the final review.

## 0.10.3 flight composition and map scroll

- The guided rocket trajectory and intact route have the same midpoint at the center of the cinematic stage. Equal route extensions balance the drawing; bounded velocity keeps wide screens from stretching the flight across the frame. The fracture still meets the nose at two seconds, followed by continuous off-course motion and drift. Tail flame, fire-free fracture, reduced motion and centered Retry remain supported. The faint star-field vanishing point is centered too.
- Mouse-wheel/trackpad scrolling on every Voyage explorer follows the same directional resistance curve as touch drag. Impulses ease over 100ms, bursts accumulate and 220ms without input starts the existing return spring. The map consumes its pointer signals rather than scrolling a surrounding page. Touch takeover, backgrounding, reduced motion and disposal cancel or finish the motion safely.
- Fixed-timestep captures render the actual widget at 0/1/2/2.8/4/5.5/6 seconds on desktop, tablet and phone. They are review artifacts, not pre-rendered game assets. Centered guided flight (local review artifact: `desktop-1000.png`), fracture and drift (local review artifact: `desktop-2800.png`), phone composition (local review artifact: `phone-1000.png`).

All **729 integrated tests pass**, with clean analysis. The browser test at 1280 × 720 scrolled forward to later celestial objects, backward to earlier planets, and returned to Planet 4/Halo after input stopped. Document scroll offsets stayed at (0,0), and no browser console errors were captured. Backward wheel exploration (local review artifact: `0.10.3-wheel-back.png`), returned destination (local review artifact: `0.10.3-wheel-return.png`).

Version 0.10.3+25 web and iOS release builds succeeded; the iOS signature, web ZIP integrity and checksum were verified. Localhost now serves the update. The live preview is on Voyage with 105 stars and Viridian route 2/15; the expired attempt was retried to return to the map. The native update is built, not installed.


## 0.10.4 continuous browser scroll

The reported delay was reproduced with two wheel signals before each 16ms frame: restarting AnimationController on every signal left camera depth at exactly zero while input continued. A mutable spring simulation now retargets on one persistent animation clock. That failing regression passes with the fix. Input is scaled to 28% of touch distance; reversal preserves displayed position and velocity. A 700ms quiet interval prevents the return spring from fighting ordinary spaced wheel notches. Return motion uses a slower spring; touch resistance and release are unchanged.

The camera rail now has continuous tangents at its sideways turns. All original anchors are retained and the interpolation cannot overshoot each segment’s original bounds. Tests check projected position and velocity on phone and desktop geometry.

All **736 integrated tests pass**; static analysis is clean. Actual browser scroll actions were checked at 832 × 1194 and 1728 × 1117: small steps, consecutive steps, reversal and return to Halo. Document scroll offsets remain (0,0), and no browser errors or warnings were captured. The high-frequency event regression supplies frame-by-frame timing evidence; browser screenshots alone cannot establish physical trackpad frame pacing. Small-step response (local review artifact: `0.10.4-wheel-small.png`), desktop exploration (local review artifact: `0.10.4-wheel-desktop.png`).

Version 0.10.4+26 release web and signed iOS builds succeeded. Web ZIP integrity and its SHA-256 manifest were checked before updating localhost. The live preview loaded the new hashed scripts and retained 105 stars and Viridian route 2/15; it was returned to Voyage without replaying or resetting the route. The native build is prepared, not installed.


## 0.10.5 elastic scroll return

The previous map returned after a finite scroll stream, but its 700ms pause and overdamped spring read as a slow drift. The pause is now 550ms, with stiffness 150 and damping 18 for a short, bounded elastic rebound. The continuous input clock, sensitivity, direction-change behavior and touch gesture handling are unchanged.

All **22 focused scroll/elasticity tests pass**, and targeted static analysis is clean. The new release test reaches within 6% of home at 336ms after return begins, limits rebound to 4% of the excursion and settles exactly at zero within 1.44s. Existing 400ms-spaced wheel steps, high-frequency bursts, touch takeover, reduced motion and page-scroll containment checks still pass.

The 0.10.5+27 web package, ZIP integrity and checksum were verified and localhost updated. Browser checks at 1280 × 720 confirmed forward and backward scrolling return to Viridian; the document stays at (0,0). The new content-hashed script loaded with saved progress intact. This patch rebuilds the web preview only.


## 0.10.6 prompt scroll release

Reduced the wheel idle window from 550ms to **160ms** in response to review. The continuous input follower and elastic return spring are unchanged. All **22 focused scroll/elasticity tests pass**; return is visibly underway by 240ms after final input. Active 112ms input bursts, rapid events between frames, reversal continuity, bounded rebound, touch takeover and reduced motion remain covered. Targeted analysis is clean. The web review package and checksum were verified before updating localhost.

Browser verification loaded the new hashed script and confirmed the faster return at 1280 × 720. The saved attempt expired on initial load; Retry preserved its edits before returning to Voyage. Stars and route progression remain at 105 and Viridian 2/15. Returned map (local review artifact: `0.10.6-prompt-return.png`).


## 0.10.7 25ms scroll release

Set the requested wheel idle window to **25ms**. If a new wheel session has not yet advanced its first nonzero animation frame, the release waits for that frame instead of swallowing the input. The post-frame callback checks that input has not resumed and the session is still current.

All **24 focused scroll/elasticity tests pass**. New regressions reproduced cancellation of a single unsynchronized wheel event and long stalls in a 33ms event stream; both pass after the safeguard. Continuous 16ms bursts, reversal velocity, touch takeover, reduced motion, bounded rebound and exact settling remain covered. After an active burst the camera is heading home by 80ms after its final event. Targeted static analysis is clean.

Version 0.10.7+29 web package integrity/checksum verified and localhost updated. Browser loaded the new hashed script; a wheel notch visibly moved the map and promptly returned. Saved 105 stars and Viridian 2/15 remain intact. Returned preview (local review artifact: `0.10.7-25ms-return.png`).
