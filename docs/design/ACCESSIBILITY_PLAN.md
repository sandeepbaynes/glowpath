# Glowpath accessibility plan

Reviewed 22 November 2026. The coordinating agent reports **52 automated tests passing**, including the accessibility and UI tests described below, plus manual browser checks at four viewport sizes. This document records that evidence and the remaining acceptance work; it does not claim a completed device accessibility audit. Scope: the original UI, the rewritten `lib/main.dart` and `lib/ui` components, tests, and installed Flutter 3.50.1 test/framework sources. Baseline line references below describe the original snapshot, not the rewritten files.

## Release requirements

- Use at least **48 × 48 logical pixels** for every enabled game control on both platforms. This satisfies Flutter's 48 × 48 Android and 44 × 44 iOS guideline checks. Measure the real hit/semantics area, not just the visible icon. Adjacent tile targets must not overlap.
- Keep essential text readable at system text scales 1, 1.5, 2, and 3. Reflow, wrap, or scroll vertically; do not shrink essential instructions with `FittedBox`, clamp system text scaling, or clip labels to make a screenshot fit. Proposed type tokens: body/actions 16–17, secondary information 13–14, and no visible text below 11 logical pixels at scale 1.
- Require text contrast of at least 4.5:1 for ordinary text and 3:1 for large text. Use 3:1 for meaningful board graphics and custom focus/selection indicators against adjacent backgrounds. Decorative stars and borders need not carry meaning.
- Provide names, actions, selected/disabled states, and useful updates to assistive technology. A person must be able to complete the core game using a screen reader or keyboard.
- Support iOS Reduce Motion and Android Remove Animations independently. Convey success, connection, star collection, and invalid actions without requiring motion, color, sound, or haptics.

Flutter's [UI accessibility guidance](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling) documents platform target sizes, text scaling, and text contrast. Apple's [UI design guidance](https://developer.apple.com/design/tips/) recommends 44-point controls; its [Typography HIG](https://developer.apple.com/design/human-interface-guidelines/typography) lists 17-point default and 11-point minimum iOS text, and recommends layout changes as text grows. The stricter shared 48-pixel target and proposed type tokens above are project choices. The [W3C non-text contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) supports the 3:1 graphics/state target; a decorative border is not automatically a failing control boundary.

## Baseline findings in the replaced UI

| Priority | Evidence in the audited snapshot | Consequence / required check |
| --- | --- | --- |
| P1 | `main.dart:319` uses 24-pixel horizontal page padding; `:594–596` uses a 19-pixel board gutter and 5-pixel gaps. At width 320, each tile is `(320 − 48 − 38 − 20) / 5 = 42.8` pixels. | The 25 primary targets miss both platform goals. Reduce outside/gutter spacing at narrow widths while preserving at least 48-pixel non-overlapping cells. A 5-column board is feasible at width 320; do not solve this by overlapping invisible hit boxes. |
| P1 | `_modeButton`, around `:556`, has 12 pixels of vertical padding per side and a 17-pixel icon, but no minimum target constraint. | Default-scale height can be approximately 41–42 pixels, depending on text metrics. Add an explicit 48-pixel minimum and verify both mode semantics nodes. |
| P1 | Font sizes 8 (`:491`, `:826`, `:879`), 9 (`:351`), and 10 (`:399`, `:475`, `:865`, `:902`) appear in secondary/status labels. | Raise or remove nonessential microcopy. Progress, difficulty, and daily-reset information must remain legible. Existing large-text tests do not validate baseline legibility. |
| P1 | Unlit, still-interactive pipes use `#71858C` on `#293E4B` (`:932`, `:949`, tile material). Calculated contrast is approximately **2.88:1**. | Increase contrast of the pipe shape, which is essential to solving. “Unlit” is not the same as a disabled control. Flutter's text-contrast check will not inspect this `CustomPaint`. |
| P2 | Footer text uses `#6A818C` over the sky gradient (`:491`). Contrast is approximately **4.35:1** over its darkest stop `#0C1923` and **2.83:1** over `#253C45`. | It misses 4.5:1 even before considering antialiasing. Raise contrast or remove the nonessential footer. Ratios are calculated from source colors, not measured screenshots. |
| P1 | Difficulty buttons (`:873`) communicate selection using color and weight, without a selected semantic state. | Announce exactly one selected pace; also use a visible selection indicator that does not depend on hue. |
| P1 | Tiles have useful row/column and connection labels, but `enabled: !status.solved` (`:660`) coexists with an always-present `InkWell.onTap` (`:670`). `_rotate` returns early if loading/solved. | Match announced state to operability: no tap action or keyboard activation while unavailable, and loading must also be represented. Check the merged semantics tree; source intent alone is insufficient. |
| P2 | The three collected-star icons (`:413`) have no aggregate count label. Collection progress (`:843`) lacks a descriptive semantic label. | Expose “2 of 3 stars connected” and a named constellation progress value; avoid three indistinguishable announcements. Verify that visible progress text and indicator are not announced twice. |
| P2 | Completion (`:715`) and assisted status change in ordinary text, without a deliberate live region or focus policy. The hint snackbar lasts two seconds (`:252`). | Provide a concise completion/progress announcement without moving focus unexpectedly. Keep essential hint/assistance information available after any snackbar disappears. |
| P2 | Header uses `FittedBox.scaleDown` (`:520`); controls are always three columns (`:733`); collection is a fixed horizontal composition (`:815`); content is always capped at 470 pixels. | Check actual 3× labels and readable text, not just absence of overflow. Reflow controls/collection at large sizes. Landscape should keep the board usable, with vertical scrolling as a fallback. |
| P2 | Difficulty buttons request `minimumSize: Size(0, 40)` (`:891`). | This is a visual minimum, not proof of a 40-pixel target: Material may pad hit regions. Verify the rendered semantic/hit area before treating it as a failure. |
| P2 | Existing tests use mostly 430 × 1100, plus a single 320 × 568 / 2× Hint flow. No Guideline API, keyboard, screen-reader-state, or reduced-motion checks exist. | Add the matrix and specific behavior checks below after the redesigned UI is stable. Keep existing gameplay regression tests. |

Positive foundations: the game is untimed; Hint/Undo are free; tiles already have spatial/connection labels; the help dialog is scrollable; mode buttons expose `selected`; controls use standard button widgets; the page can scroll vertically. Preserve these properties.

The rewritten source uses 16-pixel phone page padding, 15-pixel board rails, 3-pixel gaps and a 1-pixel border, giving 48.8-pixel cells at a 320-pixel viewport. It introduces Atkinson/Lora fonts, larger text, explicit 48-pixel button minima, descriptive star semantics, persistent hint instructions, disabled solved tiles, and both OS motion flags. The automated checks below now pass for the tested states. Device checks remain necessary. The wordmark intentionally keeps a fixed size as branding; essential game text retains system scaling.

## Layout and text-size matrix

Dimensions are logical pixels at DPR 1 in widget tests, not physical hardware pixel counts. **Pass** means the automated play/hint layout, reachable-control, label and target checks pass for that pair; it does not mean every manual state below was tested at that pair. The twelve other pairs remain pending. Linear scales are deterministic stress tests; separately check the real OS's largest text setting because platform scaling can be nonlinear.

| Viewport | 1× | 1.5× | 2× | 3× | Specific risk |
| --- | --- | --- | --- | --- | --- |
| Phone 320 × 568 | Pass | Pass | Pass | Pass | 48-pixel tiles; mode/action labels; no forced horizontal page scrolling; scroll to lower controls. |
| Phone 390 × 844 | Pass | Pending | Pending | Pending | Normal play composition, long completion title, help and daily status. |
| Large phone 430 × 932 | Pending | Pass | Pending | Pending | Intermediate layout breakpoint, longer labels, real-font wrapping. |
| Landscape 844 × 390 | Pass | Pending | Pending | Pass | Short height; all board cells and controls reachable; keyboard focus brings off-screen controls into view. |
| Tablet 768 × 1024 | Pass | Pending | Pass | Pending | Readable board sizing, stable focus order, no overly wide text blocks; touch remains 48 pixels. |
| Desktop 1280 × 900 | Pass | Pending | Pending | Pass | Keyboard-only play, visible focus, pointer activation, no tiny controls despite large canvas. |

For the full 24-configuration review matrix, inspect these states. Automated coverage uses the bounded critical pairs below; remaining pairs can be covered by visual/device review rather than duplicating every interaction in every widget test:

1. Fresh Journey: first board, initial disabled Undo/Restart, current pace, help entry.
2. In progress: rotate a tile; verify changed connections, move count, enabled Undo/Restart, Hint, and collected-star state. Scroll each tested control fully into view before guideline checks.
3. Daily trio: selected mode and progress/reset text, with no stale pace selection in the accessible tree.
4. Completion: long daily-completion variant, score and assistance label, inactive board, reachable Next/Revisit control. Keep the full completion text; do not truncate the essential result.
5. Help: long instructions can scroll, both actions can be reached, dismissal returns focus sensibly. Verify the open-source licenses route on 320 × 568 at 3× and 844 × 390 at 2×.

Across all states: no framework/layout exception, no overlapping essential labels, no clipped actionable content, and no content-dependent loss of an action. Off-screen content in an intentional scroll view is allowed; prove it can be revealed and activated. `tester.takeException() == null` alone is not evidence that text is visible or readable.

Add one portrait-notch/inset case and one landscape-inset case at 390 × 844 / 844 × 390. In a running build, verify safe areas and the keyboard/focus overlay do not cover the active tile or dismiss button. Recheck after rotating without resetting game progress.

## Supported automated checks

The following APIs were verified by reading the installed SDK at `/opt/homebrew/share/flutter`, not by assuming old sample code applies:

- `packages/flutter_test/lib/src/accessibility.dart`: `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` and `MinimumTapTargetGuideline`.
- `packages/flutter_test/lib/src/matchers.dart`: `meetsGuideline` and the current partial semantic matcher `isSemantics`. Older `containsSemantics` is deprecated in this SDK.
- `packages/flutter_test/lib/src/window.dart`: `tester.platformDispatcher.textScaleFactorTestValue`, `accessibilityFeaturesTestValue`, and `FakeAccessibilityFeatures` including independent `reduceMotion` and `disableAnimations` flags.
- `packages/flutter/lib/src/widgets/media_query.dart`: `TextScaler`, `MediaQuery.reduceMotionOf`, and `MediaQuery.disableAnimationsOf`.

Use the project's existing test imports (`material_ui` and `flutter_test`). A fixture should reset all view/dispatcher settings and mock preferences for each test. The following is a harness outline, to adapt to the final UI rather than paste in as a complete test:

```dart
tester.view.devicePixelRatio = 1;
tester.view.physicalSize = viewport;
tester.platformDispatcher.textScaleFactorTestValue = scale;
addTearDown(tester.view.resetDevicePixelRatio);
addTearDown(tester.view.resetPhysicalSize);
addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
SharedPreferences.setMockInitialValues({});
final controller = (await tester.runAsync(() async {
  final value = GameController(
    preferences: await SharedPreferences.getInstance(),
    now: () => DateTime.utc(2026, 11, 22, 12),
    snapshotWriter: (_) async => true,
  );
  await value.load();
  await value.flush();
  return value;
}))!;
addTearDown(controller.dispose);
final semantics = tester.ensureSemantics();
try {
  await tester.pumpWidget(GlowpathApp(controller: controller));
  await tester.pumpAndSettle();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
} finally {
  semantics.dispose();
}
```

[Flutter's accessibility test documentation](https://docs.flutter.dev/ui/accessibility/accessibility-testing) describes these guideline checks and native inspectors. Use a semantics handle throughout each test and dispose it in `finally` before the test callback returns; `addTearDown` runs too late for Flutter's outstanding-handle verification. Do not add a nested `MaterialApp` merely to force a text scale: verify the actual `MediaQuery.textScalerOf(GameScreen)` receives the intended setting. Use bounded pumps for motion tests; an endless animation must not make an unrestricted `pumpAndSettle` the test's only failure signal.

### Important limits of guideline passes

The installed target-size traversal ignores hidden, non-actionable, merged, and link nodes, and skips nodes touching a viewport/scroll boundary. Therefore scroll all required controls completely into view and directly measure interior tile targets, including corners and edges. Verify target rectangles do not overlap and that taps near their edges activate the intended cell.

The label guideline accepts a label **or tooltip** and cannot assess whether it is meaningful. A generic “Turn clockwise” on every tile is insufficient; assert row, column, connection directions, entrance/exit, star, and lit status where relevant. Avoid duplicate labels from nested Tooltip/Semantics/InkWell widgets.

The text-contrast algorithm samples rendered pixels and matches visible text semantics. It is approximate, ignores disabled nodes, and does not validate custom-painted pipes, star-state graphics, or keyboard focus rings. Pair it with explicit color-pair contrast checks and real-font visual inspection. Do not erase semantics or mark useful text hidden to obtain a pass.

The twelve passing automated critical pairs are: 320 × 568 at all four scales; 390 × 844 at 1×; 430 × 932 at 1.5×; 844 × 390 at 1× and 3×; 768 × 1024 at 1× and 2×; 1280 × 900 at 1× and 3×. This covers every requested size and scale, with extra emphasis on narrow and short screens, and exercises the tablet/desktop wide layout at default scale. Keep any previously failing combination as a regression test. The accessibility tests load the configured Atkinson/Lora fonts. Extend raster contrast checks to each distinct text/background/state combination as that UI settles.

The implementation is in `test/accessibility_test.dart` and `test/game_screen_test.dart`. It injects a fully loaded controller with a fixed UTC date and an in-memory save writer. Passing coverage includes the twelve critical pairs, actual tile rectangles, visible target/label guidelines, tile semantic activation and solved state, collected-star reporting, mode selection, representative text contrast, both independent OS motion flags, keyboard activation, modal dismissal, and the completion/next flow. A normal-motion test observes an intermediate rotation, interrupts it with three more taps, then checks the final rendered angle and move count. A narrow-phone 3× sheet test verifies reachable settings switches, changing the contrast setting, and closing Settings, Help and Atlas with an explicit control. This automated scope does not replace the remaining visual/device checks in this plan.

Source-color contrast calculations for the final palette: body on paper **10.66:1**, secondary text **5.44:1**, rust text **5.61:1**, unlit pipes on tiles **4.98:1**, lit pipes on lit tiles **5.27:1**, and the focus ring on unlit tiles **7.10:1**. These are opaque source-color calculations, not a full rendered-state audit.

### Behavioral acceptance inventory

This inventory includes release checks beyond the passing test subset. The recorded results below identify what has actually been verified.

| Test | Meaningful assertion |
| --- | --- |
| Tile activation and state | One semantic activation and one keyboard activation each rotate exactly once; connection directions update. Lit/unlit, star, entrance and exit descriptions match the board. |
| Availability | Loading and solved tiles have no usable tap action. Undo/Restart disabled state changes with history and remains consistent with keyboard behavior. |
| Selection | Exactly one mode and one Journey pace are selected; selecting another updates the semantics and visible indicator. |
| Progress/completion | A concise progress/result live region updates once per meaningful event. Moving focus does not reread the whole board; a completion announcement does not remove access to the result. |
| Keyboard | Tab/Shift+Tab reach all controls in a logical order; Enter/Space activate; focus is visible; help can be closed with Escape; there is no focus trap. If arrow-key tile navigation is added, test its boundaries and restoration after dialogs. |
| Touch geometry | All 25 cells have at least 48 × 48 non-overlapping targets at width 320. Check mode, Help, Hint, Undo, Restart, pace, Next and dialog controls with the guideline and actual hit tests. |
| Persistence of help | Hint information and assistance status remain understandable after a snackbar ends; no essential action depends on responding within two seconds. |
| Motion settings | Independently test `FakeAccessibilityFeatures(reduceMotion: true)` and `FakeAccessibilityFeatures(disableAnimations: true)`, resetting the dispatcher afterward. Tap, undo, hint and complete: state changes still occur; movement/pulsing is removed or suitably reduced. |
| Color/sensory independence | Completion, selection and collected stars have a shape/text equivalent. The game remains understandable in grayscale and with sound/haptics disabled. |

**SDK-specific motion note:** iOS `reduceMotion` does not set `disableAnimations` in Flutter 3.50.1 and does not automatically shorten `AnimationController`. Read both settings for custom effects. Merely overriding `MediaQuery.disableAnimations` does not override the engine-level animation policy; use dispatcher test features to exercise that policy. Test actual result and motion, not only the value of a duration field.

## Manual acceptance before claiming support

Use VoiceOver on iPhone/iPad and TalkBack on Android to navigate from entry to one solved puzzle, change mode/pace, use Undo/Hint, and dismiss Help. Verify rotor/swipe order and spatial tile descriptions with eyes off the display. Test keyboard-only play on desktop/web, and Full Keyboard Access on an Apple device where available. Check the actual web semantics tree if web is distributed.

Use Xcode Accessibility Inspector and Android Accessibility Scanner for runtime audits. Repeat the short play flow with largest OS text, bold text, increased contrast, grayscale, and reduced motion. Check readability outdoors/at low screen brightness and rapid repeated taps on a real phone. Record device/OS, settings, screenshots, failures, fixes, and retest result; a screenshot or widget-test pass alone is not a screen-reader audit.

Apple's [Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility) supports multiple sensory cues, keyboard navigation, switch/voice interaction, and reduced motion. Its guidance also warns about timed disappearing information. The workflow and release checks here are Glowpath-specific applications of those principles.

## Recorded results — 22 November 2026

The coordinating agent supplied the following execution and browser evidence. No additional SDK commands were run to update this record.

| Check | Result and scope |
| --- | --- |
| Automated suite | **52 tests passed**, including the latest UI/accessibility tests and existing game/model regression tests. |
| Static analysis | Final rerun passed with no issues, including the system-bar-style and entrance-arrow edits. |
| Layout/text scale | All twelve viewport/scale pairs in the table passed, including 300% text at narrow-phone, landscape and desktop sizes. Tested controls remain reachable through scrolling with no reported layout exception. |
| Target geometry | All 25 rendered tile rectangles are at least 48 × 48 logical pixels and do not overlap in the tested pairs. Visible Android target/label checks and the representative iOS target check passed. |
| Contrast and semantics | Representative rendered text-contrast checks passed with Atkinson/Lora loaded. Tests passed for named tiles and changing connections, semantic activation, disabled solved tiles, collected-star reporting, and selected modes. These checks do not establish complete custom-painted-graphics contrast or real screen-reader usability. |
| Motion | Independently setting the iOS `reduceMotion` or Android `disableAnimations` feature made the rendered turn reach its final state immediately. With normal motion, the test observed an intermediate frame after 40 ms, interrupted the turn with three further taps, and verified four moves, the original logical orientation and one full rendered rotation after settling. |
| Sheets and input | Settings, Help and Atlas close controls worked at 320 × 568 / 3× text; the contrast switch remained reachable and operable. Escape dismissal, keyboard tile activation, Undo, mode changes, Hint and completion/Next flows passed. |
| Manual browser layouts | Checked at 390 × 844, 320 × 568, 844 × 390 and 1280 × 900. Browser checks are viewport evidence, not physical-device measurements. |
| Manual browser flow | A tile tap registered one move; motion and contrast settings toggled and the sheet closed. A seven-turn solution earned 200 unassisted points. Reload preserved the completed board and six total stars without a duplicate award; the Atlas was checked. A second reload preserved the unfinished Journey 3 board at four turns with two lit stars. |

Still pending: the untested full-matrix pairs and remaining states/insets; an end-to-end VoiceOver solve on iOS and TalkBack solve on Android; real-device focus/announcement behavior and largest OS text settings; physical haptics; and frame-pacing/performance measurements on actual devices. Browser interaction and deterministic widget animation checks do not establish physical-device performance.

Preserve the puzzle, score, daily-seed, persistence and accessibility regression tests. Record device/OS and results when the pending device audit is performed; do not advertise unverified screen-reader or performance support.
