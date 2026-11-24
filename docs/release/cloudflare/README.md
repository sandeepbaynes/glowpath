# Deploy to Cloudflare Pages

The Pages project is `glowpath`, with [glowpath-38p.pages.dev](https://glowpath-38p.pages.dev/) as its public address. Use a prebuilt Cloudflare ZIP or the generated directory after reviewing the matching source and package. Uploading a prebuilt package requires only a browser and a Cloudflare account; no local Flutter, Blender, Node or AWS installation is needed. The repository contains source and build instructions; generated web files stay out of Git history. See the [0.12.0 release status](../0.12.0.md) for deployment and device verification.

## Deploy from the development Mac

The same Mac can build the game and manage Cloudflare releases. A pinned Wrangler CLI lives in `tools/cloudflare`; no global installation is needed. From the repository root:

```sh
npm ci --prefix tools/cloudflare
npm --prefix tools/cloudflare run login
npm --prefix tools/cloudflare run profiles
npm --prefix tools/cloudflare run projects
```

Login creates an explicit named `sandeepbaynes` profile with account/profile read access and Pages write access. Its credentials are encrypted using a key in macOS Keychain. The scripts select that profile and keychain storage only for their own command; they do not replace Wrangler's default login, activate a directory binding, export global account variables, or modify shell startup files. Other projects keep their normal account selection. Review Cloudflare's authorization page before granting access. It does not request billing or DNS write permissions. Do not place credentials in this public repository.

The named profile is authenticated on the development Mac and `npm --prefix tools/cloudflare run projects` succeeds. `npm --prefix tools/cloudflare run profiles` verifies that `sandeepbaynes` has no bound directories. This profile can serve multiple Pages projects in the same Cloudflare account: reuse `--profile sandeepbaynes` and select the destination with `--project-name`. A separate profile is useful for a different account or different access permissions, not for each project.

Build the upload directory with `python3 tools/package_web.py --target cloudflare --mode public --base-href /`. From the repository root, deploy that directory with:

```sh
npm --prefix tools/cloudflare run wrangler -- pages deploy \
  "$PWD/build/review/glowpath-0.12.0-35-cloudflare-public-root" \
  --project-name glowpath --branch main
```

Wrangler uploads a directory, not the ZIP. The absolute path is deliberate because npm runs the helper from `tools/cloudflare`. If the login can access multiple accounts, set `CLOUDFLARE_ACCOUNT_ID` for that command to the intended account; do not export it globally. An exported `CLOUDFLARE_API_TOKEN` takes precedence over a profile. To force the named login for one command, prefix it with `env -u CLOUDFLARE_API_TOKEN -u CLOUDFLARE_API_KEY -u CLOUDFLARE_EMAIL -u CLOUDFLARE_ACCOUNT_ID`; this leaves the parent shell unchanged. Reuse the existing Pages project for subsequent releases. Use these scoped npm commands instead of plain `wrangler login` or `wrangler logout`, which affect the default profile.

The public build is free and sends no ad requests. Publisher ownership metadata is configured for site review; web ad approval and browser integration remain separate work. Use `--mode preview` for a non-indexed review package without publisher metadata.

## Dashboard upload

For version `0.12.0+35`, the public packager creates these three matching artifacts. Download them from the matching GitHub Release only after they have been attached, or build them locally:

- `glowpath-0.12.0-35-cloudflare-public-root.zip` — the deployable site, with `index.html` directly at its root.
- `glowpath-0.12.0-35-cloudflare-public-root.json` — version, flags, file inventory, web-ad status and SHA-256 hashes.
- `glowpath-0.12.0-35-cloudflare-public-root.sha256` — checksum for the ZIP.

The ZIP has **no live ads**: real ads, purchases and mock transactions are disabled; no leaderboard endpoint is configured. Public mode includes the publisher meta tag, privacy/support pages and indexable headers. Saves, scores and collections are local to each browser/origin. Changing the website address creates a different save origin. No player account or gameplay backend is needed for this build.

## Upload a prebuilt package

1. Download the matching ZIP, JSON and checksum from the repository's Releases page when available, or use the locally generated artifacts. Optional integrity check from their directory: `shasum -a 256 -c glowpath-0.12.0-35-cloudflare-public-root.sha256` (macOS) or `sha256sum -c glowpath-0.12.0-35-cloudflare-public-root.sha256` (Linux). PowerShell can calculate it with `Get-FileHash <zip-file> -Algorithm SHA256`.
2. In Cloudflare, open the existing `glowpath` Pages project and choose **Create a new deployment**. Upload the ZIP containing the generated files, not GitHub's “Source code” archive or the whole repository. No build command or environment variables are required.
3. Deploy to the production branch, then open [glowpath-38p.pages.dev](https://glowpath-38p.pages.dev/).
4. Check first load, phone/tablet layout, solving a route, wormhole entry/exit, timeout/Retry, cargo/achievements, pause on backgrounding, and reload with saved progress. Hints/skips must not display real ad or payment prompts. These are deployment checks, not a substitute for physical-device review.

Cloudflare accepts ZIPs through the dashboard; the current limits are 1,000 files and 25 MiB **per asset**. Packaging validates both. A Direct Upload project cannot later be converted to Git integration; automatic deployments would use a new project. [Cloudflare Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/).

The bundled `_headers` asks browsers to revalidate on refresh. Public mode permits indexing; preview and review modes prevent it. No credentials are included. Hash navigation needs no route rewrite. Keep the `/` base path for the Pages root. [Cloudflare headers](https://developers.cloudflare.com/pages/configuration/headers/).

## Build from source

From the repository root after the final version and source changes:

```sh
flutter pub get
python3 -m unittest discover -s tools -p 'test_package_web.py'
python3 tools/package_web.py --target cloudflare --mode public --base-href /
```

The script writes a fresh directory, ZIP, JSON and checksum under `build/review/`. It validates the compiled version, explicit service flags, local CanvasKit/fonts, hashed bootstrap/game references, upload limits and all archived file hashes. It neither signs in nor publishes. Rebuilding the same version replaces only that generated package. Attach the resulting ZIP/JSON/SHA256 files to the version's GitHub Release after committing the matching source.

Verify a downloaded package without Flutter:

```sh
python3 tools/package_web.py --verify-archive /path/to/glowpath-0.12.0-35-cloudflare-public-root.zip
```

For a generic static host under a subdirectory, rebuild with `--target static --base-href /glowpath/ --mode preview`; serve it at that exact path. Do not relocate the Cloudflare root build into a subfolder. Hosting approval does not activate web ads: the H5 adapter, consent, publisher/site configuration and rewarded-ad verification remain separate work in [web release preparation](../../WEB_RELEASE.md).

The repository excludes local screenshots, retired Blender worlds/cinematics, caches, native signing material and generated deploy trees. Runtime artwork is drawn by Flutter; required fonts and licenses remain in source. Renderer scripts are included so archival artwork can be recreated.
