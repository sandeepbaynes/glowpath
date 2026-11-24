# Navigation, startup and failure — 0.4.5

The current revision addresses three player reports: the lost rocket was too small to explain failure, top navigation was hard to reach, and returning to Voyage replayed a completed puzzle before showing the destination.

## One consistent route through the app

Voyage and Daily restore their saved state directly. An unfinished round opens its puzzle; a completed round opens its reached destination with Play available immediately. Selecting the active mode does nothing. The board payoff and 2.6-second onward flight happen only after a new solve. Restoring a completed save on cold launch also skips the completed board and arrival replay.

The persistent bottom console exposes Voyage, Daily trio, Help and Settings directly. Mode targets are at least 64 logical pixels high; utility targets are at least 56 pixels wide and 64 high. It reserves layout space above device safe insets and never floats over the puzzle. On narrow screens with large text, the two modes get a full row and utilities move to a second row. The destination header also stacks to preserve readable text width. Control positions and identity remain unchanged between gameplay, destination and modes.

## Loading

An original luminous route and three-star mark introduces Glowpath on navy. Web shows this before Flutter loads; Flutter shows it until the local save is ready; native launch screens use the same mark and background. There is no minimum wait or extra action. Loading transitions smoothly into the saved screen. The splash is static and supports reduced motion and large type.

## Readable failure

The full-screen interruption now uses a 3.1-second sequence: a large powered ship approaches an amber conduit break, loses guidance, then banks onto a curved drift trail. The final rocket remains opaque and 56–82 logical pixels long rather than shrinking into an almost invisible point. The broken route persists, with “The route was incomplete at launch” and “Your route is saved.” This is a schematic explanation, not a simulation of the player's exact board cell. Retry is immediately available, stationary and the only active action. The prior root dissolve remains; important contact occurs after it is visible.

Reduced motion shows the same final scene immediately. Short landscape screens use illustration and recovery side by side; large text can scroll. Retry retains all edited relay rotations and moves and grants a new launch window.

## Verification

Static analysis is clean and all 245 tests pass. A final background-contrast adjustment also passed all 15 focused failure tests before the release rebuilds. Coverage includes restored completed Voyage on tab changes and cold load, rapid mode changes, repeat selection, phone and tablet safe-area geometry, 3× text, fixed touch targets, failure input isolation, keyboard Retry, reduced motion and final rocket visibility. Eight tablet configurations remain covered by the existing suite. Native device frame pacing and launch-screen appearance still need physical-device review.

No new dependency, paid asset, subscription, tracking or backend was added. Existing saves and prior review builds are preserved. This is a review candidate, not a store publication.

## Preview review and artifacts

The release web preview was checked at 390×844, 820×1180 and 1366×1024. The saved completed Voyage opened directly to route 26; switching to the unfinished Daily route and back preserved both modes, with no completed-board replay. Timeout exposed only Retry in the accessibility tree; Retry restored the unchanged Daily route and its 40-second window. The viewport override was reset and the original Voyage destination left ready for review.

- Phone destination and dock (local review artifact: `navigation-0.4.5-phone.jpg`)
- Phone gameplay and dock (local review artifact: `navigation-0.4.5-gameplay.jpg`)
- Portrait tablet (local review artifact: `navigation-0.4.5-tablet-portrait.jpg`)
- Landscape tablet (local review artifact: `navigation-0.4.5-tablet-landscape.jpg`)
- Final failure scene (local review artifact: `failure-0.4.5-phone.jpg`)
- Rendered Flutter splash (local review artifact: `splash-0.4.5-phone.png`)

Android, web and unsigned iOS release builds succeeded. Version is 0.4.5+9. The APK signature and 16 KB ZIP alignment passed; exact metadata and checksum are in the package verification (local review artifact: `glowpath-0.4.5-verification.txt`).
