# Glowpath 0.3 verification

22 November 2026. This record applies to 0.3.0+3. The earlier accessibility plan documents the 0.2 pass and remains historical evidence.

## Automated and build results

- `flutter analyze`: no issues.
- `flutter test --reporter expanded`: **75 tests passed** after the final semantic fixes.
- `flutter build apk --release`: passed; development-signed review APK packaged and verified.
- `flutter build web --release --no-web-resources-cdn`: passed; engine/font assets served locally.
- `flutter build ios --release --no-codesign`: passed; unsigned `Runner.app` produced. This does not establish device installation or App Store acceptance.
- Android package identity, permissions, ABIs, SHA-256, development certificate and 16 KB ZIP alignment were checked during this version's build review.

Coverage includes authored opening boards, valid generated routes, old-save compatibility, serialized persistence, per-mode boards and undo history, frozen unfinished Daily dates, assistance and once-only rewards. Voyage boundaries cover five-route destinations and 25-route galaxies. Hint regressions distinguish preview from rotation and follow the connected route when choosing a relay.

UI checks load the real bundled fonts. Twelve viewport/text-scale pairs cover 320×568 through 1280×900, portrait and landscape, with text scales through 3×. Checks measure every tile at at least 48 logical pixels with no overlap, exercise scroll access to tools and sheets, and validate semantic labels and representative text contrast. They are not a full color-contrast certification for every custom-painted state.

Specific interaction regressions verify that completion leaves the board at the same coordinates on 320×568 and 390×844 layouts; Next remains usable during the arrival animation; switching modes and continuing from the map resumes the correct saved board; and keyboard activation turns a tile once. Android disable-animations and iOS reduce-motion flags independently make turns and arrival immediate. The introductory relay is announced without marking assistance; destination semantics report Voyage progress or Daily completion correctly.

## Browser inspection

The release web build was exercised through the in-app browser. The existing `127.0.0.1` save was preserved; a separate `localhost` origin was used for fresh first-play testing.

- First route: one unassisted tap opens the portal, collects three stars, and earns 200 points.
- Second route: first hint outlines a relay without adding a move; the second turns it; Undo restores the prior orientation and move count. Three manual turns finish the route after undo. Assistance remains recorded.
- 390×844: endpoints, board, tools and completion action are visible. Voyage map displays all five destinations and its continuation action.
- 844×390: board and tools sit alongside each other and fit at normal text size.
- 320×568: the page scrolls to expose tools while maintaining usable tile sizes; board and tools can be visible together after scrolling. Not every heading and control fits simultaneously on this short screen.
- Modal content, original vector scenery, route glow, final board and map were visually inspected. Temporary viewport overrides were removed afterward.

Screenshots:

- Phone play (local review artifact: `phone-play-0.3.jpg`)
- Phone completion (local review artifact: `phone-completion-0.3.jpg`)
- Voyage map (local review artifact: `voyage-map-0.3.jpg`)
- Landscape play (local review artifact: `landscape-play-0.3.jpg`)

## Remaining evidence

Physical-device TalkBack/VoiceOver, haptics, interruption/resume, large-text ergonomics and frame pacing remain unverified. No frame-rate or battery claim is made. Existing-user migration is covered by controller tests; an installed 0.2→0.3 upgrade should still be checked on a phone. No measured retention, revenue, award potential or player-preference improvement follows from these checks.

Publication remains gated on user review and production signing/store preparation. This pass added no cloud resources, advertisements, analytics, subscriptions or paid assets. Existing model usage remains a resource cost; exact token charges were not available and are not invented. Research was divided into bounded reviews, reused in implementation, and documented in [the UX direction](UX_DIRECTION_0_3.md) and [evidence register](RESEARCH_EVIDENCE_0_3.md).
