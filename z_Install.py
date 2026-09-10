#!/usr/bin/env python3
"""Install and manage the Zibo/LevelUp CPDLC patch."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

from patchlib import (
    PatchError,
    apply_operation,
    load_json,
    remove_operation,
    sha256_bytes,
    sha256_path,
)


PACKAGE_ROOT = Path(__file__).resolve().parent
MANIFEST_PATH = PACKAGE_ROOT / "package-manifest.json"
STATE_DIRECTORY = ".zibo-cpdlc-patch"
STATE_FILENAME = "state.json"


def _safe_relative_path(value: str) -> Path:
    posix = PurePosixPath(value)
    if posix.is_absolute() or not posix.parts or ".." in posix.parts:
        raise PatchError(f"Unsafe relative path in manifest: {value!r}")
    return Path(*posix.parts)


def _load_manifest() -> dict[str, Any]:
    manifest = load_json(MANIFEST_PATH)
    if manifest.get("schemaVersion") != 3:
        raise PatchError("Unsupported package manifest schema")
    if manifest.get("packageId") != "wahltho.zibo-40535.cpdlc":
        raise PatchError("Unexpected package identity")
    _validate_baselines(manifest)
    return manifest


def _baseline_file_map(baseline: dict[str, Any]) -> dict[str, dict[str, Any]]:
    files = baseline.get("files", [])
    result = {item["relativePath"]: item for item in files}
    if len(result) != len(files):
        raise PatchError(f"Duplicate file in baseline: {baseline.get('id', '<unknown>')}")
    return result


def _validate_baselines(manifest: dict[str, Any]) -> None:
    target_paths = {target["relativePath"] for target in manifest.get("targets", [])}
    baselines = manifest.get("supportedBaselines", [])
    if not target_paths or not baselines:
        raise PatchError("Manifest contains no targets or supported baselines")
    identifiers = [baseline.get("id") for baseline in baselines]
    if any(not value for value in identifiers) or len(set(identifiers)) != len(identifiers):
        raise PatchError("Supported baseline identifiers are missing or duplicated")

    fingerprints: set[tuple[tuple[str, str], ...]] = set()
    for baseline in baselines:
        files = _baseline_file_map(baseline)
        if set(files) != target_paths:
            raise PatchError(
                f"Baseline target closure mismatch: {baseline['id']}"
            )
        fingerprint = tuple(
            sorted((relative, metadata["sourceSha256"]) for relative, metadata in files.items())
        )
        if fingerprint in fingerprints:
            raise PatchError(f"Duplicate source fingerprint: {baseline['id']}")
        fingerprints.add(fingerprint)
        for relative, metadata in files.items():
            for field in ("sourceSha256", "resultSha256"):
                value = metadata.get(field)
                if not isinstance(value, str) or len(value) != 64:
                    raise PatchError(
                        f"Invalid {field} for {baseline['id']}: {relative}"
                    )


def _validate_payloads(manifest: dict[str, Any]) -> None:
    declared = {item["path"]: item for item in manifest["payloads"]}
    referenced = {target["payload"] for target in manifest["targets"]}
    if set(declared) != referenced:
        raise PatchError("Manifest payload declarations do not match target references")
    for relative, metadata in declared.items():
        path = PACKAGE_ROOT / _safe_relative_path(relative)
        if not path.is_file():
            raise PatchError(f"Missing patch payload: {relative}")
        if path.stat().st_size != metadata["size"] or sha256_path(path) != metadata["sha256"]:
            raise PatchError(f"Patch payload integrity check failed: {relative}")


def _state_path(aircraft_root: Path) -> Path:
    return aircraft_root / STATE_DIRECTORY / STATE_FILENAME


def _load_state(aircraft_root: Path) -> dict[str, Any] | None:
    path = _state_path(aircraft_root)
    return load_json(path) if path.exists() else None


def _target_path(aircraft_root: Path, target: dict[str, Any]) -> Path:
    return aircraft_root / _safe_relative_path(target["relativePath"])


def _detect_baseline(
    aircraft_root: Path, manifest: dict[str, Any]
) -> dict[str, Any] | None:
    actual: dict[str, str] = {}
    for target in manifest["targets"]:
        path = _target_path(aircraft_root, target)
        if not path.is_file():
            raise PatchError(f"Required aircraft file is missing: {target['relativePath']}")
        actual[target["relativePath"]] = sha256_path(path)

    matches = []
    for baseline in manifest["supportedBaselines"]:
        files = _baseline_file_map(baseline)
        if all(actual[relative] == metadata["sourceSha256"] for relative, metadata in files.items()):
            matches.append(baseline)
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        raise PatchError("Source files ambiguously match multiple supported baselines")

    return None


def _transform_targets(
    aircraft_root: Path, manifest: dict[str, Any], baseline: dict[str, Any] | None
) -> dict[str, bytes]:
    transformed: dict[str, bytes] = {}
    baseline_files = _baseline_file_map(baseline) if baseline is not None else None
    for target in manifest["targets"]:
        relative = target["relativePath"]
        source = _target_path(aircraft_root, target).read_bytes()
        payload = load_json(PACKAGE_ROOT / _safe_relative_path(target["payload"]))
        result = apply_operation(source, target["operation"], payload)
        actual = sha256_bytes(result)
        expected = baseline_files[relative]["resultSha256"] if baseline_files else None
        if expected is not None and actual != expected:
            raise PatchError(
                f"Generated result hash mismatch for {baseline['id']}: {relative}\n"
                f"  actual: {actual}\n"
                f"  expected: {expected}"
            )
        transformed[relative] = result
    return transformed


def _remove_targets(aircraft_root: Path, manifest: dict[str, Any]) -> dict[str, bytes]:
    transformed: dict[str, bytes] = {}
    for target in manifest["targets"]:
        relative = target["relativePath"]
        source = _target_path(aircraft_root, target).read_bytes()
        payload = load_json(PACKAGE_ROOT / _safe_relative_path(target["payload"]))
        transformed[relative] = remove_operation(source, target["operation"], payload)
    return transformed


def _write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(payload)
    os.replace(temporary, path)


def _verify_state(aircraft_root: Path, state: dict[str, Any], manifest: dict[str, Any]) -> None:
    if state.get("packageId") != manifest["packageId"]:
        raise PatchError("Installed state belongs to a different package")
    for item in state.get("files", []):
        path = aircraft_root / _safe_relative_path(item["relativePath"])
        if not path.is_file():
            raise PatchError(f"Installed file is missing: {item['relativePath']}")
        current = path.read_bytes()
        target = next(
            target for target in manifest["targets"]
            if target["relativePath"] == item["relativePath"]
        )
        payload = load_json(PACKAGE_ROOT / _safe_relative_path(target["payload"]))
        verified = apply_operation(current, target["operation"], payload)
        if verified != current:
            raise PatchError(
                f"Installed CPDLC blocks are missing from: {item['relativePath']}"
            )


def command_check(aircraft_root: Path, manifest: dict[str, Any]) -> int:
    state = _load_state(aircraft_root)
    if state is not None:
        _verify_state(aircraft_root, state, manifest)
        print(f"Installed and verified: {state['packageId']} {state['packageVersion']}")
        return 0
    _validate_payloads(manifest)
    baseline = _detect_baseline(aircraft_root, manifest)
    _transform_targets(aircraft_root, manifest, baseline)
    print(f"Ready to install {manifest['packageId']} {manifest['packageVersion']}")
    if baseline is not None:
        print(
            f"Detected baseline: {baseline['id']} "
            f"({baseline['aircraftFamily']} {baseline['release']})"
        )
    else:
        print("No exact baseline fingerprint; all owned patch anchors validated structurally.")
    print(f"Validated {len(manifest['targets'])} source files; no files were changed.")
    return 0


def command_install(aircraft_root: Path, manifest: dict[str, Any]) -> int:
    state = _load_state(aircraft_root)
    if state is not None:
        _verify_state(aircraft_root, state, manifest)
        print(f"Already installed and verified: {state['packageId']} {state['packageVersion']}")
        return 0

    _validate_payloads(manifest)
    baseline = _detect_baseline(aircraft_root, manifest)
    transformed = _transform_targets(aircraft_root, manifest, baseline)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    state_root = aircraft_root / STATE_DIRECTORY
    backup_root = state_root / "backups" / timestamp
    backup_root.mkdir(parents=True, exist_ok=False)
    state_files: list[dict[str, Any]] = []

    for target in manifest["targets"]:
        relative = target["relativePath"]
        source = _target_path(aircraft_root, target)
        backup = backup_root / _safe_relative_path(relative)
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, backup)
        state_files.append(
            {
                "relativePath": relative,
                "originalSha256": sha256_path(source),
                "installedSha256": sha256_bytes(transformed[relative]),
            }
        )

    try:
        with tempfile.TemporaryDirectory(prefix="cpdlc-stage-", dir=state_root) as name:
            staging_root = Path(name)
            staged: dict[str, Path] = {}
            for target in manifest["targets"]:
                relative = target["relativePath"]
                destination = _target_path(aircraft_root, target)
                temporary = staging_root / _safe_relative_path(relative)
                temporary.parent.mkdir(parents=True, exist_ok=True)
                temporary.write_bytes(transformed[relative])
                os.chmod(temporary, stat.S_IMODE(destination.stat().st_mode))
                staged[relative] = temporary
            for target in manifest["targets"]:
                relative = target["relativePath"]
                os.replace(staged[relative], _target_path(aircraft_root, target))

        state_document = {
            "schemaVersion": 1,
            "packageId": manifest["packageId"],
            "packageVersion": manifest["packageVersion"],
            "manifestSha256": sha256_path(MANIFEST_PATH),
            "baselineId": baseline["id"] if baseline is not None else None,
            "aircraftFamily": baseline["aircraftFamily"] if baseline is not None else None,
            "aircraftRelease": baseline["release"] if baseline is not None else None,
            "installedAtUtc": datetime.now(timezone.utc).isoformat(),
            "backupRelativePath": backup_root.relative_to(aircraft_root).as_posix(),
            "files": state_files,
        }
        _write_json_atomic(_state_path(aircraft_root), state_document)
    except Exception:
        for target in manifest["targets"]:
            relative = target["relativePath"]
            backup = backup_root / _safe_relative_path(relative)
            destination = _target_path(aircraft_root, target)
            if backup.exists():
                shutil.copy2(backup, destination)
        raise

    print(f"Installed {manifest['packageId']} {manifest['packageVersion']}.")
    print(f"Backup: {backup_root}")
    print("Restart X-Plane before testing the aircraft.")
    return 0


def command_verify(aircraft_root: Path, manifest: dict[str, Any]) -> int:
    state = _load_state(aircraft_root)
    if state is None:
        raise PatchError("The CPDLC patch is not installed")
    _validate_payloads(manifest)
    _verify_state(aircraft_root, state, manifest)
    print(f"Verified {state['packageId']} {state['packageVersion']} ({len(state['files'])} files).")
    return 0


def command_uninstall(aircraft_root: Path, manifest: dict[str, Any]) -> int:
    state = _load_state(aircraft_root)
    if state is None:
        raise PatchError("The CPDLC patch is not installed")
    _verify_state(aircraft_root, state, manifest)
    transformed = _remove_targets(aircraft_root, manifest)

    state_root = aircraft_root / STATE_DIRECTORY
    with tempfile.TemporaryDirectory(prefix="cpdlc-restore-", dir=state_root) as name:
        staging_root = Path(name)
        staged: dict[str, Path] = {}
        rollback: dict[str, Path] = {}
        for item in state["files"]:
            relative = item["relativePath"]
            temporary = staging_root / _safe_relative_path(relative)
            temporary.parent.mkdir(parents=True, exist_ok=True)
            temporary.write_bytes(transformed[relative])
            current = aircraft_root / _safe_relative_path(relative)
            os.chmod(temporary, stat.S_IMODE(current.stat().st_mode))
            staged[relative] = temporary
            rollback_file = staging_root / "installed" / _safe_relative_path(relative)
            rollback_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(current, rollback_file)
            rollback[relative] = rollback_file
        try:
            for item in state["files"]:
                relative = item["relativePath"]
                os.replace(staged[relative], aircraft_root / _safe_relative_path(relative))
        except Exception:
            for item in state["files"]:
                relative = item["relativePath"]
                rollback_file = rollback[relative]
                if rollback_file.exists():
                    shutil.copy2(rollback_file, aircraft_root / _safe_relative_path(relative))
            raise

    shutil.rmtree(state_root)
    print(f"Uninstalled {manifest['packageId']} and removed only its owned blocks.")
    return 0


def _parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("check", "install", "verify", "uninstall"))
    parser.add_argument("--aircraft-root", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = _parse_arguments()
    aircraft_root = arguments.aircraft_root.expanduser().resolve()
    if not aircraft_root.is_dir():
        raise PatchError(f"Aircraft root is not a directory: {aircraft_root}")
    manifest = _load_manifest()
    actions = {
        "check": command_check,
        "install": command_install,
        "verify": command_verify,
        "uninstall": command_uninstall,
    }
    return actions[arguments.action](aircraft_root, manifest)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (PatchError, OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
