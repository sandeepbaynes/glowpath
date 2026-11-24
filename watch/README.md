# Glowpath watch preview

A small native SwiftUI watchOS prototype for simulator playtesting. This target is deliberately separate from the Flutter phone, tablet and web app. Flutter does not ship a watchOS target.

The preview has a 3×3 routing board, three stars, five route shapes with deterministic rotated starts, a 30-second timer that begins with the first move, hints, retry, next-flight progression and a local personal best. Tapping a tile turns its path. Cyan marks the left-side start; the gold circle marks the right-side finish. Complete a connected route through all three stars before launch.

The clock pauses while help is open or the app is inactive. Retry resets the timer and turn count while keeping your tile arrangement and any hint penalty. A hint aligns one route tile; using hints applies a 60-point flight-score penalty that lasts until the next flight. Scores are local to this watch simulator; they do not sync with the phone game. This is a freely playable preview with no ads, purchases, accounts or network calls.

The watch edition is **not yet a production release**. Full Voyage worlds, collections, Daily/Weekly challenges, phone handoff, WatchConnectivity sync and store assets are not implemented here. Physical-watch accessibility, haptics, battery and performance still need device review. The five route shapes repeat with varied starts; they are not the phone game's full level catalogue.

## Build

Requires Xcode with the watchOS platform SDK. A simulator runtime is needed to install and play, but not for the generic build:

```sh
xcodebuild \
  -project watch/GlowpathWatch.xcodeproj \
  -scheme GlowpathWatch \
  -sdk watchsimulator \
  -configuration Debug \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath build/watch-preview \
  CODE_SIGNING_ALLOWED=NO build
```

The application is `build/watch-preview/Build/Products/Debug-watchsimulator/GlowpathWatch.app`, bundle identifier `app.glowpath.watchpreview`. The deployment target is watchOS 10; current build verification uses the installed watchOS 27.2 SDK. No signing team is embedded.

After creating and booting an Apple Watch simulator:

```sh
xcrun simctl install WATCH_UDID build/watch-preview/Build/Products/Debug-watchsimulator/GlowpathWatch.app
xcrun simctl launch WATCH_UDID app.glowpath.watchpreview
```

Use an unlocked booted simulator. Do not uninstall to update: installing in place retains preview progress.

## Playtest

1. Read the short first-flight briefing, then tap **Let's fly**. The timer stays at 30 until the first tile or hint.
2. Rotate the cyan-start tile until the route lights up, then follow it through three stars to the gold finish.
3. Try a hint, complete a route, then choose **Next flight**. Compare score and local best.
4. Use a hint, let time expire, then choose **Retry**. The timer and turn count reset, while the route and 60-point hint penalty remain.
5. Tap the **Route** heading for help, or background the watch during play. Return and verify time was paused.
6. Check the smaller 40 mm screen and enlarged text. Record any clipped content, hard-to-tap tiles or confusing endpoints before this grows into a full edition.
