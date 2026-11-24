# Glowpath 0.4.4 — steady layout, continuous transitions

22 November 2026. The user requested smooth transitions throughout the app and identified a header shift between arrival and gameplay.

Navigation now lives once in a shared, fixed SafeArea above the changing content. Voyage, Daily, help and settings keep the same width, gutters, position and widget identity across gameplay, arrival and mode changes. Both modes reserve equal label space and use constant font weight; selection changes only color and the orbital indicator. The universe continues to fill the device behind the shared interface.

Keyed page content and scenery dissolve over 320 ms. Rapid changes continue from the visible opacities. Outgoing layers immediately lose input, focus, semantics and active tickers, so a fading old page cannot receive a second action. Incoming controls are usable immediately. The timeout cover fades in and out over 260 ms; Retry still retains the edited route and restarts its clock immediately.

Hints and the success tools dissolve and resize smoothly. Guide text fades over 180 ms. Console selection, focus and enabled state interpolate over 220 ms; press feedback uses a 90 ms press-in and eased release, including keyboard activation. Button label and icon changes crossfade. Preference press surfaces ease over 160 ms. Sheets enter over 340 ms and return over 280 ms. Restart confirmation uses a 260 ms fade and small scale transition. Existing tile turns, elastic map return and onward flight remain.

Reduced Motion and platform animation-disabling settings remove decorative transitions. Fixed touch bounds, gameplay timing and one-Play progression remain. No deliberate input delay or extra gate was added.

## Verification

**229 tests pass**, with clean static analysis. Android, web and unsigned iOS release builds succeeded. Historical package checks and checksums are retained with the build artifacts.

New continuity tests compare exact rectangles and Element identity for all four navigation controls at 390×844, 820×1180, 1366×1024 and 320×568 with 3× text. They cover the payoff, mid-arrival, settled arrival, Play, and rapid 80 ms mode reversals. Existing eight-tablet and phone/accessibility coverage remains.

Transition tests cover intermediate opacity, rapid switching, transparent overlay dismissal, immediate input, single active semantics/focus, outgoing ticker suspension, large-to-small intrinsic content and all reduced-motion sources. Integration checks include pressing Play before arrival finishes and preserving the route on Retry. Accessibility checks validate the reached target's full render and semantic bounds within its actual viewport; all 25 tile sizes/non-overlap and global label checks remain.

The rebuilt browser preview was checked at phone and landscape tablet sizes for Retry, mode changes and panel open/close, preserving the existing 25-turn Halo route. Captures: gameplay (local review artifact: `shared-header-gameplay-0.4.4.jpg`), Daily (local review artifact: `shared-header-daily-0.4.4.jpg`), tablet (local review artifact: `shared-header-tablet-0.4.4.jpg`). Physical-device frame pacing remains to be assessed on actual hardware. Nothing has been published.
