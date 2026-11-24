"""Portable-package regressions; no Flutter, account, network or live build needed."""

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import package_web as web


VERSION = "0.11.0+30"


def fixture(base="/", mode="preview", target="cloudflare"):
    entry = b"window.glowpathReady = true;"
    entry_name = f"main.{web.sha256(entry)[:12]}.dart.js"
    bootstrap = ('_flutter.buildConfig = ' + json.dumps({
        "useLocalCanvasKit": True,
        "builds": [{"renderer": "canvaskit", "mainJsPath": entry_name}],
    }) + ';\n_flutter.loader.load();').encode()
    bootstrap_name = f"flutter_bootstrap.{web.sha256(bootstrap)[:12]}.js"
    return {
        "index.html": f'<base href="{base}"><script src="{bootstrap_name}" async></script>'.encode(),
        entry_name: entry,
        bootstrap_name: bootstrap,
        "version.json": b'{"version":"0.11.0","build_number":"30"}',
        "manifest.json": b'{"icons":[{"src":"icons/Icon-192.png"}]}',
        "icons/Icon-192.png": b"icon",
        "canvaskit/canvaskit.js": b"renderer",
        "canvaskit/canvaskit.wasm": b"wasm",
        "assets/FontManifest.json": b'[{"family":"Manrope","fonts":[{"asset":"assets/fonts/Manrope-VariableFont_wght.ttf"}]}]',
        "assets/assets/fonts/Manrope-VariableFont_wght.ttf": b"font",
        "_headers": b"/*\n  Cache-Control: no-cache\n  X-Robots-Tag: noindex\n",
        "glowpath-build.json": json.dumps({
            "version": VERSION, "mode": mode, "baseHref": base, "target": target,
            "buildFlags": {"MOCK_SERVICES": mode == "review", "ENABLE_ADS": False,
                           "ENABLE_PURCHASES": False, "LEADERBOARD_URL": ""},
        }).encode(),
    }


class PackageTests(unittest.TestCase):
    def validate(self, files, base="/", mode="preview", target="cloudflare"):
        web.validate_bundle(files, VERSION, mode, base, target)

    def test_root_and_subpath_packages(self):
        self.validate(fixture())
        self.validate(fixture("/glowpath/", "review", "static"),
                      "/glowpath/", "review", "static")
        with self.assertRaisesRegex(ValueError, "base href"):
            self.validate(fixture(), base="/glowpath/")
        with self.assertRaisesRegex(ValueError, "root build"):
            self.validate(fixture("/glowpath/"), base="/glowpath/")

    def test_real_service_flags_are_explicit_in_build_command(self):
        for mode in ("review", "preview"):
            args = web.build_command("flutter", Path("output"), "/glowpath/", mode)
            for flag in ("--release", "--no-web-resources-cdn", "--base-href=/glowpath/",
                         "--dart-define=ENABLE_ADS=false", "--dart-define=ENABLE_PURCHASES=false",
                         "--dart-define=LEADERBOARD_URL="):
                self.assertIn(flag, args)
            self.assertIn(f"--dart-define=MOCK_SERVICES={'true' if mode == 'review' else 'false'}", args)

    def test_missing_font_icon_renderer_and_script_are_rejected(self):
        for name, message in (("assets/assets/fonts/Manrope-VariableFont_wght.ttf", "Missing font"),
                              ("icons/Icon-192.png", "Missing app icon"),
                              ("canvaskit/canvaskit.wasm", "Missing runtime asset")):
            with self.subTest(name=name):
                files = fixture()
                del files[name]
                with self.assertRaisesRegex(ValueError, message):
                    self.validate(files)
        files = fixture()
        del files[next(name for name in files if name.startswith("main."))]
        with self.assertRaisesRegex(ValueError, "game entrypoint"):
            self.validate(files)

    def test_cdn_runtime_and_external_script_are_rejected(self):
        files = fixture()
        name = next(name for name in files if name.startswith("flutter_bootstrap."))
        files[name] = files[name].replace(b'"useLocalCanvasKit": true', b'"useLocalCanvasKit": false')
        with self.assertRaisesRegex(ValueError, "self-hosted"):
            self.validate(files)
        files = fixture()
        files["index.html"] += b'<script src="https://ads.example/sdk.js"></script>'
        with self.assertRaisesRegex(ValueError, "one local"):
            self.validate(files)

    def test_mismatched_version_and_flags_are_rejected(self):
        files = fixture()
        files["version.json"] = b'{"version":"0.10.7","build_number":"29"}'
        with self.assertRaisesRegex(ValueError, "Compiled version"):
            self.validate(files)
        files = fixture()
        files["glowpath-build.json"] = files["glowpath-build.json"].replace(b'"ENABLE_ADS": false', b'"ENABLE_ADS": true')
        with self.assertRaisesRegex(ValueError, "build metadata"):
            self.validate(files)

    def test_stale_game_service_worker_and_unsafe_path_are_rejected(self):
        for name, data, message in (("main.0123456789ab.dart.js", b"old", "Stale game"),
                                    ("flutter_service_worker.js", b"cache", "service worker"),
                                    ("../private.txt", b"no", "Unsafe archive")):
            with self.subTest(name=name):
                files = fixture()
                files[name] = data
                with self.assertRaisesRegex(ValueError, message):
                    self.validate(files)

    def test_cloudflare_size_and_file_limits(self):
        with patch.object(web, "CLOUDFLARE_MAX_FILES", 5):
            with self.assertRaisesRegex(ValueError, "file limit"):
                self.validate(fixture())
        with patch.object(web, "CLOUDFLARE_MAX_ASSET_BYTES", 20):
            with self.assertRaisesRegex(ValueError, "asset limit"):
                self.validate(fixture())
        files = fixture()
        del files["_headers"]
        with self.assertRaisesRegex(ValueError, "revalidation"):
            self.validate(files)

    def test_archive_hash_and_inventory_are_verified(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "game.zip"
            files = fixture()
            with zipfile.ZipFile(archive, "w") as bundle:
                for name, data in files.items():
                    bundle.writestr(name, data)
            manifest = {"version": VERSION, "mode": "preview", "baseHref": "/",
                        "target": "cloudflare", "sha256": web.sha256(archive.read_bytes()),
                        "fileHashes": {name: web.sha256(data) for name, data in files.items()}}
            manifest_path = archive.with_suffix(".json")
            manifest_path.write_text(json.dumps(manifest))
            self.assertEqual(web.verify_archive(archive)["version"], VERSION)
            manifest["fileHashes"]["index.html"] = "wrong"
            manifest_path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "inventory/hash"):
                web.verify_archive(archive)
            archive.write_bytes(archive.read_bytes() + b"tampered")
            with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                web.verify_archive(archive)

    def test_repackage_cannot_retain_old_hashed_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            headers = root / "docs/release/cloudflare/_headers"
            headers.parent.mkdir(parents=True)
            headers.write_bytes(fixture()["_headers"])
            stale = root / "build/review/glowpath-0.11.0-30-cloudflare-preview-root/old.dart.js"
            stale.parent.mkdir(parents=True)
            stale.write_text("old build")

            def fake_build(command, **kwargs):
                output = Path(next(item.split("=", 1)[1] for item in command if item.startswith("--output=")))
                self.assertFalse(list(output.iterdir()))
                files = fixture()
                entry = next(name for name in files if name.startswith("main."))
                bootstrap = next(name for name in files if name.startswith("flutter_bootstrap."))
                files["main.dart.js"] = files.pop(entry)
                files["flutter_bootstrap.js"] = files.pop(bootstrap).replace(entry.encode(), b"main.dart.js")
                files["index.html"] = files["index.html"].replace(bootstrap.encode(), b"flutter_bootstrap.js")
                for name, data in files.items():
                    path = output / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(data)

            with patch.object(web.subprocess, "run", side_effect=fake_build):
                result = web.package(root, "flutter", VERSION, "/", "preview", "cloudflare")
            self.assertFalse(stale.exists())
            manifest = web.verify_archive(Path(result["archive"]))
            self.assertNotIn("old.dart.js", manifest["fileHashes"])
            self.assertTrue(Path(result["checksum"]).read_text().startswith(manifest["sha256"]))


if __name__ == "__main__":
    unittest.main()
