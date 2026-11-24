# Planet progression — 0.6.0 review

> Historical 0.6 / `planet-v4` record. New rounds in 0.7.2 use `planet-v5`: 4×4 opening worlds with certified route choices, coupled twins from planet 2, and winding paths that can return westward. Existing v4 rounds retain the generation rules below. See README for current controls and review status.
This iteration turns the short route sequence into an ongoing expedition with teachable mechanics, shorter clocks and explicit local previews of competition and monetization. It does not promise revenue or deliberately make solved routes fail.

## Progression and challenge

Each planet contains **15 routes**, arranged in three five-route legs. Its board size and obstacle budget stay fixed; the launch window tightens from **30 to 27 to 24 seconds** across the legs. Bright pace removes another three seconds; Gentle preserves the same 30-second ceiling. Planet 1 uses 3×3 boards and routes through all nine cells, with an independently certified minimum of 12–16 clockwise taps across sampled openings. Planet 2 uses 4×4, and later planets use 5×5. Later difficulty comes from route interactions rather than continually shrinking touch targets.

| First planet | New rule |
| --- | --- |
| 1 | Rotate a route through three stars from START to FINISH |
| 2 | Locked paths that cannot rotate |
| 3 | Directional paths |
| 4 | Linked twins: turning either turns both |
| 5 | Bridges with independent opposite-side lanes |
| 6 | Crossways with independent adjacent-side bends |
| 7 | Paired wormholes connecting distant tiles |
| 8 | Black-hole pull |
| 9 | White-hole push |
| 10 | Linked triplets |
| 11 | Gravity-controlled forks |
| 12 | Weapons and disarm circuits |
| 13 | Shields and a second weapon circuit |
| 14 | Directional/gravity-influenced bridge and crossway lanes |
| 15 onward | Mixed expeditions using the learned rules |

Generation continues beyond 500 planets with deterministic seeds, procedural names, palette variants and five planet visual families. These are not 500 individually authored worlds. Legal inverse scrambles preserve solvability, including linked tiles. The rules communicate hazards before launch; there is no hidden random loss applied after a correct solution. Retry preserves the player's route edits, and undo/hints understand linked rotations.

Daily signals contain three shared routes; Weekly expedition contains five. Their fixed progression levels are 31/91/151 and 61/91/121/151/181 respectively, with equal balanced difficulty and UTC periods. Versioned replays allow fair score calculation. Existing star rewards, achievements, cosmetic trail unlocks, daily/weekly medals and saved progress remain in place. Skipping a Voyage route grants no stars, achievements or league score.

## Understanding the board

The cyan rocket and START marker identify the real entrance port; the gold FINISH marker identifies the exit. Tiles do not start with a keyboard-style focus highlight. Underlined mode controls retain their active underline without a filled selection box; keyboard/accessibility support remains.

First launch shows a compact Mission Control / Sol and Pilot / Nova conversation explaining taps, three stars and the finish. New rules receive short, remembered briefings, including unfamiliar rules encountered through Daily or Weekly modes. Reading a briefing pauses the clock. Rules remain available in the mission reference; the player is not expected to guess unfamiliar symbols.

Crossing a planet boundary now combines a **seven-second pilot-view approach with the mission dialogue**. The exact map destination uses the restored illustrated planet renderer and a matching drawn cockpit rim, with perspective stars and eased approach. One character message is visible at a time; Previous/Next preserve every rule, and the final action starts play. The flight can arrive while the player reads, but never dismisses dialogue. Reduced motion arrives immediately, backgrounding pauses travel, and Arrive now shortens only the animation. See [PLANET_FLIGHT.md](PLANET_FLIGHT.md). This replaces the earlier generic six-second movie and rejected realistic planet atlas; it uses native painted geometry, not a live high-poly 3D engine.

## Local preview services

Build the local preview from the repository root with:

```sh
flutter build web --release --no-web-resources-cdn --dart-define=MOCK_SERVICES=true
flutter build ios --release --dart-define=MOCK_SERVICES=true
```

No leaderboard endpoint or subscription is required. Four clearly marked fictional pilots make the local league reviewable. The current player's result is calculated by replaying actual completed challenge actions. Joining, scoring, refresh and deletion work locally. Demo rewards add hints/skips without showing an ad; the demo ad-free unlock charges nothing. Mock balances, entitlement and league data are persisted separately from live data.

Without the mock flag, live ads/purchases remain disabled by default and the league remains unavailable until configured. The prepared backend shares the puzzle validator and supports anonymous opt-in rankings/deletion, but has not been deployed. AdMob still has test IDs; App Store product setup and live account work remain pending. See [backend/README.md](../../backend/README.md) for local API commands, activation steps and validation/security limits.

Live support code saves earned balances atomically, does not replenish its three initial hints/one initial skip on restart, and grants ad rewards only from the SDK's earned callback. iOS ad-free access uses verified current StoreKit entitlements, including revocation checks on foreground/restore; a callback status alone grants no entitlement. The removed-ads benefit includes hints and Voyage skips. Neither purchasing nor rewarded ads are active in the preview.

## Compatibility and validation scope

Old `intro-v1`, `generated-v2` and `voyage-v3` saved rounds remain restorable; new rounds use `planet-v4`. The progression tests sample three routes across each of 525 planets and exercise late progression. Focused service tests check persistence, revocation, session races, mock/live separation and absence of HTTP/SDK work in mock mode. The fourteen current flight widget tests cover independent arrival/dialogue, reduced motion, lifecycle handling, complete rule text and 48-pixel controls across five phone/tablet sizes at 1× and 3× text. Eight backend tests pass, including actual Dart replay validation rather than a permissive stub.

The final integrated Flutter suite for this version passed 429 tests with clean analysis; iOS/web release builds succeeded. Physical-device feel, late-game difficulty and native cinematic playback remain separate review work. These checks do not establish live payments, global rankings or exhaustive human playtesting.

A fresh-browser agent review solved the first three routes in 15/13/12 moves without hints or solver/state inspection, all first try. This confirms usability and legal completion, not a guaranteed retry rate. Phone 375×667 and tablet 1024×1366 layouts fit; the Weekly briefing kept its full 30-second launch window. The minimum-tap guarantee raises the floor, but real families should decide whether the early challenge is engaging.
