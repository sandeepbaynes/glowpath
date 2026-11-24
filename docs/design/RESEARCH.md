# Glowpath design research

Scope: bounded source audit and design checks for the existing Flutter prototype. Reviewed `lib/main.dart` and `docs/screenshots/phone-preview.jpg`; this is not a completed usability or accessibility test. Use original procedural graphics and the existing licensed fonts; no AI-generated artwork or new purchases.

## Selected online skill

Use [game-design by xaviertorgerson](https://github.com/xaviertorgerson/game-dev-skills/blob/main/game-design/SKILL.md) as a reference for this pass. The [complete raw source](https://raw.githubusercontent.com/xaviertorgerson/game-dev-skills/main/game-design/SKILL.md) was read. Its framework-neutral guidance is self-contained enough for Flutter: start with the player's action and intended feeling, introduce mechanics through safe play, construct valid puzzles, evaluate pacing, preserve progress, and give proportionate feedback. Its review order places comprehension before decoration.

Apply selectively. For Glowpath, optional efficiency goals can provide mastery without timers, forced failures, constant idle movement, camera shake, or punishment. Treat its feedback prescriptions as hypotheses, not requirements. Keep the calm tone while making cause and effect unmistakable.

Audit: the reviewed file contains no executable commands, credential requests, upload instructions, or mandatory external services. It references adjacent build/assets skills but does not require them for its design advice. No installation was performed. Repository licensing and other files were not audited; retain links and original synthesis rather than copying the skill into this project. Remote guidance does not override the project budget or product constraints.

The alternative [design-game by playableintelligence](https://github.com/playableintelligence/game-creator/blob/main/skills/design-game/SKILL.md), also [read in full](https://raw.githubusercontent.com/playableintelligence/game-creator/main/skills/design-game/SKILL.md), assumes JavaScript scene files, `Constants.js`, an EventBus, and npm. It requires another `game-designer` skill and promotes a broader command pipeline. Its metadata says MIT, but that is not a repository-wide license audit. Its visual checklist is useful; the workflow is not self-contained or well matched to this Flutter project. Do not install it for this pass.

## Apple guidance applied

[Designing for games](https://developer.apple.com/design/human-interface-guidelines/designing-for-games) supports quick access to play, contextual teaching, readable adaptable layouts, direct touch controls, and multiple ways to perceive important information. [Motion](https://developer.apple.com/design/human-interface-guidelines/motion) emphasizes purposeful, brief feedback, user choice, and avoiding animation that blocks interaction. Both full Markdown versions were read; the checks below are our application to Glowpath, not Apple-prescribed timings or a certification claim.

## Five concrete design checks

1. **Learn by making a connection.** Replace reliance on the help dialog with a short authored opening sequence: one corner turn completes a route, the next board introduces a star, then a detour demonstrates the three-star objective. Show a hint only after hesitation and dismiss it after action. Give entrance and destination distinct shapes and labels. Test with a fresh player for two minutes without coaching; record where they pause and whether they can explain the rule.

2. **Let the board lead.** Retain Lora for a short title and Inter for gameplay information. Reduce the prominence of the large welcome text and collection card while a puzzle is active. Increase the current small helper labels and keep essential instructions readable at 200% text scaling. At 320 logical pixels wide, the current padding/grid calculation produces tiles around 42.8 pixels; adjust spacing to meet a 44-pixel touch-target design goal. Check safe areas, short screens, and large text without clipping or obscuring controls.

3. **Make each tap feel precise.** Trial a 140–180 ms clockwise quarter-turn and a restrained light transition on newly connected segments. Update game state immediately and handle rapid taps without dropped moves. Keep the star glyph fixed while its pipe turns. Use the existing light haptic only for meaningful confirmation, with an off option; show a single concise completion response. These durations are starting hypotheses. Verify repeated input and undo against the board state, then check frame pacing on a device.

4. **Make feedback work without motion or color.** Respect system Reduce Motion: replace rotations, pulses, and traveling light with immediate state changes or brief opacity changes; avoid background shimmer and camera movement. Preserve persistent route/star state, distinct endpoint shapes, and clear text. Verify tile row/column, connections, star, and lit status with VoiceOver, plus activation and focus order. Test grayscale, increased text, and silent/haptics-off play. Existing semantics are a useful starting point, not proof that these checks pass.

5. **Protect trust and continuity.** Keep hints and undo discoverable, explain assisted results plainly, and do not imply the reference move count is an optimum. Verify that leaving and returning restores the current board, moves, mode, and assistance state. Current persistence visibly stores aggregate progress; in-flight restoration needs implementation evidence before it is promised. Make restart intentional and reversible where practical. Preserve offline play and defer any future permission, rating, or monetization request until its purpose is clear; never interrupt a move.

Acceptance evidence should be a small set of before/after screenshots, device interaction checks, an accessibility pass, and observed playtest notes. Add only effects that improve a specific interaction; avoid decorative gradients, particles, or card layers that compete with the puzzle.
