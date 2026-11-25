# Glowpath TV review

A native SwiftUI **tvOS simulator preview**, separate from the Flutter phone/tablet/web game. This gives the installed Apple TV simulator a real playable target for evaluating couch-distance typography, remote focus and a slower clock. It is not the full TV edition or an App Store package.

The preview adapts the existing watch prototype's routing rules: a 3×3 board, five deterministic route shapes, three stars, hints, retry, next flight and local best score. The **90-second** launch clock starts with the first rotation or hint, pauses when inactive, and resumes on return. The board uses the game's dark blue, cyan, gold and broad pipe artwork. Arrow/D-pad navigation selects a tile; Select rotates it. A cyan outline identifies focus. Hint, Undo, Restart and result actions are remote-focusable.

There are no ads, paid features, accounts, analytics or network requests. Saved progress belongs to this preview only; there is no phone sync. Full Voyage planets, the phone's obstacle catalogue, collections, daily/weekly modes, cinematic loss flight and store artwork are not implemented here. Five route shapes repeat with changed orientations. The copied native rule adapter needs cross-platform parity tests before sharing levels or scores with the full game.

## Build and inspect

Requires Xcode and the tvOS platform. The project targets tvOS 17+, with no signing team configured.

```sh
xcodebuild -project tv/GlowpathTV.xcodeproj -scheme GlowpathTV \
  -sdk appletvsimulator -configuration Debug \
  -destination 'generic/platform=tvOS Simulator' \
  -derivedDataPath build/tv-preview CODE_SIGNING_ALLOWED=NO build

xcrun simctl install TV_UDID build/tv-preview/Build/Products/Debug-appletvsimulator/GlowpathTV.app
xcrun simctl launch TV_UDID app.glowpath.tvpreview
```

Use Xcode Simulator's Apple TV Remote for D-pad and Select input. The app opens with focus on START; the timer stays idle until the first move. The **Show a hint** control aligns one tile and applies a score penalty. **Undo** restores the previous tile arrangement without refunding elapsed time. After timeout, **Retry** keeps that arrangement and any hint penalty. **Next flight** starts a fresh route.

Run the preview's actual rule engine checks on the Mac:

```sh
python3 tv/Tests/check_rules.py
```

They check 150 deterministic routes for solvability and star collection, plus paused time, timeout, and retained retry state. The harness compiles the source engine section without copying its implementation and uses an isolated temporary preferences suite. Simulator screenshots are written under the ignored `build/review/platforms/` folder. Physical Siri Remote input, VoiceOver, viewing-distance readability and television overscan still require device testing.

## Simulator review, 25 November 2026

On the tvOS 27.2 Apple TV 1080p simulator, manual remote interaction confirmed D-pad movement between tiles, Select rotation, the timer starting with the first move, timeout followed by Retry, Hint, and Undo. An assisted route completed with **690 points**, and Next flight opened **Route 02**. The native button halo was replaced by the game's cyan focus outline; the reviewed 1920×1080 layout shows no clipped board, text or controls.

The same binary installed and launched on the Apple TV 4K simulator. Its **3840×2160** capture preserves the same composition, focus outline and readable controls without clipping. The process remained running after capture; no crash or app exit was observed during this scaling check. Remote playthrough was performed on the 1080p simulator, while the 4K review checked launch and rendering only.

The focus implementation uses [SwiftUI FocusState](https://developer.apple.com/documentation/swiftui/focusstate) and disables the default focus effect so the game's cyan outline remains the sole highlight.
