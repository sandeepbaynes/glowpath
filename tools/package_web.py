#!/usr/bin/env python3
"""Build and verify a portable static bundle; never publish or contact accounts."""

import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
CLOUDFLARE_MAX_FILES = 1000
CLOUDFLARE_MAX_ASSET_BYTES = 25 * 1024 * 1024


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def check(condition, message):
    if not condition:
        raise ValueError(message)


def build_command(flutter, destination, base_href, mode):
    return [
        flutter, "build", "web", "--release", "--no-web-resources-cdn",
        "--pwa-strategy=none", f"--base-href={base_href}",
        f"--output={destination}",
        f"--dart-define=MOCK_SERVICES={'true' if mode == 'review' else 'false'}",
        "--dart-define=ENABLE_ADS=false", "--dart-define=ENABLE_PURCHASES=false",
        "--dart-define=LEADERBOARD_URL=",
    ]


def fingerprint_scripts(destination):
    """Fresh executable URLs prevent an old browser cache hiding a new build."""
    entrypoint = destination / "main.dart.js"
    entry_name = f"main.{sha256(entrypoint.read_bytes())[:12]}.dart.js"
    entrypoint.rename(destination / entry_name)
    bootstrap = destination / "flutter_bootstrap.js"
    bootstrap_text = bootstrap.read_text().replace('"main.dart.js"', f'"{entry_name}"')
    bootstrap_name = f"flutter_bootstrap.{sha256(bootstrap_text.encode())[:12]}.js"
    (destination / bootstrap_name).write_text(bootstrap_text)
    bootstrap.unlink()
    index = destination / "index.html"
    index.write_text(index.read_text().replace('src="flutter_bootstrap.js"',
                                              f'src="{bootstrap_name}"'))


def validate_bundle(files, version, mode, base_href, target):
    """Validate actual packaged bytes, including root/subpath and local fonts."""
    check(re.fullmatch(r"/(?:[A-Za-z0-9_-]+/)*", base_href), "Invalid base href")
    check(target in ("static", "cloudflare"), "Unknown deployment target")
    check(mode in ("review", "preview"), "Unknown service mode")
    for name in files:
        path = pathlib.PurePosixPath(name)
        check(not path.is_absolute() and ".." not in path.parts,
              f"Unsafe archive path: {name}")
    for required in ("index.html", "version.json", "manifest.json",
                     "glowpath-build.json", "assets/FontManifest.json",
                     "canvaskit/canvaskit.js", "canvaskit/canvaskit.wasm"):
        check(required in files, f"Missing runtime asset: {required}")
    index = files["index.html"].decode()
    check(f'<base href="{base_href}">' in index, "HTML base href does not match package")
    scripts = re.findall(r'<script\b[^>]*\bsrc=[\"\']([^\"\']+)', index)
    check(len(scripts) == 1 and re.fullmatch(r"flutter_bootstrap\.[0-9a-f]{12}\.js", scripts[0]),
          "Expected one local content-hashed bootstrap script")
    check(scripts[0] in files, "Missing bootstrap script")
    bootstrap = files[scripts[0]].decode()
    config = re.search(r"_flutter\.buildConfig\s*=\s*(\{.*?\});", bootstrap, re.S)
    check(config is not None, "Missing Flutter runtime configuration")
    config = json.loads(config[1])
    check(config.get("useLocalCanvasKit") is True, "CanvasKit must be self-hosted")
    entries = [item["mainJsPath"] for item in config.get("builds", []) if "mainJsPath" in item]
    check(len(entries) == 1 and entries[0] in files, "Missing or ambiguous game entrypoint")
    check(re.fullmatch(r"main\.[0-9a-f]{12}\.dart\.js", entries[0]),
          "Game script must be content-hashed")
    check(sum(bool(re.fullmatch(r"main\..*\.dart\.js", name)) for name in files) == 1,
          "Stale game scripts found in package")
    check(sum(bool(re.fullmatch(r"flutter_bootstrap\..*\.js", name)) for name in files) == 1,
          "Stale bootstrap scripts found in package")
    check(not files.get("flutter_service_worker.js", b""), "Active service worker is not supported")
    actual_version = json.loads(files["version.json"])
    check(f"{actual_version['version']}+{actual_version['build_number']}" == version,
          "Compiled version does not match package version")
    metadata = json.loads(files["glowpath-build.json"])
    expected_flags = {"MOCK_SERVICES": mode == "review", "ENABLE_ADS": False,
                      "ENABLE_PURCHASES": False, "LEADERBOARD_URL": ""}
    check(metadata == {"version": version, "mode": mode, "baseHref": base_href,
                       "target": target, "buildFlags": expected_flags},
          "Packaged build metadata does not match release configuration")
    for font in json.loads(files["assets/FontManifest.json"]):
        for asset in font["fonts"]:
            check(f"assets/{asset['asset']}" in files, f"Missing font: {asset['asset']}")
    for icon in json.loads(files["manifest.json"]).get("icons", []):
        check(icon["src"] in files, f"Missing app icon: {icon['src']}")
    check("assets/assets/fonts/Manrope-VariableFont_wght.ttf" in files,
          "Missing local splash font")
    if target == "cloudflare":
        check(base_href == "/", "Cloudflare Direct Upload requires this package's root build")
        check(len(files) <= CLOUDFLARE_MAX_FILES, "Cloudflare dashboard file limit exceeded")
        check(max(map(len, files.values())) <= CLOUDFLARE_MAX_ASSET_BYTES,
              "Cloudflare 25 MiB asset limit exceeded")
        check(b"Cache-Control: no-cache" in files.get("_headers", b""),
              "Missing Cloudflare revalidation headers")
        check(b"X-Robots-Tag: noindex" in files.get("_headers", b""),
              "Preview should not be indexed")


def verify_archive(archive, manifest_path=None):
    manifest_path = manifest_path or archive.with_suffix(".json")
    manifest = json.loads(manifest_path.read_text())
    check(sha256(archive.read_bytes()) == manifest["sha256"], "Archive SHA-256 mismatch")
    with zipfile.ZipFile(archive) as bundle:
        check(len(bundle.namelist()) == len(set(bundle.namelist())), "Duplicate archive entries")
        files = {item.filename: bundle.read(item) for item in bundle.infolist() if not item.is_dir()}
    check({name: sha256(data) for name, data in files.items()} == manifest["fileHashes"],
          "Packaged file inventory/hash mismatch")
    validate_bundle(files, manifest["version"], manifest["mode"],
                    manifest["baseHref"], manifest["target"])
    return manifest


def package(root, flutter, version, base_href, mode, target):
    slug = base_href.strip("/").replace("/", "-") or "root"
    label = "cloudflare" if target == "cloudflare" else "web"
    name = f"glowpath-{version.replace('+', '-')}-{label}-{mode}-{slug}"
    output = root / "build" / "review"
    output.mkdir(parents=True, exist_ok=True)
    destination = output / name
    archive = output / f"{name}.zip"
    flags = {"MOCK_SERVICES": mode == "review", "ENABLE_ADS": False,
             "ENABLE_PURCHASES": False, "LEADERBOARD_URL": ""}
    metadata = {"version": version, "mode": mode, "baseHref": base_href,
                "target": target, "buildFlags": flags}
    # Flutter retains unknown hashed files in reused output directories. Build
    # from an empty staging area so every ZIP contains exactly one generation.
    with tempfile.TemporaryDirectory(prefix=".web-package-", dir=output) as staging:
        staging = pathlib.Path(staging)
        subprocess.run(build_command(flutter, staging, base_href, mode), cwd=root, check=True)
        fingerprint_scripts(staging)
        (staging / ".nojekyll").touch()
        (staging / "glowpath-build.json").write_text(json.dumps(metadata, indent=2) + "\n")
        if target == "cloudflare":
            shutil.copyfile(root / "docs/release/cloudflare/_headers", staging / "_headers")
        files = {str(path.relative_to(staging)): path.read_bytes()
                 for path in sorted(staging.rglob("*")) if path.is_file()}
        validate_bundle(files, version, mode, base_href, target)
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for name, data in files.items():
                bundle.writestr(name, data)
        # Only replace this script's generated output, after validation succeeds.
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(staging, destination)
    manifest = {
        "schemaVersion": 2, **metadata, "archive": archive.name,
        "sha256": sha256(archive.read_bytes()), "files": len(files),
        "uncompressedBytes": sum(map(len, files.values())),
        "largestAssetBytes": max(map(len, files.values())),
        "fileHashes": {name: sha256(data) for name, data in files.items()},
        "selfHostedCanvasKit": True, "liveAds": False,
        "livePurchases": False, "published": False,
    }
    manifest_path = archive.with_suffix(".json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    checksum_path = archive.with_suffix(".sha256")
    checksum_path.write_text(f"{manifest['sha256']}  {archive.name}\n")
    verify_archive(archive, manifest_path)
    return {"directory": str(destination), "archive": str(archive),
            "manifest": str(manifest_path), "checksum": str(checksum_path)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-href", default="/", help="/ or /repository-name/")
    parser.add_argument("--mode", choices=("review", "preview"), default="review",
                        help="review: labelled local mocks; preview: free, no live services")
    parser.add_argument("--target", choices=("static", "cloudflare"), default="static")
    parser.add_argument("--verify-archive", type=pathlib.Path,
                        help="Verify a ZIP and its sibling JSON without Flutter or account access")
    args = parser.parse_args()
    try:
        if args.verify_archive:
            manifest = verify_archive(args.verify_archive)
            print(f"Verified {manifest['archive']} ({manifest['files']} files, {manifest['version']})")
            return
        check(re.fullmatch(r"/(?:[A-Za-z0-9_-]+/)*", args.base_href),
              "base-href must be / or a slash-terminated path such as /glowpath/")
        check(args.target != "cloudflare" or args.base_href == "/",
              "Use --base-href / for the Cloudflare root host")
        flutter = shutil.which("flutter")
        check(flutter is not None, "Flutter must be installed and available on PATH")
        version = re.search(r"^version:\s*(\S+)", (ROOT / "pubspec.yaml").read_text(), re.M)[1]
        print(json.dumps(package(ROOT, flutter, version, args.base_href, args.mode, args.target), indent=2))
    except (ValueError, OSError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Package validation failed: {error}\n")


if __name__ == "__main__":
    main()
