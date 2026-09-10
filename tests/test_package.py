from __future__ import annotations

import json
import unittest
from pathlib import Path

from patchlib import sha256_path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class PackageContractTests(unittest.TestCase):
    def test_manifest_payload_integrity_and_target_closure(self) -> None:
        manifest = json.loads(
            (REPOSITORY_ROOT / "package-manifest.json").read_text(encoding="utf-8")
        )
        self.assertEqual(3, manifest["schemaVersion"])
        self.assertEqual("compatibilityPackage", manifest["packageType"])
        self.assertEqual("1.0.0", manifest["packageVersion"])
        self.assertEqual(
            ["zibo-737ng", "levelup-737ng"],
            manifest["supportedProducts"],
        )
        payloads = {item["path"]: item for item in manifest["payloads"]}
        targets = manifest["targets"]
        self.assertEqual(set(payloads), {target["payload"] for target in targets})
        self.assertEqual(1, len(targets))
        target_paths = {target["relativePath"] for target in targets}
        baselines = manifest["supportedBaselines"]
        self.assertEqual(
            {"zibo-4.05.35", "levelup-v2.s1.50"},
            {baseline["id"] for baseline in baselines},
        )
        fingerprints = set()
        for baseline in baselines:
            files = {item["relativePath"]: item for item in baseline["files"]}
            self.assertEqual(target_paths, set(files))
            fingerprint = tuple(
                sorted((relative, item["sourceSha256"]) for relative, item in files.items())
            )
            self.assertNotIn(fingerprint, fingerprints)
            fingerprints.add(fingerprint)
            for item in files.values():
                self.assertEqual(64, len(item["sourceSha256"]))
                self.assertEqual(64, len(item["resultSha256"]))
        for relative, metadata in payloads.items():
            path = REPOSITORY_ROOT / relative
            self.assertTrue(path.is_file())
            self.assertEqual(metadata["size"], path.stat().st_size)
            self.assertEqual(metadata["sha256"], sha256_path(path))

        self.assertEqual(1, len(manifest["modules"]))
        module = manifest["modules"][0]
        self.assertEqual("cpdlc", module["moduleId"])
        self.assertEqual("optional", module["policy"])
        self.assertFalse(module["defaultEnabled"])
        self.assertEqual(payloads, {item["path"]: item for item in module["payloads"]})
        self.assertEqual(targets, [
            {key: value for key, value in target.items() if key != "sourceSha256"}
            for target in module["targets"]
        ])

    def test_repository_does_not_ship_complete_aircraft_targets(self) -> None:
        forbidden = {
            "B738.a_fms.lua",
            "B738.tablet.lua",
            "zibomod.xpl",
        }
        shipped = {path.name for path in REPOSITORY_ROOT.rglob("*") if path.is_file()}
        self.assertTrue(forbidden.isdisjoint(shipped))


if __name__ == "__main__":
    unittest.main()
