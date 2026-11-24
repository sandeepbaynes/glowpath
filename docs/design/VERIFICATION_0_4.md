# Glowpath 0.4 verification

22 November 2026. This record covers the rocket-mission candidate and preserves the distinction between automated behavior, visual inspection and release readiness. Current design choices and differences from the original proposal are recorded in [Rocket direction](ROCKET_DIRECTION_0_4.md).

## Automated results

The final release source passed the full test suite: **135 tests — 75 legacy and 60 new**.

| New coverage | Tests | What was checked |
| --- | ---: | --- |
| Mission model and controller | 18 | Authored safe routes and obstacle rules; deterministic attempts; launch-only progression; retry/edit state; persistence, mode separation and Daily dates; invalid saves and write failure recovery |
| Mission UI | 13 | Explicit arming, elapsed countdown, Hold/settings/background pauses, zero auto-launch, actual failure trace, advancing cockpit, retry edits, map return/travel/replay, staged guidance, restored debrief, untimed play and both OS motion flags |
| Reactive sky | 9 | Neutral calibration, filtering/clamping, invalid readings, stationary child geometry, no child rebuild on sensor events, cancellation/resubscription, source replacement, graceful errors and pointer fallback |
| Launch presentation and galaxy map | 8 | Available/locked destination interaction, map semantics and keyboard controls, large text, reduced-motion launch presentation and caller-owned animation timing |
| Cockpit | 7 | Success/failure semantics, empty/dead-end traces, moving versus frozen pixels, wormhole/edge-wrap rendering and no self-running animation |
| Mission turns | 5 | Visible relay rotation with upright star badges, rapid-turn continuity/wrapping and immediate orientation under app/OS motion settings |
| **Total new** | **60** | |

After the final symbol, control and copy changes, the **13 mission UI + five mission-turn tests passed again**. This is a repeat of 18 tests in the total, not an additional 18 unique tests.

Mission UI viewport checks use the bundled Atkinson font and cover 320×568 at 1× and 3× text, 844×390 at 2×, and 1280×900 at 3×. They measure cells at least 48 logical pixels, exercise scrolling to controls/settings, and run visible touch-target and label guidelines. The 75 legacy tests retain the earlier layout/accessibility coverage; they do not substitute for checking new screens. These results are not comprehensive contrast certification or proof of usability with an actual screen reader.

Timing tests use an injected clock and verify elapsed time rather than nominal callback counts. Ignition tests check its final visual pose at exactly five seconds and the cockpit on the following frame, including OS motion settings. Production countdown code uses a monotonic Stopwatch; the controller preserves ignition duration while the visuals separately respect motion preferences. Sensor tests use injected streams, so they establish lifecycle logic, not physical accelerometer quality.

## Visual and browser evidence

Three fixed-progress presentation screenshots were rendered for inspection:

- Rocket launch (local review artifact: `rocket-launch-0.4.png`)
- Cockpit flight (local review artifact: `cockpit-flight-0.4.png`)
- Cockpit route loss (local review artifact: `cockpit-lost-0.4.png`)

Additional browser captures: mission control (local review artifact: `mission-control-0.4.jpg`), galaxy atlas (local review artifact: `galaxy-atlas-0.4.jpg`) and Daily instruments (local review artifact: `daily-instruments-0.4.jpg`).

The three rendered PNGs show specified animation states; they are not evidence of device frame pacing or a complete interactive flight. Manual web inspection completed the first mission, opened the galaxy map and selected mission 2. An intentionally broken mission-2 route launched, returned the correct failure explanation/sector, and retried with its edits retained and a fresh window. Hold and Atlas worked; Daily displayed its live UTC-reset orbit dial, and reopening Atlas selected the parked campaign coordinate rather than the Daily catalog number. Fixed-route locks remain visible beside star badges. Intermediate cockpit poses were inspected via the actual-widget renders above; this is not a browser video or a physical-device performance measurement.

## Release and remaining checks

| Check | Current status |
| --- | --- |
| Final source analysis | Passed, no issues |
| Final web release build | Passed with `--no-web-resources-cdn` |
| Final Android review build/package checks | Passed; identity, signature, permissions, ABIs, 16 KB ZIP alignment and checksum checked during this version's build review |
| Final unsigned iOS build | Passed; unsigned Runner.app produced, not installed or distributed |
| Manual browser loop | Success, failure, retry, hold, atlas travel and Daily clock exercised as described above |
| Physical phone testing | Pending: tilt calibration/orientation feel, interruption/resume, haptics, thermal/battery behavior and frame pacing |
| Assistive technology | Pending physical VoiceOver/TalkBack, large-text ergonomics and control discoverability |
| Player research | Pending fresh-player comprehension, fairness, risk understanding and voluntary-return pilot |

No measured retention, revenue, ad ROI or performance improvement follows from this verification. The prototype has no ads, analytics backend or cloud deployment. Publication, production signing and store preparation remain separate from the review build.
