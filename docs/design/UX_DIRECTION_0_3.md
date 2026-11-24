# Glowpath 0.3 — a voyage with a readable purpose

Research and implementation review, 22 November 2026. This is a playable design hypothesis, not measured evidence of higher retention. The user identified weak control hierarchy and unclear start/end markers, then proposed a galaxy/planet journey. Those observations set the scope.

## What we investigated

[Competitor research](COMPETITOR_RESEARCH_0_3.md) documents Flow Free, Two Dots and Threes through eight sources. [Research evidence](RESEARCH_EVIDENCE_0_3.md) examines seven primary studies, including methods, sample sizes, limitations and testable implications. We use historical successes as design references; this is not a verified current revenue/chart ranking. We did not install or buy competitors, infer private analytics, or attribute their growth to a visual change without evidence.

Additional primary accounts inspected:

- **Mini Metro**, [developer postmortem](https://www.gamedeveloper.com/audio/postmortem-dinosaur-polo-club-s-i-mini-metro-i-), 2016. It began in a 2013 game jam, remained playable on the web during development, and moved through alpha and Early Access. The developers describe replacing their improvised interface with Jamie Churchman's comprehensive visual redesign, retaining Helvetica but rebuilding the interface, tutorial, menu and marketing assets as a coherent system. They also describe the difficulty of retrospective causal explanations and the cost of scope growth. **Our inference:** improve the entire interaction sequence and test a small playable slice; a prettier board alone is insufficient.
- **Monument Valley**, [Apple's developer interview about its origins](https://apps.apple.com/my/story/id1453819075). The team explored satisfying touch interactions and artwork before arriving at its architectural identity. **Our inference:** the visual premise should express what a player does; here, light visibly travels from a beacon through stars to a portal.
- **Monument Valley's evolution**, [Google Play interview with lead artist Lili Ibrahim](https://play.google.com/store/apps/editorial?hl=en&id=mc_games_editorialevergreen_indiedev_interviewseries_ustwogames_fcp). Designers and artists pass levels between disciplines; the interview describes balanced palettes and environmental water as contributors to atmosphere. **Our inference:** create a distinct world around the puzzle while protecting the readable interactive layer. This does not show that adding animated planets causes longer play.
- **Touch interaction**, [Apple's Ingredients of Great Games](https://developer.apple.com/videos/play/wwdc2014/602/), 2014. The talk connects direct touchscreen interactions with immediate feedback and argues for redesigning controls around touch. **Our inference:** keep the board as the main interaction, then make Undo and optional Hint easy to reach. The exact placement still needs physical-device testing.

These sources are developer accounts or platform guidance, not randomized evaluations. The separate evidence register distinguishes experiments from these practice-based lessons.

## Decisions implemented

| Observed problem | Change | What success would look like |
| --- | --- | --- |
| Tiny arrow/ring do not explain the objective | Named Start and Portal markers, different shapes/colors, connecting rails to the actual edge tiles, three-star status and a short objective | A new player points to both endpoints and explains the three-star condition before tapping |
| Decorative star rewards lack a reason to exist | Five destinations, five routes per destination; planetary arrival and a wormhole after 25 Voyage routes | A player can identify the next destination and remaining routes without opening help |
| Three equal buttons elevate Restart and make the dock busy | Two primary tools: reversible Undo and optional Hint; Restart moves to settings and has a keep-playing escape | Fewer accidental resets; frequent actions remain reachable |
| Hint changes the board immediately | First request outlines a relay without changing rotations or moves; a second explicit action turns it | Players understand the clue and retain agency; assistance stays recorded |
| First random board asks too much before teaching | Three authored opening routes, requiring 1, 3 and 5 turns | Players solve the opening without a verbal tutorial and transfer the skill to generated routes |
| Success is only a text swap | A short light courier follows the actual solved route and arrives at the portal; the solved board stays visible alongside outcome and next destination | Players notice completion and progress without feeling delayed; Next remains available |
| Switching modes loses the unfinished route | Separate local round slots preserve both Voyage and Daily boards/history | Switch away/back or restart the app without redoing work |
| Background fantasy could compete with the task | Original vector planets, restrained stars and orbit lines behind opaque puzzle tiles; a finite entrance drift | Players distinguish decoration from controls; no ongoing motion while considering a puzzle |

System/in-game reduced motion removes the movement; contrast preferences, descriptive tile semantics and large text remain supported. No paid artwork, image generation, subscriptions, backend or tracking SDK is added. This pass uses the existing licensed Atkinson font and original geometry. More planets do not mean more puzzle mechanics: the five visual destination types repeat in later named galaxies, with generated routes.

## What this does not establish

The studies do not justify claiming that a space theme, a hint system, richer animation or a larger session count improves long-term retention. We have no live cohort or revenue evidence. The prototype contains no ads, analytics, timers, energy gates, lost-streak penalties or forced daily prompts. The aim is understandable, satisfying play and a voluntary reason to return.

Next: use the first-play and return-session protocol in the evidence register. Observe objective recognition, first meaningful turn, unaided completion, hint comprehension, accidental actions, willingness to replay, and next-day voluntary return. Record denominators and qualitative confusion. Family/friend testing can identify repeated usability problems; it cannot validate revenue forecasts or population retention. Compare a static scene against the same scene with motion separately from changes to puzzle difficulty.
