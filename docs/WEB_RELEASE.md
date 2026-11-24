# Web release preparation

The web and iOS apps share the Flutter game, artwork, progression and local save format. Web progress currently belongs to that browser and origin; it does not sync to iOS or between domains. Browser data deletion removes local progress. Shared identity and score submission remain separate release work.

## Static bundles

Run `python3 tools/package_web.py --base-href / --mode review` for an account-free review build. It includes labelled mock services, self-hosted CanvasKit and fonts, and no ad requests or real purchases. The script writes a static directory, ZIP and SHA-256 manifest under `build/review/`. It never publishes. Bundles use content-hashed game/bootstrap script names and disable Flutter’s deprecated generated service worker so an earlier review does not keep serving stale game code after a refresh. Offline installation is not provided by this packaging step.

For Cloudflare Pages Direct Upload, run `python3 tools/package_web.py --target cloudflare --base-href / --mode preview`. This produces the root-hosted preview with Cloudflare headers and upload-limit validation. Preview mode is free and disables mock purchases as well as real services. See the [Cloudflare upload guide](release/cloudflare/README.md).

For another static host under a project path, use `--target static --base-href /REPOSITORY/ --mode preview`. Build for the actual destination path; do not move a root build under a repository path without rebuilding. Flutter uses its default hash navigation, so a server-side route rewrite is not needed.

Serve the files over HTTP locally (not `file://`). A subpath build must be served from that same path. Test a fresh load, a reload with saved progress, drag routing, galleries, background/foreground timer behavior and mobile Safari before release. A browser resize audit is not physical Safari testing.

## Hosting decision

GitHub Pages explicitly disallows use as free hosting to run an online business. An ad-funded commercial game should not assume Pages is a permitted production host. GitHub can still hold source and a noncommercial review preview. See [GitHub Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).

The web preview is packaged for Cloudflare Pages. The documented free-tier limits include 500 builds/month, 20,000 files and assets up to 25 MiB each; dashboard Direct Upload has its own 1,000-file limit. The packager checks the stricter upload limit and writes asset sizes into the manifest. Publishing is a separate step using your Cloudflare account. Review current limits before deployment. See [Cloudflare Pages limits](https://developers.cloudflare.com/pages/platform/limits/) and [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/).

## Web ads: activation still pending

AdMob is the native mobile integration; its Flutter plugin does not serve browser ads. Google provides [AdSense H5 Games Ads](https://support.google.com/adsense/answer/9959170) through the [Ad Placement API](https://developers.google.com/ad-placement). H5 program approval, the correct publisher account/site, consent setup and domain-specific checks must precede activation. Merely putting an AdSense banner beside the game does not implement rewarded hints.

The first web placement should be an explicit rewarded hint or skip, opened from Flight support while the puzzle clock is paused. Preserve the board on cancellation, blocked scripts and no-fill. Grant a reward only from the provider's earned-reward callback, once per ad; never from a close callback or timeout. Later interstitials belong at completed-run boundaries, never across the puzzle or underneath controls. Frequency and availability are controlled jointly by the game and provider. The default and packaged builds do not load an ad SDK.

Before enabling ads: implement the H5 adapter with provider callbacks and consent, exercise provider test ads, verify no-fill/cancel/reward flows, configure the real site and any required `ads.txt`, and measure page weight/frame timing. Browser ad-free checkout and cross-platform entitlements are not implemented. Current mock balances are isolated from real entitlement storage.

Hosting references checked during the November 2026 release preparation. No live advertising adapter or paid entitlement service is included in the preview.
