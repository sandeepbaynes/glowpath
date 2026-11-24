# Glowpath 0.4.1 — return to the puzzle

22 November 2026. This correction follows direct user review: 0.4 was overdone, needed too many clicks, had weak linear-looking flight animation, repeated its planet visuals and used distracting parallax. Those observations outweigh the earlier feature plan.

## Implemented direction

- **Zero prerequisite taps.** Default `GlowpathApp()` opens the retained 0.3 puzzle, without a briefing, Begin or Launch gate. Its first meaningful action is a relay turn. Success gets a short on-board payoff, then the rocket automatically approaches the next route in depth. A single Play starts the next puzzle; it is also available during the payoff to skip the wait.
- **Expressive, contained touch feedback.** Relays use a 270 ms overshoot-and-settle rotation. Rapid taps remain responsive, Undo reverses to the exact logical orientation, and hit targets never scale or move. Subtle tile shading gives the board material depth. The completion courier now rounds bends and leaves a tapering light trail; the final flare decelerates.
- **Depth belongs in the optional voyage map.** The five destinations have distinct artwork, silhouettes and materials. Perspective projection divides world coordinates by camera depth; approaching the scene increases apparent size and produces radial star movement rather than scrolling a level list vertically. This is illustrated perspective, not a new 3D engine or a claim of finished cinematic graphics. The full voyage map remains optional. A compact scene also shows automatic travel to the next route, with one Play action and no separate debrief/continue/launch chain.
- **Quiet ambient space.** The restored home has no pointer or accelerometer sway. Its layered backdrop uses a seamless 64-second cycle with approximately 0.65–2 logical pixels of lateral movement. The board stays still. A painter-only repaint keeps scenery updates separate from puzzle layout. Backgrounding, disabled tickers and Reduce Motion stop the animation.
- **Keep the good baseline.** Voyage, Daily trio, staged hints, Undo, optional difficulty, local persistence, descriptive tile semantics and large-text layouts stay in place. The newer mission source and `glowpath.missions.v1` saves are retained separately; active progress returns to `glowpath.snapshot.v1` with no conversion or deletion.

## Automatic launch timing

The user clarified timing after the initial rollback request: the rocket should warm up during the timer itself, with no Commit step, a one-minute ceiling and shorter windows for harder puzzles. The inline 62 px instrument shows seconds, a shrinking time rail and a shaded rocket whose engine glow and exhaust strengthen as the deadline approaches. It adds no button or independent repeating animation.

Introductory routes receive 60/55/50 seconds. Generated Gentle/Steady/Bright routes begin at 60/50/40 seconds, reduce by five seconds per five levels, and stop at a 20-second floor. The clock starts when a board is ready; after success it waits at the next stop until Play. Completing the route launches immediately. At zero, input is frozen and an incomplete route fails; Retry preserves edits and starts a fresh window. A turn reconciles the monotonic clock before editing, so a tap cannot race the periodic display update after the deadline.

Elapsed time is measured with Stopwatch, not wall-clock time. Help, map, settings, nested restart confirmation and backgrounding pause active time. Opening a different mode or restarting the process gives the restored plan a fresh window; remaining time is not persisted in this review prototype. The old generated-puzzle scoring remains unchanged. No hidden random failure was introduced.

## What was removed from the active flow

Mandatory briefings, manual launch, long ignition, cockpit flight and debrief are no longer the default loop. Advanced 0.4 mission rules, reactive phone tilt and its single catalog Daily mission are dormant with that experiment. The earlier 0.3 interface is intentionally restored rather than repopulated with its gauges and controls.

A future flight needs one convincing art-and-motion slice before it returns: original modeled forms, coherent light and materials, acceleration, bank anticipation and a brief landing payoff. It must be optional, preserve the immediate Next action, and pass visual review before more content is built. A spring curve alone does not establish that quality. No claim of full 3D flight polish is made for this revision.

## Verification

The final full suite passed **165 tests**; static analysis found no issues. Added evidence covers the uninjected default home, restrained overshoot/exact Undo, real active-time expiry, late-input rejection, retry preservation, paused help/nested dialogs/background, automatic next-stop travel, one Play, next-clock gating and once-only rewards. Map/background tests cover depth projection, distinct scene rendering, stopping motion and stable board coordinates. New instrument and next-stop tests cover small screens and 3× text; both OS reduced-motion flags complete travel immediately.

Final Android release, web release with local engine assets and unsigned iOS release builds succeeded. APK signature, version, permissions and 16 KB ZIP alignment were verified; iOS version/build were checked. Historical package hashes are retained with the build artifacts.

The actual web build was reviewed at390×844. Preserved Voyage/Daily saves resumed; the clock started without a launch gate; opening the map held remaining time; all destination materials were visible. Staged hints completed the route, followed automatically by the route11 next-stop scene and one Play action. That scene is left open for review. The test suite separately verifies that waiting there does not spend the next clock. No browser storage was erased.

Actual browser captures: countdown board (local review artifact: `puzzle-countdown-0.4.1.jpg`), depth map (local review artifact: `voyage-depth-0.4.1.jpg`), automatic next stop (local review artifact: `next-stop-0.4.1.jpg`). These show the implemented app, not concept mockups. The continuous backdrop and travel renderer were also inspected in focused widget tests; this is not a measured device frame-rate or battery claim.

Physical-device motion comfort, haptics, TalkBack/VoiceOver and frame pacing still need review. No retention, revenue or award claim is supported by this pass. No new subscriptions, paid assets, audio or cloud services were used.
