# Glowpath 0.3 competitor research

Reviewed 22 November 2026. Scope: Flow Free, Two Dots, and Threes, using eight publisher or firsthand sources. These are useful design comparisons, not evidence that copying their presentation will reproduce their commercial results. No current chart position, revenue, retention rate, or causal uplift is claimed.

This is a document review, not a hands-on audit of the current apps. Store text and release histories were accessible; their screenshot links resolved to placeholder artwork in the research tool. Current button placement, animation timing, ad frequency, and first-run flows therefore remain unverified. Historical UI details below are explicitly dated. No competitor assets were downloaded or reused.

## Documented evolution

### Flow Free: protect the rule, expand the puzzle supply

The developer's June 2012 announcement offered 300 levels and reported three million iOS downloads at that time. Its rule already combined matching endpoints with covering the whole board. A July 2012 FAQ distinguished a completed level's check from a perfect result's star and explained the optional text labels. That month's update made the completion dialog dismissible: players could inspect their finished route. These are historical details, not a claim that today's interface is identical. [Big Duck Games archive](https://www.bigduckgames.com/blog)

The current publisher listing still leads with that same objective. It advertises over 2,500 free levels, daily puzzles, tracked level completion, optional efficient-move goals, and a separate timed mode. Its visual description remains vector graphics, color, and sound; accessibility labels remain listed. Hint bundles appear among its purchases. This is evidence of a product growing around a recognizable rule, not of a wholesale visual reinvention. [Flow Free listing](https://apps.apple.com/us/app/flow-free/id526641427)

**Implication for Glowpath:** put the complete rule where players can see it: turn the route pieces, light all three stars, reach the portal. Connecting the destination alone must not look like an unexplained failure. Preserve a solved board long enough to enjoy it; place extra challenge alongside completion rather than obscuring the accomplishment.

### Two Dots: a simple board can belong to a larger world

In an April 2018 interview, cofounder Patrick Moberg described Dots starting as an art-and-technology prototype, tested with people weekly. He distinguished that first game from David Hohusen's Two Dots direction: characters, a richer illustrated world, and deeper play. He also described a then-current three-week release cadence for new levels/art and weekly events with completion rewards. Those are the founder's retrospective observations, not controlled evidence that illustrations or events caused retention. [Founder interview](https://www.ycombinator.com/blog/gaming-studio-founders-patrick-moberg-and-holly-liu)

The current listing juxtaposes the dot-connection puzzle with illustrated hidden-object worlds. Forming a square clears that color; Power-Ups help when stuck. The publisher advertises thousands of levels, several modes, collections, badges, and a free colorblind mode. Its June 2024 anniversary announcement documents a specific later expansion of the presentation: decorated home screen, dressed-up characters, themed hunts, and reward tiles that change as players win. [Two Dots listing](https://apps.apple.com/us/app/two-dots-connect-the-colors/id880178264), [tenth-anniversary announcement](https://www.twodots-game.com/news/10th-birthday-a-decade-of-dots)

**Implication for Glowpath:** let completed routes reveal a coherent planetary journey. A planet should be a recognizable destination with visible progress, not another unrelated card. Keep space scenery around the board quieter than the puzzle. A three-board daily expedition can give a clear reason to return without the production burden of several unrelated game modes.

### Threes: resolve the system before decorating it

In their April 2014 interview, Asher Vollmer and Greg Wohlwend describe a quick first prototype followed by a much longer development. Walls, monsters, and power-ups did not solve the fundamental problem; simplifying the system and refining merge rules did. The art changed alongside those experiments, eventually finding personality in small numbered characters. Their anecdotes about eager early testers are qualitative observations, not a retention benchmark. The article has inconsistent release-month references, so it is not used here to establish a precise launch date. [Creator interview](https://www.pocketgamer.biz/fighting-the-monsters-the-making-of-threes/)

Their public development emails provide unusually concrete historical UX evidence. In November 2013 they discussed consistent navigation positions, score-review actions such as retry and menu, and tutorial iterations that combine instructions, action, and visible results. They disagreed about how much explanation to provide and continued testing. This was a development discussion; an individual sketch or proposed sequence is not necessarily what shipped. [Dated development archive](https://asherv.com/threes/threemails/)

The paid edition's current listing still emphasizes one mode and characterful cards. Release history records night colors and a statistics screen in the 2014 updates, home-bar gesture protection in September 2020, a dark launch screen in February 2021, and an additional score leaderboard in June 2025. These are concrete examples of legibility, comfort, input, and mastery improvements over time. [Threes listing and release history](https://apps.apple.com/us/app/threes/id779157948)

**Implication for Glowpath:** a space skin cannot fix an ambiguous start/end or an uninteresting puzzle. Teach each action with a tiny playable example. Make each rotation visibly change the route, and use short text to explain its purpose. Keep menus and results predictable as the art evolves.

## What could support repeat play

The following are design hypotheses inferred from the documented features, not proven explanations of these games' success.

| Pattern | Possible player value | Glowpath experiment |
| --- | --- | --- |
| Stable, legible rules | Less effort remembering how to play | Use the same beacon, stars, and portal meanings in every chapter. |
| Short completed units | A satisfying stopping point | Complete one route, inspect it, then choose the next route. |
| Visible lasting progress | A reason to care about the next puzzle | Light a route on the planetary chart and show distance to the next destination. |
| Optional mastery | A reason to revisit familiar content | Offer a clearly explained personal best without invalidating an assisted solve. |
| Fresh bounded content | A predictable return occasion | Retain a daily set of three, with a finished state rather than an endless demand. |
| Distinctive feedback | A memorable action and outcome | A turn connects light; a collected star stays lit; reaching the portal resolves the journey. |

A large level catalogue, established audience, publisher resources, and years of iteration are major differences from Glowpath. None of these sources supplies a defensible conversion from visual polish to the project's revenue target.

## Proposed 0.3 direction: chart a route through space

These are recommendations for implementation and playtesting, not assertions that the current build already has them.

1. **Make the fiction explain the objective.** Name the start **Launch beacon** and the destination **Portal**. Give them different silhouettes and persistent labels, with a clear connection to their edge cells. Use the instruction “Turn the paths. Light 3 stars. Reach the portal.” A destination connected too early should say how many stars remain. Avoid relying on glow or hue alone.

2. **Teach through three small successes.** First, one corner turn connects beacon and portal. Next, introduce a star directly on that route. Then introduce a detour that collects all three stars. Keep instructions next to the relevant action; let the player act immediately. Use authored, verified boards for these lessons. A help sheet remains available later.

3. **Separate scenery from interactive information.** Put a small number of original planets and distant stars outside the board's main reading area. Keep tile edges, pipe exits, unlit stars, and endpoint connections crisp against a stable dark surface. Make the route the brightest continuous element. Preserve existing readable fonts and high-contrast controls. Decorative floating motion should be subtle and optional; Reduce Motion should leave a fully understandable still scene.

4. **Make the planetary chart functional.** Show the current planet, completed routes, and the next reachable destination. Tie a chapter reward to an explicit number of solves. Reveal a new planet or a wormhole connection at a chapter boundary. Start with a few authored destinations and a coherent visual vocabulary; a sprawling galaxy and additional mechanics can wait for evidence that players enjoy the core loop.

5. **Let completion explain the reward.** Leave the illuminated route visible. Use a compact result with collected stars, score explanation, and the progress gained on the chart. Keep **Continue** primary and **Journey map** secondary, with an unobstructed board view available. Avoid simultaneous animated counters, collectible popups, and route effects competing for attention. Do not auto-advance before the player can understand the outcome.

6. **Make help predictable and fair.** Keep Hint and Undo clearly labelled and consistently placed. Explain what a hint changes before its first use; preserve the existing assistance marker without shame or lost chapter access. A hint should highlight or rotate a useful piece and make the resulting connection easy to follow. Do not introduce paid rescue, hidden difficulty manipulation, or time pressure as part of this visual revision.

7. **Use motion to show causality.** Rotate the selected piece, illuminate the newly reachable path, acknowledge a star, then resolve the portal. Input should remain responsive during presentation. Reduced motion uses immediate, persistent state changes. Maintain understandable semantics for each tile and separate start/goal announcements; screen-reader usability still requires device testing.

## Validation before calling the redesign successful

Use fresh testers and record observations with consent; no individual fingerprinting is needed. These are proposed checks, not measured results or industry benchmarks.

- In the first minute, can the player identify the start, destination, rotation action, and three-star requirement without coaching? Note the first mistaken assumption.
- Does a player who reaches the portal early understand why the puzzle continues? Can they find Hint and Undo independently?
- After a solve, can the player explain what they earned and where Continue leads? Can they inspect the completed route and return to the chart?
- After leaving mid-board, does resume preserve the exact puzzle and assistance state? Can the daily set end without pressure to keep playing?
- At large text, in grayscale/high contrast, with Reduce Motion, and using TalkBack or VoiceOver, do the objective and controls remain usable? Check performance on a modest real Android device.
- For repeat play, observe later voluntary returns and ask what motivated them. Record sample size and elapsed days. Do not treat a friend saying the art looks good, or one long session, as evidence of durable retention.

The next design decision should follow the largest observed comprehension problem. Prefer a clear, satisfying five-minute experience before expanding the map, adding new mechanics, or building live events.
