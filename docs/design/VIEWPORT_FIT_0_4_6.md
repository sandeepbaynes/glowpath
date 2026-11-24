# Viewport fit — 0.4.6

The player reported that Daily's reset details fell below the bottom navigation and that the tablet layout left most of the screen empty. The old scrollable HUD and fixed 470px/460px board limits caused both problems.

## Layout changes

Gameplay and arrival now use the height available above the safe-area navigation dock. Their scroll containers are removed. The phone header combines a 48px destination/map shortcut and a compact rocket countdown. A compact graphical Daily reset shows the complete time, orbit and progress track in 40px. Tools, turn/target statistics and reset information stay in the visible footer; the board takes the remaining space. During the on-board success payoff, Play occupies the same tool area, so the board does not jump.

Portrait tablets expand the board up to 920px; wide screens allocate the available height and width between the board and a vertically centered mission panel. A separate Start/stars/Portal legend in the side panel saves vertical room on landscape phones. The compact board uses 11px side rails, retaining all 25 non-overlapping 48px targets at a 276px board size. Original rail and arrival painters use the actual rail geometry.

Navigation stays in its shared bottom console, with no additional taps to enter play. Mode restoration, saved routes, countdown rules, ambient scenery, splash and readable failure behavior are unchanged.

## Typography and accessibility

The game HUD uses bounded instrument typography instead of letting large settings turn it into a scrolling document: maximum 1.1× on short layouts,1.5× on taller layouts; compact destination/navigation labels max 1.1×, mission captions max 1.2× and board/countdown instruments max 1.25×. Full spoken labels and statuses remain, and help/settings continue using the player's preferred text size. Informational sheets and legal text retain their accessible scrolling; the no-scroll change applies to the primary gameplay and arrival screens. All minimum tile hit areas remain 48px, and navigation controls retain their larger targets.

## Verification

Static analysis is clean and all 262 tests pass. Eleven new viewport cases check both Voyage and Daily before any scroll or ensureVisible call: 320×568,360×640,390×844,430×932,740×360,844×390,744×1133,820×1180,1180×820,1366×1024 and390×844 with top 47/bottom 34 safe insets. They verify every tile, board, map shortcut, timer, tool, statistic and reset instrument lies entirely above navigation; active scroll extents are zero. Arrival summary/Play also fit. Tablet board width must reach at least the smaller of 50% viewport width and 60% viewport height.

Existing accessibility, rapid-navigation, timeout, keyboard, save/restore, tablet and reduced-motion coverage passes. Compact instrument tests cover active/paused/expired/complete countdowns, midnight and fallback fonts. Physical-device comfort and frame pacing remain review work.
