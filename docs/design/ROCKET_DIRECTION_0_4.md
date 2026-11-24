# Glowpath 0.4 — rocket missions, fair failure and galaxy travel

Reviewed 22 November 2026. The user proposes a launch countdown, route failures, a deeper galaxy map and new obstacles. This document records the research-led proposal and the resulting 0.4 implementation. It extends the seven studies in [the 0.3 evidence register](RESEARCH_EVIDENCE_0_3.md) with three primary sources whose methods, findings and limitations were inspected. The implementation table below is the current behavior record; later proposal sections retain alternatives for evaluation. Neither implementation nor passing tests establishes improved retention.

The core promise is: **plan a route, commit to a launch, watch the rocket follow the rules, then understand the result.** Challenge should come from choosing and executing a solution. A correct safe solution must succeed; the game must not secretly add a failure to manufacture another attempt. Surprise can come from discovering a new combination, seeing a revealed hazard unfold, or choosing a visibly risky shortcut.

## Implemented 0.4 versus the proposal

| Area | Implemented behavior | Difference or remaining hypothesis |
| --- | --- | --- |
| Opening and timer | Only mission 1 is untimed by default. Later missions show their launch window; Begin Mission starts it, early launch is available, and zero launches the built route. Untimed planning is available in settings. | The earlier proposal made the first three missions untimed. The current learning pace still needs fresh-player testing. |
| Hold and interruptions | Hold pauses until Resume. Settings/inspection, the map and app backgrounding suspend elapsed countdown consumption; returning to active play resumes automatically unless Hold remains active. | The proposal preferred an explicit Resume after every interruption. Automatic resumption is the current choice. |
| Process restart | Saved edits, moves, assistance, undo history and attempt state are restored. An unfinished plan returns to briefing with a fresh window on Begin. A resolved launch restores its debrief. | Remaining countdown time and the previous screen phase are not persisted; the proposal's exact elapsed-time restoration is not implemented. |
| Failure and Retry | The debrief identifies the actual route failure. Revise & Retry keeps edits, increments the attempt identifier and starts a new window with a fresh asteroid forecast; help discloses this. Each attempt's result is stable. | This differs from the proposed unchanged-forecast replay. There is no separate same-attempt replay control. |
| Safe routes and risk | Authored reference solutions avoid asteroid risk. Optional marked shortcuts disclose their collision chance. Repeating one attempt is deterministic; a correct safe solution is not randomly punished. | Comprehension of risk and the distinction between attempts remain player-test questions. |
| Fixed cells | Fixed relays and blocks reject rotation. Their enabled button action opens an explanation without spending a turn. | The earlier non-button proposal assumed no action; an inspector is a valid accessible button action. |
| Gravity and other mechanics | The 15-mission campaign includes fixed relays, blocks, one-way gates, paired wormholes, fixed clockwise/counterclockwise fork priorities, slingshots, asteroid shortcuts and edge wraps. | Gravity does not simulate attraction of neighboring cells or continuous orbital physics. |
| Daily mission | One Daily mission is selected from the same 15-mission catalog by UTC date. An unfinished Daily keeps its date/board; after completion, leaving and returning after rollover can select the next date. Campaign and Daily plans remain separate. | This is one catalog mission per day, not the old Daily trio or a newly generated daily world. |
| Progress | Successful launches unlock campaign coordinates and award progress once. Planning a connected route does not award it; completed missions can be replayed through the map. Daily success does not unlock campaign levels. | No measured retention or progression preference is established. |
| Cockpit and map | The cockpit constructs route-derived 3D geometry and projects it onto Flutter Canvas; the galaxy view uses illustrated depth and selectable mission nodes. | This is procedural perspective rendering, not a full 3D physics simulation or free-roaming galaxy. |
| Motion and access | Phone tilt/pointer input changes only decorative sky layers. Motion stops when disabled, backgrounded or reduced by either OS flag. Reduced-motion flight uses a static alternative; the ignition clock retains its real duration and can be skipped. | Actual sensor feel, battery use, VoiceOver/TalkBack and frame pacing still need device checks. |
| Legacy saves | New mission data uses a separate save key; the old game/controller and legacy save behavior remain covered by regression tests. | Old Voyage stars/routes are not converted into new campaign unlocks. |

Current automated evidence: **135 tests passed**, comprising 75 legacy and 60 new tests. After small copy changes, the 13 mission UI and five turn tests passed again. Final analysis/release builds and wider manual checks are tracked separately in [0.4 verification](VERIFICATION_0_4.md); they are not implied by these test results.

## Additional evidence

### R1 — failure and responsibility

Jesper Juul, **Fear of Failing? The Many Meanings of Difficulty in Video Games**, 2009. [Author full text](https://www.jesperjuul.net/text/fearoffailing/), especially the online test, attribution analysis and appendices.

**Method/result.** A nine-person pilot preceded an online study of 85 players using a four-level snake/action prototype. Seventy-three participants were men; recruitment used the author's blog, and only completed questionnaires were included. Players who attributed failure to their own mistake rated the game more positively than those saying it was too hard (reported p < .016). The comparison suggesting that some failure followed by success received the highest ratings was p = .06, not conventionally significant.

**Limits.** Performance and attribution were not randomly assigned; the associations do not establish that adding failures increases enjoyment. A short action game and self-selected audience cannot establish mobile retention, an optimal failure rate, or benefits from concealed hazards.

### R2 — timing can change experience, but this is not a timer recommendation

Denisova and Cairns, **Adaptation in Digital Games: The Effect of Challenge Adjustment on Player Performance and Experience**, CHI PLAY 2015. [Author full text](https://www-users.york.ac.uk/paul.cairns/pubs/Denisova_CHIPLAY15.pdf), study design, results and discussion. [DOI](https://doi.org/10.1145/2793107.2793141).

**Method/result.** Forty-two adults, aged 19–33, played an isometric shooting game after untimed practice. Twenty received a normal 90-second timer; 22 received an undisclosed performance-dependent timer, producing approximately 72–108 real seconds. The adaptive group reported greater immersion; overall score differences were not significant. Faster players receiving shorter sessions were selected by the adaptation itself, so their higher scores are not evidence that pressure caused better performance.

**Limits.** One short session, one genre, and no untimed comparison. The authors explicitly leave repeated play and discovery of adaptation unresolved. This does not test an honest countdown against no countdown, validate a particular duration, or establish a retention benefit. Glowpath should not copy the deceptive clock manipulation.

### R3 — expectations distinguish a difficult obstacle from a meaningless setback

Ballou and Deterding, **“I Just Wanted to Get It Over and Done With”: A Grounded Theory of Psychological Need Frustration in Video Games**, CHI PLAY 2023. [Full text](https://selfdeterminationtheory.org/wp-content/uploads/2024/01/2023_BallouDeterding_IJustWanted.pdf), §§2, 3.1–3.2 and 4.5.

**Method/result.** Twelve players described recalled experiences in semi-structured interviews. The authors developed a theory relating expectations, frustrating situations and later play choices. Competence frustration included stagnation, unfair situations and actions without expected impact; autonomy frustration included constrained playstyles and feeling compelled to continue. The model allows momentary struggle within an otherwise wanted experience.

**Limits.** This is qualitative theory generation, not a causal experiment or a retention-effect estimate. Recall, interpretation and a relatively homogeneous sample limit transfer: participants were 18–42, mostly from the Global North, and named console/PC favorites. It supports useful questions for testing our design, not a universal rule that all frustration is harmful.

## What carries forward from 0.3

The previous register remains the source for tutorial, hint, feedback, touch and scenery decisions. E1 motivates testing a short playable introduction instead of assuming that more instruction helps. E2 motivates evaluating optional hints by comprehension and the next independent action. E3 supports testing competence and autonomy alongside enjoyment. E4–E5 inform distinct, synchronized action feedback. E6 motivates generous controls. E7 concerned static scenery and supplies no evidence for moving planets or true 3D navigation. None establishes a revenue or long-term retention uplift for this direction.

The following specifications and hypotheses are our product inferences. Their exact timings, state rules, obstacle order and layouts were not prescribed or evaluated by the papers.

## Proposed mission loop

This section records the original design options. Where it differs from the implementation table, the table describes the shipped candidate and this section remains a hypothesis.

1. **Briefing/planning.** Show a rocket at START, the destination, required collectibles and all operative hazard rules. Let the player inspect the route and choose Timed launch or Untimed practice. The clock starts only after an explicit action, once the board and controls are usable.
2. **Armed countdown.** If enabled, display real remaining time. Define before starting whether tiles may still rotate; the proposed first prototype permits edits until launch. Provide **Launch now** and **Pause**. Do not shorten, accelerate or extend a running timer based on performance or advertising goals. A different pace is a visible choice for the next attempt.
3. **Flight.** At launch or deadline, freeze one route snapshot and simulate it. The rocket follows that snapshot; no input may silently alter a flight already in progress. A deadline with an incomplete route produces its actual route failure, rather than a generic score penalty. An optional brief cinematic countdown belongs here and must be skippable; it is separate from the puzzle's decision timer.
4. **Debrief.** Success identifies the destination reached and earned progress. Failure identifies the first decisive event: for example, “No connection at row 3, column 2” or “Entered the one-way relay against its arrow.” Keep the relevant route and marker visible. Text and semantics must explain the event without relying on an explosion, sound or red color.
5. **Choose again.** Offer **Edit route**, **Retry same mission**, and **Back to galaxy**. Editing restores the attempted configuration; restarting returns to its initial configuration. No forced delay, lost earned worlds, energy payment or compulsory ad to try again. Keep optional help available after failure and during planning.

A live in-flight repair game would be a separate design: it changes input timing, route simulation and accessibility substantially. Do not accidentally mix that rule with a frozen-route puzzle. Likewise, an auto-launch timer and a decorative 3–2–1 sequence must have different labels and state.

## Proposed countdown and interruption contract

| Situation | Proposed rule | Reason to verify |
| --- | --- | --- |
| First three teaching missions | Untimed by default; demonstrate launch, one understandable failure and correction without removing progress | Learn the rule before speed becomes a second task |
| Timed choice | Show duration and consequence before arming; count real active-play time | A displayed second must mean a second |
| Pause, Help, Settings or galaxy sheet | Pause the mission clock and any hazard phase; resume through an explicit Resume action | Reading help must not cause an unseen loss |
| App inactive, backgrounded, screen locked or interrupted | Pause and persist active elapsed time; return paused | Phone interruptions must not consume the attempt |
| Reload/process death | Restore a coherent paused mission or a completed debrief, with the same route/hazard seed | No duplicate rewards, rerolled hazard or invisible expiry |
| Near-zero input | Define one ordering rule for a final accepted turn and launch; test it at the exact boundary | A valid tap must not be visually accepted but omitted from flight |
| Timer implementation | Inject a monotonic elapsed-time source; callbacks redraw rather than subtracting assumed ticks | Slow frames and delayed callbacks must not extend or accelerate time |
| Screen reader | Expose remaining time on demand; announce a small set of useful milestones, then one outcome | Announcing every tick would compete with tile descriptions |
| Reduced motion | Remove camera travel, shaking and decorative flight motion; keep equivalent route/outcome information | Motion preference must not change the logical result or silently shorten decision time |
| Alternative pace | Keep untimed practice available and clearly separate timed scoring if required | A speed challenge should not make the whole game inaccessible |

No reviewed study supplies the correct countdown length. Start with generous, visible settings and tune after observing fresh players. Track timeout-related misunderstanding separately from a deliberate failed attempt. Practice should still allow galaxy progress in the prototype; any timed badge is an additional mastery goal rather than the only route through the game.

## Proposed obstacles and deliberate risk

Introduce one rule at a time with a small authored mission, then combine known rules. Every mission needs a validated safe solution under its displayed rules. Each rule must be present in the solver, flight simulation, visual legend and accessible description; a decorative obstacle must not imply a rule the engine does not implement.

| Mechanic | Readable rule and feedback | Prototype boundary |
| --- | --- | --- |
| Locked relay | Lock shape plus “Fixed relay”; its connections are readable but it cannot rotate | A tap must not increase moves or animate a turn. Expose it as readable state, not an enabled button |
| One-way relay | Arrow identifies permitted entry/exit; failure highlights the prohibited entry | Do not rely on rotating a symmetric pipe alone to communicate direction |
| Paired wormholes | Shared letter/shape labels identify the pair; explain exit direction before launch | A deterministic transition; track entry state and prevent infinite portal cycles |
| Gravity fork | Show the priority/selected branch with an arrow and a short rule | Use a fixed rule or an explicit player selector. No hidden coin flip when two branches are possible |
| Slingshot | A preview shows the fixed direction change or skipped span | Keep the puzzle discrete. Continuous physics and precision launch gestures are outside the first slice |
| Asteroid route | Display its path, dangerous cells and rule before arming. Keep a safe alternative when presenting an optional shortcut | Begin with a deterministic visible pattern. Label an unknown scan as unknown rather than pretending it is safe |

For any future probabilistic shortcut, disclose what is uncertain and its consequence before commitment. Generate and persist the hazard schedule once per attempt, using a versioned seed, and replay that same schedule on retry. If the UI advertises a numeric probability, the generator and observed outcomes must support it. Resampling on every Retry would hide what was learned; silently changing odds after success or failure would break the contract. The prototype can avoid this complexity by making risk a visible timing/path choice instead of randomness.

Surprise remains available: the first wormhole reveals a new part of the map; a known gravity rule creates an unexpected but explainable shortcut; a forecast asteroid crosses exactly as shown. After an outcome, the player should be able to say what happened and identify a different decision. If no decision could change the outcome, that event should be presentation, not a failed mission or lost reward.

## Galaxy presentation and learning arc

Use a small authored sequence to establish the new loop: launch and arrival; fix a visible gap; observe a fixed relay; follow a one-way arrow; traverse a paired wormhole; combine two learned rules. Introduce gravity forks, slingshots and asteroid patterns only after their single-rule examples work. These are proposed teaching beats, not a requirement to build six mechanics at once or pad progression with repeated filler.

The map can use depth cues, shaded planets, a route line and an earned wormhole transition. Describe it accurately as an illustrated or 2.5D map unless genuine 3D navigation is implemented. Decorative scale must not shrink a selectable destination below the existing 48-logical-pixel target. Give each node a name, mission state and explicit action; provide a straightforward list/linear navigation alternative to any pan, pinch, depth or drag interaction. Current, completed and locked states need text or shape as well as color. Explain the next unlock with a fixed rule.

Keep the board quiet and stable while decisions are made. Camera travel belongs between missions and must be skippable and suppressed by either OS motion flag or the in-game setting. Flight and arrival may look rich while retaining a static route trace and concise outcome. A slower phone must render fewer effects rather than run different hazard rules. True 3D rendering, extra engines, paid assets and procedural physics require separate scope and device-performance evidence; they are not prerequisites for this prototype.

## Scope and implementation review gates

### Implementation direction reviewed during the 0.4 build

The current implementation uses purposeful spacecraft instruments and custom flight controls, with a route board and a galaxy view serving distinct tasks. It does not use stock navigation tabs as its visual structure. `CockpitFlight` constructs three-dimensional route geometry from actual `FlightResult` steps and projects it through a perspective camera onto Flutter Canvas. This is a procedural perspective flight, not a prerecorded clip; the rocket's bends, collected stars and final outcome are derived from the resolved route. That technical description does not establish physical-device frame rate, comfort or retention. The galaxy navigation remains a separate illustrated depth presentation.

The implementation has expanded to 15 authored missions spanning the proposed mechanics. This is broader than the small first slice originally recommended, so each new rule still needs its own comprehension and transfer checks. Current `retry()` keeps route edits but increments the attempt identifier, allowing a new asteroid outcome; a repeat of the same attempt is deterministic. The flight manual now discloses that Retry refreshes the forecast. Safe-route success is independent of either attempt choice.

**Original first-slice recommendation:** offline authored missions; explicit planning/countdown/flight/debrief states; a reliable launch and failure trace; same-mission retry; fixed relays and one-way rules; a small galaxy progression view; existing accessibility and save guarantees. The proposed next extension was a paired wormhole before further hazards. The implementation now includes the broader mechanic set above; this paragraph records the earlier scope recommendation rather than unfinished implementation work. No backend, tracking SDK, ad SDK, paid asset or cloud spend was required for this prototype.

The mission model should own the result; animation merely displays it. Prefer explicit states such as briefing, planning, countingDown, paused, flying, succeeded and failed, with an attempt identifier. Define legal transitions and ignore stale callbacks from previous attempts. Commit progress once for a mission/result identifier, then persist it independently of animation completion. Save schema version, mission identifier, route, assistance, hazard seed and pause state; reject or migrate invalid snapshots deliberately.

Review and test these cases before claiming the slice ready:

- A known safe route succeeds for the same seed on web and native; every failure reports its decisive rule and location. Loops terminate with an explanation rather than hanging.
- Rotate, Undo, launch, timeout and Retry races cannot start two flights or award twice. Rapid taps during a disabled phase cannot alter the committed route.
- Backgrounding, opening a sheet, resizing, process restoration and widget disposal cannot leave a live timer or invoke a stale callback. A paused deadline cannot become a failure behind a modal.
- Editing after failure preserves the attempted route; Retry preserves the mission and hazard schedule. A newly selected mission resets attempt state intentionally.
- Completion and failure controls stay reachable at the existing viewport/text-scale matrix; board geometry remains usable. Locked relays, hazard rules, countdown, pause and result have meaningful semantics and keyboard actions.
- Reduced-motion and disable-animations flags each suppress visual motion independently. The same route has the same result in both modes; outcome navigation does not wait for an animation.
- A fresh mission and a restored mission show the same objective and unlocked galaxy state. Existing Voyage/Daily progress migrates without silently deleting earned work.

These are design review gates, including alternatives not implemented in 0.4 (such as same-forecast retry and persisted remaining time). The implementation table and verification record identify actual behavior and completed checks. Passing earlier 0.3 tests alone does not establish that new mission states satisfy them. Physical VoiceOver/TalkBack, interruption behavior, haptics and frame pacing still require device testing.

## Hypotheses and bounded evaluation

Use the existing 6–8-person first-play pilot for diagnosis, not statistical proof. Ask each player to explain the objective, launch behavior and one hazard before committing; after a failure, ask what caused it and what they would change. Include an interrupted attempt and a retry. Record the exact version, mission and seed, with participant permission and minimal identifying data.

| Hypothesis | Comparison or observation | Reject or revise if |
| --- | --- | --- |
| A route trace makes failure useful | Concrete cause/location feedback versus a generic failure message on matched missions | Players cannot identify a repair or repeat the same misunderstanding |
| A chosen countdown adds enjoyable tension | Timed and untimed variants, with order varied and both selectable afterward | Comprehension or control falls, accidental launches rise, or participants prefer stopping because of pressure |
| Disclosed hazards support deliberate risk | Ask players to predict a safe route and a shortcut outcome before launch | Players believe the game changed a rule or cannot distinguish uncertainty from a bug |
| Galaxy travel makes progress meaningful | Ask what was earned, where the next mission is and why it is unlocked | Decorative planets are mistaken for controls or unlock rules are unclear |
| Correctable failure supports voluntary replay | Observe whether the player chooses another attempt and whether the next decision improves | Retries rise only because the same information is withheld or progress is blocked |

Track cause-specific failures, successful corrections, accidental actions, assistance, perceived fairness/control and reasons for stopping. Retry count and session length are not standalone success measures. After comprehension is sound, a consenting 7–14-day pilot can examine voluntary return with denominators; it cannot validate the revenue target. No fixed failure quota, hidden difficulty increase, forced near miss or secret punishment of a correct route belongs in the design.
