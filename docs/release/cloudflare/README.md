# Deploy to Cloudflare Pages

Use the **prebuilt Cloudflare ZIP attached to the repository's GitHub Release**. Uploading a prebuilt package requires only a browser and a Cloudflare account; no local Flutter, Blender, Node or AWS installation is needed. The repository contains source and build instructions; generated web files stay in release assets so each code change does not add another large binary tree to Git history.

## Deploy from the development Mac

The same Mac can build the game and manage Cloudflare releases. A pinned Wrangler CLI lives in `tools/cloudflare`; no global installation is needed. From the repository root:

```sh
npm ci --prefix tools/cloudflare
npm --prefix tools/cloudflare run login
npm --prefix tools/cloudflare run whoami
npm --prefix tools/cloudflare run projects
```

Login creates an explicit named `glowpath` profile with account/profile read access and Pages write access. Its credentials are encrypted using a key in macOS Keychain. The scripts select that profile and keychain storage only for their own command; they do not replace Wrangler's default login, activate a directory binding, export global account variables, or modify shell startup files. Other projects keep their normal account selection. Review Cloudflare's authorization page before granting access. It does not request billing or DNS write permissions. Do not place credentials in this public repository.

Build the verified upload directory with `python3 tools/package_web.py --target cloudflare --mode preview --base-href /`. Use `npm --prefix tools/cloudflare run wrangler -- pages deploy`, passing the generated directory as an absolute path and the intended `--project-name`. Wrangler uploads a directory, not the ZIP. If the login can access multiple accounts, set `CLOUDFLARE_ACCOUNT_ID` for that command to the intended account; do not export it globally. Create a Pages project only if it does not already exist; subsequent releases should update that project. Use these scoped npm commands instead of plain `wrangler login` or `wrangler logout`, which affect the default profile.

The first hosted build remains a free preview with ads off. Advertising requires the separate browser integration described below.

## Dashboard upload

For version `0.11.4+34`, download these three matching release assets when attached to the release:

- `glowpath-0.11.4-34-cloudflare-preview-root.zip` — the deployable site, with `index.html` directly at its root.
- `glowpath-0.11.4-34-cloudflare-preview-root.json` — version, flags, file inventory and SHA-256 hashes.
- `glowpath-0.11.4-34-cloudflare-preview-root.sha256` — checksum for the ZIP.

The ZIP is an **ad-free preview**, not a monetized release: real ads, purchases and mock transactions are disabled; no leaderboard endpoint is configured. Saves, scores and collections are local to each browser/origin. Moving to a custom domain creates a different save origin. No cloud backend is needed for this build.

## Upload a prebuilt package

1. Download the matching ZIP, JSON and checksum from the repository's Releases page. Optional integrity check from their download directory: `shasum -a 256 -c glowpath-0.11.4-34-cloudflare-preview-root.sha256` (macOS) or `sha256sum -c glowpath-0.11.4-34-cloudflare-preview-root.sha256` (Linux). PowerShell can calculate it with `Get-FileHash <zip-file> -Algorithm SHA256`.
2. In Cloudflare, open **Workers & Pages → Create application**, choose the Pages **Drag and drop** / **Direct Upload** flow, and name the project. Upload the **ZIP**, not GitHub's “Source code” archive and not the whole repository. No build command or environment variables are required.
3. Deploy, then open the resulting `https://<project>.pages.dev/` address. For subsequent releases, use the existing project's **Create a new deployment** action.
4. Check first load, phone/tablet layout, solving a route, wormhole entry/exit, timeout/Retry, cargo/achievements, pause on backgrounding, and reload with saved progress. Hints/skips must not display real ad or payment prompts. These are deployment checks, not a substitute for physical-device review.

Cloudflare accepts ZIPs through the dashboard; the current limits are 1,000 files and 25 MiB **per asset**. Packaging validates both. A Direct Upload project cannot later be converted to Git integration; automatic deployments would use a new project. [Cloudflare Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/).

The bundled `_headers` asks browsers to revalidate on refresh and prevents search indexing during preview. No credentials are included. Hash navigation needs no route rewrite. Keep the `/` base path on `pages.dev` or a custom-domain root. [Cloudflare headers](https://developers.cloudflare.com/pages/configuration/headers/).

## Build from source

From the repository root after the final version and source changes:

```sh
flutter pub get
python3 -m unittest discover -s tools -p 'test_package_web.py'
python3 tools/package_web.py --target cloudflare --mode preview --base-href /
```

The script writes a fresh directory, ZIP, JSON and checksum under `build/review/`. It validates the compiled version, explicit service flags, local CanvasKit/fonts, hashed bootstrap/game references, upload limits and all archived file hashes. It neither signs in nor publishes. Rebuilding the same version replaces only that generated package. Attach the resulting ZIP/JSON/SHA256 files to the version's GitHub Release after committing the matching source.

Verify a downloaded package without Flutter:

```sh
python3 tools/package_web.py --verify-archive /path/to/glowpath-0.11.4-34-cloudflare-preview-root.zip
```

For a generic static host under a subdirectory, rebuild with `--target static --base-href /glowpath/ --mode preview`; serve it at that exact path. Do not relocate the Cloudflare root build into a subfolder. Hosting approval does not activate web ads: the H5 adapter, consent, publisher/site configuration and rewarded-ad verification remain separate work in [web release preparation](../../WEB_RELEASE.md).

The repository excludes local screenshots, retired Blender worlds/cinematics, caches, native signing material and generated deploy trees. Runtime artwork is drawn by Flutter; required fonts and licenses remain in source. Renderer scripts are included so archival artwork can be recreated.
