# Progression and rewards — 0.5.0

The game now rewards each new clear with three banked stars and a visible result receipt. Stars unlock five rocket trails, including the starting Starlight trail. Earned achievements and daily/weekly completion medals persist on this device. Rewards are credited immediately; Play still starts the next route in one action.

## Learning curve

| Voyage routes | Board | New challenge | Steady launch window |
| --- | --- | --- | --- |
| 1–5 | 3 × 3 | One-turn opening, then more turns and longer routes | 60 → 44 seconds |
| 6–15 | 4 × 4 | Fixed relays from route 10 | 56 → 44 seconds |
| 16–19 | 5 × 5 | Larger route planning area | 55 seconds |
| 20 onward | 5 × 5 | One-way relays, longer routes and more fixed/directional constraints | Gradually reaches 35 seconds |

Gentle grants five extra seconds and Bright removes five, bounded to 30–60 seconds. A new board size gets a learning window before the clock tightens again. All generated routes have a known solution. Fixed relays cannot turn; directional relays must be entered from their marked inlet. The generator continues producing Voyage route numbers without a final authored level. Difficulty eventually plateaus; this is procedural variety, not a claim that every future board is unique or that challenge grows without limit.

Boards remain at most 5 × 5 so normal phone and tablet layouts can retain 48px tile targets. New generation is versioned as `voyage-v3`. Active `intro-v1` and version-2 generated saves retain their exact original board and clock rules until the player moves onward.

## Rewards

- Each distinct Voyage clear or daily/weekly route awards three stars. Hints do not remove stars.
- Trail thresholds: Starlight 0, Ember 15, Aurora 45, Ion 90, Solar 180.
- A newly unlocked trail is equipped automatically. The collection lets the player preview every trail and select any unlocked one. Stars are lifetime progress, not a spendable currency.
- Equipped colors appear on the countdown rocket exhaust, board completion courier and Voyage courier. Gameplay signal, star and portal colors retain their meanings.
- Nine achievements cover the first clear, 5/25/100 Voyage routes, a 200-point unassisted score, 1/7 daily trios and 1/4 weekly expeditions.
- Previously completed daily/weekly routes cannot award stars or medals again. Period histories are bounded; retired periods cannot be farmed after pruning.
- Legacy saves migrate only verifiable achievements. A legacy solved round does not invent a new reward receipt or credit another win.

## Return visits

Daily offers three date-seeded routes at progression tiers 8, 14 and 20. Weekly offers five week-seeded routes at tiers 12, 18, 24, 30 and 36. These use fixed Steady difficulty so changing Voyage pace cannot change a challenge. Complete a set to earn its medal; the result then offers one Play action back to Voyage.

Daily refreshes at midnight UTC and weekly on Monday at midnight UTC. Both use graphical countdown instruments. An unfinished active route retains its period, edits, moves and undo history across a rollover; a new set begins between rounds. Voyage, Daily and Weekly have independent parked states. There is no streak penalty, claim timer, notification subscription or paid currency.

## Layout and access

Gameplay and arrival use the available screen bounds and reserve space for the shared bottom console. Portrait tablets expand the board; broad tablets use a large board with a vertically centered mission panel. The collection is bounded, with paged medals and no scroll. Short landscape views use compact instruments and a two-column result.

Small-phone navigation keeps mode labels on one line and uses 48px utility widths; other screens use 56px. All navigation controls remain 64px high. The HUD uses bounded instrument typography; help and settings retain accessible scrolling for larger text and legal information. Reduced motion disables decorative movement and transitions. Outgoing collection sections stop receiving focus, input and screen-reader content during their dissolve.

## Review evidence

See [current release verification](../release/0.11.0.md) for the latest validation scope. Automated checks cover deterministic solvability, size/mechanic/timer progression, legacy saves, three-mode persistence, reward duplication prevention, long-term history bounds, actual equipped colors, daily/weekly rollover, and screen bounds across phones and tablets. Visual review checks the local browser build; physical-device timing, haptics, comfort and whether people want another session still require player testing.

All progress is local. No backend, analytics, advertising, subscription or new service spending was introduced. This creates a progression loop; retention and revenue remain unmeasured.

## Captured review views

- Phone arrival and navigation (local review artifact: `rewards-0.5.0-phone.jpg`)
- Rocket-trail collection (local review artifact: `rewards-0.5.0-collection.jpg`)
- Actual starter-route win and banked stars (local review artifact: `rewards-0.5.0-win-tablet.jpg`)
- Weekly expedition on a 1402 × 1205 tablet viewport (local review artifact: `rewards-0.5.0-weekly-tablet.jpg`)
