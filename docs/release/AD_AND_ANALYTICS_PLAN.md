# Ad and measurement plan

Status: design, local pacing code and an on-device event journal wired to session, level, failure, retry, hint and skip transitions. Eight AdMob units now exist under `sandeep.baynes@gmail.com`, but the shipped app still uses Google test IDs and ads remain disabled. No player events are uploaded. Both AdMob app records are unlisted and need store listing and AdMob review before normal serving. Web ads require a separate AdSense H5 Games integration.

## Native placements

| Surface | Placement | Trigger and safeguard |
| --- | --- | --- |
| Voyage, Daily, Weekly, map, collections, settings | Small anchored banner | Reserve a dedicated bottom slot before loading; never cover game controls, safe areas, fold hinges, failure Retry, or a board. Hide it where the slot would cause crowding or accidental taps. |
| Voyage result | Interstitial | Only after the success animation and reward are complete, before the next Play. No ad on the first three clears. Eligible after three more clears **or** three minutes of active play since the last shown ad, whichever comes first; at least two minutes must also pass between shown ads. Offer only when a player has returned for another round or shown comparable engagement. No ad on a failed attempt, during a puzzle, on app open, or during a briefing. |
| Flight supplies | Opt-in rewarded | Watch for three hints or one skip. Free initial supplies and Retry remain available. The exact reward appears before the ad. No reward on cancellation or failure to show. |
| Post-win bonus | Opt-in rewarded | Candidate experiment: additional earned coins after a win. Keep the base reward without watching. Do not double stars, rare objects, achievements, or leaderboard points. |

The provider controls interstitial duration; the app cannot guarantee a 30-second creative. Do not call it a “30-second ad” in the UI. If an interstitial is unavailable, continue straight to Play. A watchOS edition remains ad free.

`AdPacing` currently records eligibility; it is not connected to the ad provider yet. Its `recordImpression` must run only after `onAdShowedFullScreenContent`; no-fill and cancelled offers must not count. The current `FlightSupport` adapter selects separate hint/skip rewarded units but defaults to Google's test IDs. Production app IDs, consent configuration, banners and interstitial presentation remain unset. Browser ads require an approved H5 Games account and a separate adapter.

### AdMob unit inventory

These are account identifiers, not active app configuration. Keep all preview builds on test ads until consent, store metadata, placement QA and policy review are complete.

| Format / intended use | iOS unit | Android unit |
| --- | --- | --- |
| Banner / bottom safe-area slot | `ca-app-pub-3704137344359613/4093674041` | `ca-app-pub-3704137344359613/6263581357` |
| Interstitial / Voyage level break | `ca-app-pub-3704137344359613/1248018851` | `ca-app-pub-3704137344359613/6200962639` |
| Rewarded / three hints | `ca-app-pub-3704137344359613/6392534329` | `ca-app-pub-3704137344359613/1917655581` |
| Rewarded / one skip | `ca-app-pub-3704137344359613/5079452654` | `ca-app-pub-3704137344359613/7884298139` |

AdMob app IDs: iOS `ca-app-pub-3704137344359613~1566748905`; Android `ca-app-pub-3704137344359613~5449706481`. The Android record was created as an unlisted app. Verify both against their eventual store listings before enabling live ads.

When the release gates pass, select the rewarded units via `IOS_HINT_REWARDED_AD`, `IOS_SKIP_REWARDED_AD`, `ANDROID_HINT_REWARDED_AD` and `ANDROID_SKIP_REWARDED_AD` build defines. Build previews without these defines and without `ENABLE_ADS`; that keeps Google test IDs and all ads off. The app ID metadata also needs to change from Google's sample IDs for a live release.

## First-party measurement

The current journal stores the last 200 allowlisted coarse events on the device and exposes a clear operation. It has no install ID, tracking identifier or upload path. Before adding a hosted analytics endpoint, use a random install ID and rotating session ID, with no device fingerprint, contact data, advertising ID or precise location. Do not use an individual player's puzzle path to target ads. Disclose any production upload and provide a privacy control; honor consent requirements in the regions served.

Record small, versioned events with UTC time and coarse properties:

| Event | Properties | Decision it supports |
| --- | --- | --- |
| `session_start`, `session_end` | platform class, app version, session length bucket | Return rate and session length |
| `level_start`, `level_complete`, `level_fail`, `level_retry`, `level_skip` | mode, planet/level, difficulty band, time bucket, assisted flag | Difficulty, completion and abandonment |
| `hint_offer`, `hint_used` | level, free/earned/ad source | Whether hints recover stalled players |
| `ad_eligible`, `ad_request`, `ad_impression`, `ad_closed`, `ad_reward`, `ad_no_fill` | placement, result, elapsed bucket | Fill, revenue opportunity and ad friction |
| `screen_open`, `screen_exit` | screen ID, duration bucket | Screens associated with exits |

The server should accept only allowlisted event names and coarse fields, limit batch size and rate, reject arbitrary identifiers, and expire raw events after 30 days. Aggregate by cohort and level, then delete raw records; retain derived daily aggregates longer. The initial decision metric is next-level-start rate and D1/D7 return rate for exposed versus unexposed players, alongside ad impressions per daily active user, revenue per daily active user and crash-free sessions. Because engagement gates change who sees ads, exposure comparisons are observational; use a randomized holdout before claiming ads caused churn or retention changes.

Initial experiment: 10% ad-free holdout, 45% rewarded only, 45% rewarded plus paced interstitial. Keep banners separately randomized because an always-visible banner affects every screen. Require meaningful sample size and review both revenue and next-level-start/D1 retention before raising frequency. Pause a placement if accidental taps, complaints, or retention worsen materially.

Store and policy checks before activation: finalize privacy policy/support URL and store data declarations; configure UMP messages and test consent states; connect the existing production units behind a release flag; verify `app-ads.txt`; inspect device-safe banner positioning; test reward callback, no-fill, close, backgrounding, fold layouts and screen readers. Web H5 approval, `ads.txt` and its consent path are separate.
