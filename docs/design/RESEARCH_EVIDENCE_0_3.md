# Glowpath 0.3 — research evidence and design hypotheses

Reviewed 22 November 2026. Scope: seven primary papers on first play, hints, motivation, action feedback, touch controls, haptics and decorative game worlds. Abstracts, methods, results and limitations were inspected in the linked author/institutional full texts. This is a focused evidence review, not a systematic review or proof that Glowpath will retain players. No application code, analytics, accounts or SDK configuration was changed for this document.

The proposed direction is a readable space voyage: connect a launch point through three stars to a destination portal, then reveal the next part of a galaxy. Design feedback identified the existing start and end as unclear. Fix that comprehension problem before assessing additional decoration. A coherent space metaphor is our design proposal; none of the papers below experimentally validates Glowpath's particular fiction.

## Decisions to carry into 0.3

1. Make the start, objective and destination understandable on the board itself. Pair distinct shapes with short labels; keep meaning when color, animation, sound or vibration is unavailable.
2. Let first-time players perform a small, understandable action immediately. Keep help available without making a long explanation a prerequisite.
3. Offer help that first identifies the relevant problem, with an explicit further choice to demonstrate a turn. Do not silently play the puzzle for someone who expected an explanation.
4. Give a normal turn, a newly collected star, and arrival different levels of feedback. Success should be legible and attributable to the player's action.
5. Use the galaxy to support anticipation and visible progress. Treat decorative richness, decorative motion and gameplay feedback as separate design variables.
6. Define engagement as satisfying, voluntary play and return. Session length alone is not a success metric: it can also reflect confusion, interruption or difficulty stopping.

## Evidence register

### E1 — tutorials depend on the game

Andersen et al., **The Impact of Tutorials on Games of Varying Complexity**, CHI 2012. [Author full text](https://grail.cs.washington.edu/wp-content/uploads/2015/08/andersen2012tio.pdf), especially study design, results and limitations on PDF pages 4–10.

**Method/result.** Eight tutorial conditions were randomly assigned to new players in three games: Refraction (13,158), Foldit (9,743) and Hello Worlds (22,417), totaling 45,318. Tutorials improved some engagement measures in the complex Foldit, but not broadly in the two simpler games. Restricting interaction did not reliably improve engagement. Context and on-demand-help results differed between games.

**Limits.** Different genres, audiences and acquisition contexts; short field collection; behavior was a proxy for learning. This does not establish that every simple game needs no tutorial.

**Glowpath inference → hypothesis.** Compare a brief playable launch sequence with the current opening. Predict fewer mistaken first actions and better rule recall on an unseen board, without requiring more explanation screens. Preserve an accessible Help action. Do not import Foldit's percentage gains into our forecast.

### E2 — hints can fail even when they are adaptive

Wauck and Fu, **A Data-Driven, Multidimensional Approach to Hint Design in Video Games**, IUI 2017. [Full text](https://www.sift.net/sites/default/files/publications/wauck_iui2017hints.pdf), experiments and results on PDF pages 5–9. [DOI](https://doi.org/10.1145/3025171.3025224).

**Method/result.** A difficult Three Body Puzzle had 25 formative participants, 24 analyzed, followed by 90 participants, 77 analyzed, randomly assigned to adaptive, automatic or on-demand hints. No hint condition improved the measured experience or behavior overall; 54 of 66 players who saw hints rated them little or not helpful. Exploratory behavior correlated with some positive experience measures; this was not proof that causing exploration causes enjoyment.

**Limits.** One unusual puzzle, small groups, particular hint wording and three-second control lockouts for automatic/adaptive hints. The earlier no-hint group was not a concurrent randomized control.

**Glowpath inference → hypothesis.** Trial an optional, concrete two-step hint: identify the disconnected location, then let the player request a demonstration. Measure usefulness and the next independent move, not just faster completion. Do not infer frustration from hesitation alone.

### E3 — competence and autonomy are useful design goals

Ryan, Rigby and Przybylski, **The Motivational Pull of Video Games: A Self-Determination Theory Approach**, Motivation and Emotion, 2006. [Full text](https://selfdeterminationtheory.org/SDT/documents/2006_RyanRigbyPrzybylski_MandE.pdf), four study methods/results and general discussion.

**Method/result.** Three laboratory studies reported samples of 89, 50 and 58 undergraduates; a fourth surveyed 730 online-community members. Perceived competence and autonomy were associated with enjoyment and future-play preferences. Intuitive controls were associated with need satisfaction. In the first study, competence predicted choosing to continue the same game rather than an alternative.

**Limits.** Much of the mechanism evidence is associational; short console sessions and self-selected survey respondents differ from mobile puzzle users. Future-play intention is not measured long-term retention. Some average well-being changes were negative, so this is not evidence that more play is inherently beneficial.

**Glowpath inference → hypothesis.** Keep reversible turns, clear optional mastery goals, player-selected pace and optional assistance. Predict stronger reports of understanding and control, plus voluntary replay, without increasing pressure to continue.

### E4 — meaningful success feedback matters more than sheer intensity

Kao, Ballou, Gerling, Breitsohl and Deterding, **How Does Juicy Game Feedback Motivate? Testing Curiosity, Competence, and Effectance**, CHI 2024. [Author full text](https://people.csail.mit.edu/dkao/pdf/3613904.3642656.pdf), §§3–6. [DOI](https://doi.org/10.1145/3613904.3642656).

**Method/result.** A preregistered online action-RPG experiment analyzed 1,699 adults across five conditions, with ten required minutes followed by optional play. Success-dependent feedback improved perceived competence; amplification alone unexpectedly reduced competence and effectance. Curiosity was associated with optional play; enjoyment was not a reliable predictor of it in the models.

**Limits.** One action game and short exposure. The authors suspect some amplified effects obscured action–outcome links; that explanation was not independently proven. Their model does not demonstrate that random rewards cause healthy return.

**Glowpath inference → hypothesis.** Trial a small response to every turn, a clearer response to a new connected star, and one readable arrival event. Predict better recognition of what changed and greater satisfaction than uniform bursts after every tap. Keep effects off important geometry.

### E5 — haptics can add value without maximal intensity

Singhal and Schneider, **Juicy Haptic Design: Vibrotactile Embellishments Can Improve Player Experience in Games**, CHI 2021. [University full text](https://dspacemainprd01.lib.uwaterloo.ca/server/api/core/bitstreams/723405dd-f236-4aab-96f2-c1db3491e37e/content), §§5–7. [DOI](https://doi.org/10.1145/3411764.3445463).

**Method/result.** Study 1 involved 26 participants comparing visuo-haptic stimuli. Study 2 recruited 38, analyzed 36, and compared six Breakout variants on participants' iPhones, at least 90 seconds each. Haptics affected enjoyment, appeal, immersion and meaning; stronger versus lighter haptics generally did not differ on these measures. Exact visual/haptic synchronization was preferred in the first study. Mastery did not significantly improve.

**Limits.** Short, remote iPhone sessions and one game; no evidence of multiweek retention or equivalent behavior across Android actuators.

**Glowpath inference → hypothesis.** Compare a light synchronized confirmation and a distinct arrival vibration with haptics off. Keep an off switch and complete visual/semantic feedback. Predict better perceived responsiveness, without fatigue; verify on actual phones, not the browser.

### E6 — thumb accuracy needs generous, tested controls

Parhi, Karlson and Bederson, **Target Size Study for One-Handed Thumb Use on Small Touchscreen Devices**, MobileHCI 2006. [Author full text](https://www.cs.umd.edu/~bederson/images/pubs_pdfs/p203-parhi.pdf), §§4–7.

**Method/result.** Twenty right-handed adults, 17 men and three women, performed discrete and serial thumb-target tasks while standing, using an HP iPAQ. Target size and position affected performance and preference. The authors recommended approximately 9.2 mm discrete targets and 9.6 mm serial targets for that setup.

**Limits.** Old PDA hardware, one handedness and a small, unrepresentative sample; not a modern-phone accessibility standard. Physical millimeters cannot be equated directly with Flutter logical pixels. It does not supply a universal modern “thumb zone.”

**Glowpath inference → hypothesis.** Preserve the tested 48-logical-pixel minimum and visible spacing; keep frequent actions close to the board. Test both hands, different phone sizes and motor abilities. Predict fewer adjacent-cell errors without hiding the route under the thumb. Do not shrink controls to make room for planets.

### E7 — richer worlds can improve appeal; animated backgrounds remain unproven

Meiners, Reich, Hicks, Alexandrovsky and Gerling, **Lushness in Game Design: The Role of Non-Interactive Visual Embellishments in Player Experience**, FDG 2025. [Institutional full text](https://publikationen.bibliothek.kit.edu/1000180225/158028424), §§3–5, especially §5.5. [Repository record](https://publikationen.bibliothek.kit.edu/1000180225).

**Method/result.** Thirty-one adults played four decoration levels of one 2D platformer, approximately five minutes each in varied order. Decoration improved audiovisual appeal and attractiveness; a moderate-to-extreme increase was not significant. No significant competence, immersion or cognitive-load effects were detected.

**Limits.** Short laboratory exposure, mostly young participants, and exclusion of visual/hearing impairments. Crucially, the study tested **static** embellishments, not animated backgrounds. Null results are not proof of harmlessness or long-term benefit.

**Glowpath inference → hypothesis.** Compare a sparse scene with restrained static planets around an unchanged board. Assess moving planets separately. Predict higher visual appeal without worse endpoint recognition; reject motion that distracts, causes discomfort or obscures paths. No retention claim follows from this paper.

## Space-voyage design specification to test

The following details are product hypotheses informed by the register, not timings or layouts prescribed by the papers. Preserve the existing accessibility requirements in `ACCESSIBILITY_PLAN.md` throughout.

| Area | Proposed behavior | What would make us revise it |
| --- | --- | --- |
| Start and destination | A distinct launch symbol entering the first tile, marked **START**, and an outward destination ring marked **PORTAL**. The instruction says “Connect START through all 3 stars to the PORTAL.” The same nouns appear in Help and semantics. | Players think the launch symbol is a button, mistake scenery for a destination, or reach the portal without understanding the stars. |
| First three routes | First route: one clear turn demonstrates cause and effect while keeping all three required stars visible. Second: connect a short bend and inspect a collected star. Third: require a small detour and leave Undo/Hint discoverable. Allow experimentation and replay. | The first route teaches a false rule, feels like automatic completion, or learners cannot solve a new route without the prompt. |
| Hint intent | First request identifies the relevant connection with persistent text and a shape marker. A separate **Show a turn** action demonstrates help. Explain assistance before it changes score eligibility; retain Undo. | Players expect a move from the first button, cannot understand the marker, or feel that the game solved too much. Keep direct help available for people who prefer it. |
| Turn feedback | Update the logical board on input; use a brief rotation that can accept further turns. Keep star markers fixed while the connector rotates. | Repeated taps are dropped, extra taps accumulate unexpectedly, or users cannot tell the final orientation. |
| Star and arrival | A newly connected star changes outline to filled state and updates a named count. Arrival shows the completed route, actual score and a short optional voyage transition. Next and a clear stopping choice remain available. | Celebration hides the explanation, advances without consent, feels repetitive, or counts a replayed reward twice. |
| Galaxy progression | A route map shows the current location, earned progress and next destination. Unlocks have a visible fixed rule; a wormhole can mark an earned chapter transition. Keep puzzle difficulty and reward rules understandable. | Players cannot explain the unlock, confuse map decoration with selectable nodes, or see repeated filler without new puzzle interest. |
| Planets and stars | Put scenery outside the board's visual field or behind a quiet opaque board surface. Decorative stars differ from collectible star glyphs. Start with a static scene; try slow optional motion only as a separate variant. | Endpoint recognition worsens, contrast changes, small screens lose space, or anyone reports discomfort. Reduced-motion settings must freeze decorative motion and preserve all outcomes. |
| Longer sessions | Offer fresh route structures, optional efficiency challenges and chosen pace. Preserve progress when leaving; present natural completion points. | More minutes come with boredom, confusion, pressure or difficulty stopping. A completed satisfying short session is a successful outcome. |

Do not add expiring streaks, artificial energy shortages, opaque difficulty changes, near-miss reward messaging or random reward pressure to satisfy a duration metric. This is a product boundary, not a claim that the reviewed studies tested those practices. A galaxy map should communicate earned travel, not create an obligation to check in.

## Bounded evaluation plan

### First-play diagnosis

Begin with 6–8 fresh adult volunteers, using free friends/family testing where available. Include different puzzle familiarity, phone sizes and handedness; invite accessibility needs without claiming this small sample represents all players. Let each person try the opening without coaching. Record mistakes and observations with permission, using participant codes rather than unnecessary personal identifiers.

Use these tasks: identify the start and destination; predict what tapping a tile will do; connect the first star; complete a route; explain the three-star rule; use Undo; ask for help; stop and resume. Ask for an explanation of the rule again on an unseen route. Separate gameplay misunderstanding from imprecise taps or unreadable controls. Report counts and concrete failure examples; do not present this convenience sample as a retention experiment.

### Compare one design question at a time

| Comparison | Primary outcome | Guardrails |
| --- | --- | --- |
| Existing endpoints vs labeled launch/portal | Correct identification and first meaningful action without coaching | Visual appeal, unclipped labels, 48px targets, screen-reader clarity |
| Current opening vs playable sequence | Rule recall and unassisted transfer to an unseen route | Ability to skip/replay teaching; no blocked experimentation |
| Immediate auto-turn vs staged optional help | Reported usefulness and next independent action | Spoiler complaints, extra confusion, clear assistance status |
| Uniform vs progress-specific feedback | Accurate explanation of the result and satisfaction | Rapid-input correctness, route visibility, discomfort |
| Sparse vs static space scenery | Appeal rating alongside correct endpoint identification | Recognition time, distraction, text/graphic contrast |
| Static vs moving version of the same scene | Preference and reported comfort | No reduction in comprehension; OS and in-game motion settings |
| Haptics off vs light feedback | Perceived response and event distinguishability | Fatigue, unwanted vibration, different device hardware |

For short comparisons, vary order across participants and use matched but different boards so memorizing a solution does not favor the second version. A first-exposure comprehension comparison needs fresh participants per variant; showing both openings to the same person cannot recreate first play. Log the exact version and puzzle seed. Choose the primary outcome before reviewing results and keep null/negative observations.

### Voluntary return and longer use

After comprehension problems are resolved, invite a small consenting cohort to use the build for 7–14 days without reminders or streak pressure. Ask whether they chose to return, what they wanted to do, whether sessions felt satisfying, and why they stopped. Report return counts with denominators, completed routes per active session, self-reported enjoyment/control and reasons for leaving. Distinguish an intentional completed session from a crash, interruption or unresolved confusion. Optional time played is secondary evidence, never a requirement to keep playing.

This pilot can reveal recurring problems and useful preferences. It cannot establish a population retention uplift, advertising ROI or a revenue forecast. A later randomized release experiment needs a baseline, a prespecified meaningful effect, a suitable sample-size calculation and adequate follow-up; the reviewed papers do not supply those numbers for Glowpath.

## What this review does not establish

No reviewed study proves that a space theme, wormhole animation, a particular rotation duration or a daily trio will increase Glowpath's revenue or long-term retention. Haptic and animation quality still require physical-device checks. Static decorative-world evidence does not establish safety or usefulness of continuously moving scenery. Existing passing widget tests establish specific software behavior, not human comprehension, comfort or enjoyment.

The immediate research-backed order is therefore: diagnose and clarify the goal; test independent learning and useful help; verify precise controls and honest success feedback; then evaluate the voyage's visual richness and voluntary return. Keep every recommendation that crosses genres or timescales labeled as a hypothesis until Glowpath players provide evidence.
