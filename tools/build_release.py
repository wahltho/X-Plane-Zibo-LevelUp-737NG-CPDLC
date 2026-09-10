#!/usr/bin/env python3
"""Build a deterministic CPDLC source-patch release archive."""

from __future__ import annotations

import hashlib
import json
import zipfile
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DIST_ROOT = REPOSITORY_ROOT / "dist"
PACKAGE_FILES = (
    "CHANGELOG.md",
    "INSTALLATION.md",
    "LICENSE",
    "README.md",
    "RUNTIME_TEST_PLAN.md",
    "SOURCE.md",
    "package-manifest.json",
    "patchlib.py",
    "patches/B738.a_fms.lua.json",
    "z_Install.py",
)
MODULE_ID = "cpdlc"
MODULE_PAYLOADS = (
    "patches/B738.a_fms.lua.json",
)


def main() -> int:
    manifest = json.loads(
        (REPOSITORY_ROOT / "package-manifest.json").read_text(encoding="utf-8")
    )
    version = manifest["packageVersion"]
    archive = DIST_ROOT / f"X-Plane-Zibo-LevelUp-737NG-CPDLC-v{version}.zip"
    checksum = archive.with_suffix(archive.suffix + ".sha256")
    DIST_ROOT.mkdir(exist_ok=True)

    timestamp = (2026, 1, 1, 0, 0, 0)
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for relative in PACKAGE_FILES:
            source = REPOSITORY_ROOT / relative
            if not source.is_file():
                raise FileNotFoundError(relative)
            info = zipfile.ZipInfo(f"X-Plane-Zibo-LevelUp-737NG-CPDLC-v{version}/{relative}", timestamp)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, source.read_bytes())
        for relative in MODULE_PAYLOADS:
            source = REPOSITORY_ROOT / relative
            info = zipfile.ZipInfo(
                f"X-Plane-Zibo-LevelUp-737NG-CPDLC-v{version}/modules/{MODULE_ID}/{relative}",
                timestamp,
            )
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, source.read_bytes())

    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    checksum.write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    print(archive)
    print(checksum)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
