# Glowpath 0.4.3 — clearer controls and a living sky

22 November 2026. This pass addresses the awkward success header, imperceptible background movement, inconsistent screen styling, unclear planet/map affordance and ambiguous timeout state.

## Screen decisions

- **Navigation and arrival:** Voyage and Daily stay grouped; utility icons sit opposite. Removed the detached selection stroke and reduced the oversized success headline to a compact flight receipt with a completed-signal emblem. The full-device universe, elastic exploration, 2.6-second arrival and single Play action remain.
- **Gameplay:** Custom console controls now include hints and Undo. Destination typography is more compact. The planet shortcut has an orbit outline, arrow badge and explicit “View map” label; the same single tap opens the map.
- **Timeout:** A full-device overlay blocks both input and accessibility focus behind it. A 1.2-second eased lost-rocket sequence leads to “Signal lost” and “Your route is saved.” Retry is the only action and works immediately, including during animation. It retains rotations, moves and assistance, and opens a fresh countdown. Reduced Motion skips decorative animation.
- **Daily:** A small orbital day-progress instrument and HH:MM:SS countdown replace the plain midnight sentence. It describes UTC midnight. An older preserved route shows “New trio ready” without discarding or changing that route.
- **Help:** Beacon, star and portal symbols match the three rules. Launch, hint and scoring explanations have distinct headings and quieter supporting type. The close action stays fixed while long content scrolls.
- **Settings and restart:** Pace choices use the navigation style; preferences use custom segmented instrument rails with proper switch semantics. Restart uses the shared console action. The confirmation remains explicit and preserves its cancellation behavior. The legal page reports version 0.4.3.
- **Voyage map and licenses:** Reviewed within the shared panel shell. Readable destination progress and legal content remain intact. No new navigation gate was introduced.

## Motion correction

The previous loop was running, but about one pixel of movement across 64 seconds was effectively invisible. Planet surfaces were static. Both puzzle-home and voyage now use smoothly gliding star layers (roughly 0.3–1.6 logical pixels per second) and a 180-second planet-surface rotation. Surface details turn on the sphere while lighting, silhouettes, rings and flight targets stay anchored. Star movement loops over 60 seconds without a jump. Background contrast is slightly stronger on the puzzle screen.

Ambient changes repaint scenery rather than rebuilding controls. Reduced Motion, disabled animations, inactive lifecycle and disabled tickers suppress or pause decorative motion. Puzzle hit targets stay fixed.

## Verification

The final source passed **211 tests** and static analysis with no issues. Coverage includes the eight tablet viewport configurations from 0.4.2, phone and 3× text layouts, keyboard and switch semantics, full-device timeout coverage, blocked underlying controls, immediate Retry, preserved route edits, daily midnight behavior and visible ambient pixel changes within two seconds. Surface rotation is checked across all five worlds while geometry remains fixed.

The rebuilt browser app was reviewed at 390×844, 820×1180 and 1366×1024. Timeout exposed only Retry in the accessibility tree; retry restored the same six-turn route with a fresh clock. Staged hints then completed that route, and arrival stopped at route 15 ready for Play. Daily, the map, flight notes, settings and licenses were also inspected. Package identity and checksum were checked during this version's build review.

Review captures: gameplay and map shortcut (local review artifact: `gameplay-0.4.3.jpg`), arrival (local review artifact: `arrival-0.4.3.jpg`), tablet landscape (local review artifact: `arrival-tablet-landscape-0.4.3.jpg`), timeout (local review artifact: `timeout-0.4.3.jpg`), Daily reset (local review artifact: `daily-reset-0.4.3.jpg`), flight notes (local review artifact: `flight-notes-0.4.3.jpg`), settings (local review artifact: `settings-0.4.3.jpg`), voyage map (local review artifact: `voyage-map-0.4.3.jpg`).

Automated viewport checks do not establish physical-device frame pacing, heat, battery life, haptics or screen-reader experience.

No new paid service, asset purchase, advertising, analytics or publication is part of this pass. Visual quality is a product improvement, not evidence of retention or a revenue guarantee. Player feedback and measured economics remain the next commercial gates.
