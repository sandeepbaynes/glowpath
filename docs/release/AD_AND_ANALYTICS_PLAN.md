# Ad and measurement plan

Status: native ad integration uses the eight real AdMob units under `sandeep.baynes@gmail.com`, gated by build configuration and consent. Default local builds leave ads disabled. Owner-device review enables test advertising using registered test devices, with demo-unit fallback when review mode has no test-device IDs. Both AdMob app records need store listing and AdMob review before normal serving. No gameplay events are uploaded. The public website has the verified publisher ownership metadata but serves no ads while AdSense Content/H5 approval and browser integration remain pending.

## Native placements

| Surface | Placement | Trigger and safeguard |
| --- | --- | --- |
| Voyage, Daily, Weekly, map, collections, settings | Small anchored banner | Reserve a dedicated bottom slot before loading; never cover game controls, safe areas, fold hinges, failure Retry, or a board. Hide it where the slot would cause crowding or accidental taps. |
| Voyage result | Interstitial | Only after the success animation and reward are complete, before the next Play. No ad on the first three clears. Eligible after three more clears **or** three minutes of active play since the last shown ad, whichever comes first; at least two minutes must also pass between shown ads. Offer only when a player has returned for another round or shown comparable engagement. No ad on a failed attempt, during a puzzle, on app open, or during a briefing. |
| Flight supplies | Opt-in rewarded | Watch for three hints or one skip. Free initial supplies and Retry remain available. The exact reward appears before the ad. No reward on cancellation or failure to show. |
| Post-win bonus | Opt-in rewarded | Candidate experiment: additional earned coins after a win. Keep the base reward without watching. Do not double stars, rare objects, achievements, or leaderboard points. |

The provider controls interstitial duration; the app cannot guarantee a 30-second creative. Do not call it a “30-second ad” in the UI. If an interstitial is unavailable, continue straight to Play. A watchOS edition remains ad free.

`AdPacing` connects to the interstitial provider at the next-level transition after successful Voyage play. `recordImpression` runs only after `onAdShowedFullScreenContent`; no-fill and cancelled offers do not count. The banner reserves space and is omitted where compact layouts, large accessibility text, fold hinges or cinematics make it unsuitable. `FlightSupport` selects separate hint/skip rewarded units. All formats share the UMP consent gate and non-personalized ad requests, with privacy-choice reopening exposed when required. Provider message configuration and device review still need verification before live distribution. Browser ads require an approved H5 Games account and a separate adapter.

### AdMob unit inventory

These public account identifiers are included in the native configuration. They do not enable advertising by themselves. Keep owner review on test advertising until consent, store metadata, placement QA and provider review are complete.

| Format / intended use | iOS unit | Android unit |
| --- | --- | --- |
| Banner / bottom safe-area slot | `ca-app-pub-3704137344359613/4093674041` | `ca-app-pub-3704137344359613/6263581357` |
| Interstitial / Voyage level break | `ca-app-pub-3704137344359613/1248018851` | `ca-app-pub-3704137344359613/6200962639` |
| Rewarded / three hints | `ca-app-pub-3704137344359613/6392534329` | `ca-app-pub-3704137344359613/1917655581` |
| Rewarded / one skip | `ca-app-pub-3704137344359613/5079452654` | `ca-app-pub-3704137344359613/7884298139` |

AdMob app IDs: iOS `ca-app-pub-3704137344359613~1566748905`; Android `ca-app-pub-3704137344359613~5449706481`. These are present in the native app metadata. The Android record was created as an unlisted app. Verify both against their eventual store listings before live distribution.

Native build configuration:

| Build | Defines and behavior |
| --- | --- |
| Default local / web | Omit `ENABLE_ADS` or set it to `false`. No ad requests. Public web packaging always sets it to `false`. |
| Owner review | `ENABLE_ADS=true`, `ADMOB_REVIEW_MODE=true`, `MOCK_SERVICES=false`, and `ADMOB_TEST_DEVICE_IDS` containing the SDK's comma-separated test-device hashes. Real unit IDs are used with test-device requests. Keep device hashes in local build inputs, outside the public repository. |
| Review bootstrap | The same review flags with an empty test-device list select Google's demo units until the device hashes are registered. Simulators are treated as test devices by the SDK. |
| Native live release | `ENABLE_ADS=true`, `MOCK_SERVICES=false`, with review mode off after the release gates pass. Real unit IDs are supplied by the registry in `lib/services/native_ads.dart`. |

The previous per-unit ID build defines are no longer read. Purchases remain hard-disabled independently of these flags. Ad SDK initialization waits for the consent decision; failure or unavailable consent leaves the game playable without an ad.

## Public web advertising status

The verified web publisher ID is `ca-pub-3704137344359613`. The account's active product is currently AdMob. AdSense enrollment is blocked at Google's human-verification step; site review has not been successfully submitted, and eligibility of the Pages address remains unverified. AdSense Content and H5 Games approval remain pending. Public packaging adds the ownership meta tag and privacy/support pages but includes no advertising provider script or browser ad requests. Its manifest explicitly records `liveAds: false`. Native AdMob units cannot serve browser placements. See [web release preparation](../WEB_RELEASE.md) for approval, `ads.txt`, consent and browser integration work.

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

Store and policy checks before live distribution: verify the published privacy/support pages and store data declarations; configure UMP messages and test consent states; link store listings and complete AdMob review; verify `app-ads.txt`; inspect device-safe banner positioning; test reward callback, no-fill, close, backgrounding, fold layouts and screen readers. Web H5 approval, `ads.txt` and its consent path are separate.
