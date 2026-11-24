# Rapid-fire challenges and Voyage navigation — 0.9.1+20

23 November 2026.

## Shared layout

Voyage, Daily Sprint and Weekly Gauntlet use one compact destination header and identical timer, board, action and navigation geometry. The challenge relay rail uses the existing instruction slot. During play, points, cleared signals and streak replace Voyage's move/reward summary. The reset clock belongs to the final result, freeing the live board from the previous extra footer.

Phone, tablet portrait and landscape retain the same responsive layouts. No content scroll is introduced. Mode switches preserve active edits and elapsed time.

## Corrected Map behavior in 0.9.1

Map returns to the existing Voyage planet landing, in place. The Voyage tab and challenge result's Return to Voyage action use exactly the same destination. No extra planet page or route is pushed. The established planet scene, collection progress, route label, Play action and bottom navigation remain together.

An unfinished route displays its current destination without a false success receipt. Its clock pauses while the planets are shown. Play restores the exact board, moves, undo history and remaining time; a completed route retains the existing onward journey. Daily and Weekly park their own state when Map switches to Voyage and resume when their tabs are reopened. Pending automatic challenge advances cannot run while Voyage is shown.

Routes occupies the existing collection row and opens a records-only flight log. First/Previous/Next/Current controls reach earlier planets' records; replaying keeps the unfinished frontier, and Current route restores it. This retains historical replay without another planet universe. The standalone atlas introduced in 0.9.0 was rejected during user review and is no longer part of the shipped navigation.

## Challenge cadence

| Mode | Signals | Launch windows |
| --- | --- | --- |
| Daily Sprint | 3 | 22, 20, 18 seconds |
| Weekly Gauntlet | 5 | 24, 22, 20, 18, 16 seconds |

The existing deterministic advanced challenge boards remain on `planet-v5`. Their seeds, tile mechanics and verified move-score protocol are unchanged; there is no leaderboard migration. Daily uses progression levels 31/91/151 and Weekly uses 61/91/121/151/181. This update changes pacing and presentation, not the underlying solver rules. Player testing is still needed to tune difficulty.

On success, the courier runs for 900 ms and the next signal starts after a 320 ms handoff. There is no intervening Play action or planet flight. The handoff cancels while the app is inactive or a panel is open and re-arms when play resumes. Saved partial clears resume the correct next signal.

Timeout uses a blocking 350 ms signal-break overlay with one Retry signal action. Retry resets the current board and launch window, increments retries and breaks the clean streak; previous clears and their rewards are preserved. Voyage keeps its existing rocket-loss story, edit-preserving retry and cumulative elapsed effort.

## Results and persistence

Only each period's first stage clear is recorded. The result includes local points, clear time, best clean streak, stars/coins, the period medal and a live graphical UTC refresh clock. Clear time is the sum of successful attempts; it excludes failed-attempt effort. The clean streak requires measured unassisted clears without undo, restart or timeout. It is feedback, not an additional score/coin multiplier.

Old saves with unknown timing or score display missing/partial results honestly. An existing attempt budget is retained until the next stage or restart. UTC rollover preserves an active stage; advancing refreshes the period. A completed old period shows its result with a Start new challenge action when the next set is available.

Services remain local/mock. No real ads, purchases, Game Center submissions or cloud deployments are activated.

## Verification

- The 0.9.1 correction passes **651 tests** with clean analysis. New tests cover in-place Map/Play resume, Daily/Weekly parking, pending handoff restoration and historical replay. Final phone capture confirms the established Play/collection/navigation dock is present; large-text completion remains within bounds.
- Release web and signed iOS builds succeeded for 0.9.1+20. The final browser retained the saved Viridian route and 102 stars.
- The preceding 0.9.0 update passed 645 tests with clean analysis.
- Actual widget play solves all three Daily and five Weekly stages, checks automatic handoffs and the final recorded summary, and verifies retry/mode/map behavior.
- Exact header, timer, board and action rectangles match across modes at 393×852, 1024×1366 and 1366×1024. The broader viewport suite checks smaller phones, landscape, safe areas and large text without scrolling or clipping.
- Atlas accessibility verifies separate Continue/Resume controls. Challenge timeout blocks covered taps and drags.
- Live browser review confirms phone and portrait-tablet Weekly play, full-screen atlas in both tablet orientations, and a landscape Daily result. The isolated preview uses a frozen solving clock, so this is interaction/layout verification rather than a timed player study.

*Local review capture: Weekly on phone (`0.9-weekly-phone-live.png`).*

*Local review capture: Corrected Map destination: existing Voyage landing (`0.9.1-voyage-return-live.png`).*

The earlier 0.9.0 atlas screenshots document the rejected navigation, not the current Map behavior.

*Local review capture: Challenge result on tablet (`0.9-result-tablet-live.png`).*
