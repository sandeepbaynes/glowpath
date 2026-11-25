# Glowpath watch preview

A small native SwiftUI watchOS prototype for simulator playtesting. This target is deliberately separate from the Flutter phone, tablet and web app. Flutter does not ship a watchOS target.

The preview has a 3×3 routing board, three stars, five route shapes with deterministic rotated starts, a 30-second timer that begins with the first move, hints, retry, next-flight progression and a local personal best. Tapping a tile turns its path. Cyan marks the left-side start; the gold circle marks the right-side finish. Complete a connected route through all three stars before launch.

The clock pauses while help is open or the app is inactive. Retry resets the timer and turn count while keeping your tile arrangement and any hint penalty. A hint aligns one route tile; using hints applies a 60-point flight-score penalty that lasts until the next flight. Scores are local to this watch simulator; they do not sync with the phone game. This is a freely playable preview with no ads, purchases, accounts or network calls.

The watch edition is **not yet a production release**. Full Voyage worlds, collections, Daily/Weekly challenges, phone handoff, WatchConnectivity sync and store assets are not implemented here. Physical-watch accessibility, haptics, battery and performance still need device review. The five route shapes repeat with varied starts; they are not the phone game's full level catalogue.

## Simulator review — 25 November 2026

The native preview builds, installs and launches on the installed watchOS 27.2 runtime. Initial layout review covers Apple Watch SE 3 (40 mm, 324×394 pixels) and Series 12 (46 mm, 416×496 pixels). The smaller watch exposed truncated first-flight instructions; the compact briefing now uses two explicit lines and tighter diagram spacing so START, the three-star objective and FINISH remain visible above the play action.

Gameplay review also found that default scrolling-content safe margins left the 40 mm board only 90 points wide. The non-scrolling game now reserves space directly below the system clock and uses a compact toolbar: the board is 130 points wide, with approximately 41-point tiles, while retaining clear edges. Cyan START and gold FINISH beacons have dark backing to stay visible over the route. The START arrow's path construction was corrected so its filled triangle actually renders.

Interactive review on the 40 mm simulator verified tile rotation, Hint, clock start, timeout, Retry with the arrangement retained, assisted completion (+295 points), and Next flight to Route 02. The 46 mm briefing and gameplay were visually reviewed. Simulator captures are recorded in the [platform review](../docs/platforms/SIMULATOR_REVIEW_2026_11_25.md). This does not verify physical-watch readability, haptics or battery use.

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
