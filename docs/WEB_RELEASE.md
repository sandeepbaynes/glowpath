# Web release preparation

The web and iOS apps share the Flutter game, artwork, progression and local save format. Web progress currently belongs to that browser and origin; it does not sync to iOS or between domains. Browser data deletion removes local progress. Shared identity and score submission remain separate release work.

The current product plan is free access on phones, tablets, foldables, the web and a future watch edition. There are no plans for paid downloads, subscriptions, in-app purchases, paywalled levels or currency bought with money; coins are earned through play. The watch edition is planned as a complete, ad-free game playable on its own, with an optional, unobtrusive path to the phone app. Watch gameplay and future earned-reward sync are not implemented.

## Static bundles

Run `python3 tools/package_web.py --base-href / --mode review` for an account-free review build. It includes labelled mock services, self-hosted CanvasKit and fonts, and no ad requests or real purchases. The script writes a static directory, ZIP and SHA-256 manifest under `build/review/`. It never publishes. Bundles use content-hashed game/bootstrap script names and disable Flutter’s deprecated generated service worker so an earlier review does not keep serving stale game code after a refresh. Offline installation is not provided by this packaging step.

For Cloudflare Pages Direct Upload, run `python3 tools/package_web.py --target cloudflare --base-href / --mode preview`. This produces the root-hosted preview with Cloudflare headers and upload-limit validation. Preview mode is free and disables mock purchases as well as real services. See the [Cloudflare upload guide](release/cloudflare/README.md).

For the public website, run `python3 tools/package_web.py --target cloudflare --base-href / --mode public`. This produces an indexable release with the verified publisher ownership meta tag, [privacy page](../web/privacy.html) and [support page](../web/support.html). It still makes **no advertising requests**. The bundle and manifest explicitly record publisher `ca-pub-3704137344359613`, `publisherConfigured: true`, `servingStatus: pending_approval_and_integration` and `liveAds: false`. This mode is intended for the public game and Google's site review, not a claim that advertising has been approved. Preview and review builds retain their existing behavior and do not include the publisher meta tag.

For another static host under a project path, use `--target static --base-href /REPOSITORY/ --mode preview`. Build for the actual destination path; do not move a root build under a repository path without rebuilding. Flutter uses its default hash navigation, so a server-side route rewrite is not needed.

Serve the files over HTTP locally (not `file://`). A subpath build must be served from that same path. Test a fresh load, a reload with saved progress, drag routing, galleries, background/foreground timer behavior and mobile Safari before release. A browser resize audit is not physical Safari testing.

## Hosting decision

GitHub Pages explicitly disallows use as free hosting to run an online business. An ad-funded commercial game should not assume Pages is a permitted production host. GitHub can still hold source and a noncommercial review preview. See [GitHub Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).

The public website uses **https://glowpath-38p.pages.dev/** on Cloudflare Pages. No custom domain has been authorized. Do not attach another domain or change its DNS until the owner explicitly chooses one. The documented free-tier limits include 500 builds/month, 20,000 files and assets up to 25 MiB each; dashboard Direct Upload has its own 1,000-file limit. The packager checks the stricter upload limit and writes asset sizes into the manifest. Publishing is a separate step using the named Cloudflare account. Review current limits before deployment. See [Cloudflare Pages limits](https://developers.cloudflare.com/pages/platform/limits/) and [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/).

Use the Pages address consistently: local progress is tied to that origin and would not automatically move if a different address is chosen later. The public release removes the preview's `X-Robots-Tag: noindex` header but retains cache revalidation and security headers.

## Advertising readiness

The verified Google publisher account is `pub-3704137344359613`. On 24 November 2026, its active product was AdMob; web AdSense and H5 serving were not approved. AdSense enrollment stopped at Google's human-verification check, so the site has not yet been submitted successfully for review. AdMob is the native mobile integration, and its Flutter plugin does not serve browser ads. A native ad unit ID cannot be reused as a website ad placement.

Google supports [site ownership verification with a publisher meta tag](https://support.google.com/adsense/answer/7584263), without an advertising script. Public packaging inserts the actual account's meta tag into `index.html`. The website must be reachable for review, and the AdSense site status must become [Ready before ads can serve](https://support.google.com/adsense/answer/12131223). Check the account interface for the latest status; publishing this bundle does not change the approval status.

**AdSense eligibility for this specific `pages.dev` address is still pending verification.** The publisher meta tag does not establish host eligibility or approval. Keep browser advertising disabled unless Google accepts this exact site and completes its review. This package does not require or authorize domain changes to satisfy advertising requirements.

Google provides [H5 Games Ads](https://support.google.com/adsense/answer/1705831) through the [Ad Placement API](https://developers.google.com/ad-placement). This is a separate application and requires an approved AdSense account. No H5 adapter is included here. Banner or Auto ads alone do not implement rewarded hints. No sample publisher IDs or test ad slots are placed in the public website.

Until web approval and integration are complete, public builds keep `ENABLE_ADS=false` and `ENABLE_PURCHASES=false`; hints and skips remain usable without watching ads. Do not change the native `ENABLE_ADS` flag to true for web: without a web rewarded-ad adapter, that would consume hint/skip balances without a way to replenish them. The public privacy notice describes current behavior: local progress and a bounded local event journal, no backend analytics upload, Cloudflare hosting, no browser advertising, and AdMob in supported mobile builds when enabled. Privacy and support are available from the game’s About page as well as the static pages.

Before enabling web ads:

1. Finish AdSense account/site approval and obtain H5 Games access for in-game advertising. Obtain any required browser placement identifiers from the actual account.
2. Publish the account-provided `ads.txt` configuration for the correct host. Website `ads.txt` and native `app-ads.txt` serve different products. For a subdomain, follow Google's [root-domain/subdomain discovery instructions](https://support.google.com/adsense/answer/9785052); a file at the wrong origin does not verify the site. Do not substitute mobile app IDs for a web publisher configuration.
3. Integrate the browser provider and required consent flow. For personalized ads in the EEA, UK and Switzerland, use a [Google-certified CMP](https://support.google.com/adsense/answer/13554116). Update the privacy notice and expose privacy choices before activation.
4. Pause the puzzle and audio during ads; preserve the board on cancellation, blocked scripts and no-fill. Grant optional rewarded hints/skips only from `adViewed`, once per ad, never from a close callback or timeout. Use completed-level boundaries for interstitials and keep banners clear of controls.
5. Exercise provider test mode, including no-fill, dismissal and earned rewards, and measure page weight/frame timing. Developer devices must use test advertising; they should not create real advertising impressions or clicks to test revenue.

No backend advertising analytics or cross-device identity is enabled by this bundle. Paid checkout and paid entitlements are outside the free-access plan. Current mock balances remain isolated from real entitlement storage.
