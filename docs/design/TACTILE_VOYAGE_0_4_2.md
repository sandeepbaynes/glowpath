# Glowpath 0.4.2 — one universe, familiar actions

22 November 2026. Direct user feedback requested space-themed controls, resistant drag exploration, a slower onward flight, a scene filling the device and restoration of gentle continuous background motion.

## Interaction and composition

Play is now a custom-drawn console key with clipped corners, a small launch glyph, edge lights and restrained press/release feedback. Voyage and Daily are labelled orbital signals, not raised pills. Their actions, names and selected states remain the same. The optional map continuation action uses the same visual language. No confirmation, hold gesture or extra navigation step was added.

The next-stop universe fills the viewport behind floating controls; it has no rounded image container. The onward approach lasts 2.6 seconds instead of 1.1 seconds. Play remains usable throughout the animation. The route and Play dock sit closer to the planet rather than at the extreme bottom, and the backdrop continues behind them. Large text and short screens retain scroll access to the controls.

Dragging down explores forward through depth; dragging up reveals previously charted space. Each extra finger movement produces less camera movement as it leaves the accessible destination. Releasing or cancelling returns with a damped spring and a small overshoot. Re-grabbing immediately holds the current view. This changes the camera only: it does not unlock routes, activate Play, change progress or spend the next countdown.

The same exploration widget runs in the optional map. Its drag recognizer stays inside the universe; a pull there does not dismiss the sheet. Keyboard up/down and screen-reader adjustment provide corresponding preview actions. Reduced Motion preserves direct manipulation and returns immediately on release.

Gentle idle movement is enabled in the app's voyage scenes. Its seamless 64-second loop moves far stars by subpixels, near stars by about one pixel and nebula layers by at most two pixels, with small body drift. It repaints decorative layers without rebuilding controls or moving hit targets, and pauses for reduced motion, inactive lifecycle and disabled tickers. Motion stays small and slow rather than following phone/pointer movement.

Landscape framing uses the available height when sizing planets, orbits, the courier and its path. Portrait composition remains unchanged apart from the lowered scene focus and raised route dock, which close the previous empty gap. The backdrop stays full-device in both orientations.

## Verification

The final full suite passed **195 tests** and static analysis reported no issues. Android, locally served web and unsigned iOS release builds succeeded. APK signing, identity and 16 KB ZIP alignment were checked; iOS version/build are 0.4.2/6. Historical package records are retained with the build artifacts.

Focused tests cover custom control pointer/keyboard activation, cancellation, selection semantics, large type, full-device scene bounds, interaction through the floating controls, spring resistance/return/re-grab, reduced motion, modal gesture ownership, and unchanged progression/countdown behavior. Pixel comparisons confirm that the idle scenery changes without rebuilding the HUD; pause tests cover lifecycle, reduced motion and disabled tickers.

Tablet layout tests exercise 744×1133, 1133×744, 820×1180, 1180×820, 1024×1366, 1366×1024, 800×1280 and 1280×800 logical-pixel viewports, with 2× text on selected cases. They verify usable puzzle targets, completion, full-device scenery, drag/release and one-Play progression. Geometry tests check all five worlds and five route markers at 21 points during arrival in all eight tablet viewports, keeping the current planet core, docking target and full courier visible. Existing phone and 3× text accessibility checks remain passing.

The rebuilt web app was visually checked at 390×844, 820×1180 and 1366×1024, including drag and spring return. Captures: phone (local review artifact: `universe-phone-0.4.2.jpg`), tablet portrait (local review artifact: `universe-tablet-portrait-0.4.2.jpg`), tablet landscape (local review artifact: `universe-tablet-landscape-0.4.2.jpg`). These are viewport checks, not physical tablet performance measurements.

Review remains local. No subscriptions, services, asset purchases, ads, analytics or publication were added. Physical-device spring feel, motion comfort and frame pacing still need player review.
