# Voyage rewards — 0.8

Implemented locally in `GameController`, `voyage_records.dart`, `cargo.dart` and the Voyage, collection and flight-supplies screens. Coins are earned game currency; this release adds no cash purchase, account, cloud economy or ad configuration.

## Route records and replay

- Each Voyage route stores its highest score and shortest measured active solving time separately. Each record also retains its assistance flag, board layout and difficulty. Replaying uses that recorded board and difficulty.
- Any route before the unlocked frontier can be replayed. An unfinished frontier board, its edits and its elapsed time are parked and restored afterward. Replaying never moves the frontier backward.
- Opening history from a completed arrival does not park that receipt. Returning starts the unlocked frontier directly, without replaying the previous cargo animation.
- Old saves know which routes were unlocked, but cannot distinguish every historical skip from a clear. Earlier unlocked routes remain replayable; no first-clear bonus is invented for them. Their first new measured replay establishes a record.

## Score and active time

`score = move-efficiency score + round(800 × max(0, 1 − elapsed / original budget))`

The existing move-efficiency component remains in the range 0–200; the local total is capped at 1,000. A 10-second solve in an original 30-second window receives a 533-point time bonus, plus its move score.

- Time includes only active play. Briefings, help, collection, supplies and background time pause the clock.
- Timeout retry preserves both board edits and all elapsed effort. It grants another launch window, not a fresh scoring clock. Once original-budget time has been spent, the time bonus is zero.
- A time cell adds eight seconds to the deadline without increasing the scoring budget. The visible gauge describes the current retry window; it includes the extra eight seconds only in the window in which the cell was used.
- A full restart resets the board and attempt timing together. Consumed supplies are not refunded.
- Assistance is recorded when help is requested or a hint/power is used. Score and time records show their own assistance flags; an equal unassisted result replaces an assisted tie.
- An edited old save without timing history cannot produce a fabricated time record or time bonus. A full restart or a new route begins a measurable attempt.

The existing daily/weekly competitive score and replay-validation protocol are unchanged. The new time-based result is a local record, not a newly authenticated leaderboard score.

## Earned coins and supplies

| Event | Coins |
| --- | ---: |
| First eligible route clear | 20 |
| New score tier, one tier per 100 points | 1 per tier |
| Common cargo collected | 10 |
| Rare cargo collected | 25 |

A replay grants only score tiers not previously paid for that route. For example, improving from 640 to 820 grants two coins. It does not repeat the 20-coin clear bonus or three clear stars. Daily and weekly first-clear rewards use their existing period-specific claim ledger; repeated completion of the same claimed route pays nothing further.

| Supply | Cost | Effect |
| --- | ---: | --- |
| Hint | 10 | Store one credit; using it aligns the next suggested relay. |
| Skip | 75 | Advance the current Voyage frontier without score, stars or cargo. Unavailable during replays or challenges. |
| Time cell | 25 | Store a charge; use it before timeout to add eight seconds. One per attempt. |
| Route lens | 25 | Store a charge; align up to three legal relays, recomputing after each turn. |

Buying hints or powers stores inventory; use is explicit. Paid hint use, route-lens use and skipping each save the consumed resource together with its game effect. A route lens is one undo group; undo does not return its charge or erase assistance.

## Optional cargo

Cargo begins at route 31 and appears every five routes: 31, 36, 41 and onward. Each cargo board has a certified winning route through the collectible and a certified route that bypasses it. The existing three signal stars and portal remain the win condition. Cargo never becomes a required fourth star.

Ordinary encounters cycle through Moon pearl, Comet shard, Chrono cell and Route lens. Every third salvage route can instead contain a rare rendezvous item:

| Rare item | Device-local arrival window |
| --- | --- |
| Dawn prism | 06:00–10:00 |
| Night opal | 18:00–22:00 |

An encounter is pinned when the route attempt is created. Crossing a window boundary, backgrounding or relaunching does not remove an already visible item. Ordinary cargo is claimable once per route and kind. Rare cargo is claimable once per route, kind and local calendar date; a later occurrence can be discovered on replay.

Only a solved winning path that actually crosses the cargo cell claims it. Completion records the grant once, before notifying the interface. The courier pickup animation and saved completion receipt only display that grant; they do not award it again.

Collection counts are lifetime discoveries, separate from usable inventory. A Chrono cell discovery also grants one time-cell charge; a Route lens discovery grants one lens charge. Spending either charge does not remove its collection entry. Cargo adds achievements for the first discovery, five discoveries and the first rare discovery. Existing star-based trails and other achievements continue unchanged.

## Persistence and limits

Timing is sampled before gameplay actions and persisted periodically while playing. Pauses flush precise fractional timing; screen disposal also queues the final sample. Coin claims, inventory, cargo, records, the completion receipt and parked replay state share the local snapshot. Reloading a completed round cannot award its rewards again.

These safeguards prevent ordinary replay/reload farming, not deliberate save or device-clock tampering. Rare windows use the device clock and have no trusted server verification. Saves have no cross-device sync, account recovery or cloud backup added by this feature; removing local app data can remove this progression. The restore parser accepts up to 100,000 route records and bounds the coin balance at 1,000,000,000. This implementation should not be described as an unbounded, competitive or server-authoritative economy.

Focused coverage lives in `test/progression_economy_test.dart` and `test/economy_integration_test.dart`: migration, parked frontier, fixed replay board, score-tier payouts, cargo miss/claim/reload, local windows, affordability, power effects, active clock pauses, retry windows and final timing persistence. Optional-route generation and its two legal paths are verified separately in `test/bounty_generation_test.dart`.
