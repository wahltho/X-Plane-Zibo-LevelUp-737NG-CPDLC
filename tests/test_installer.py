from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from patchlib import (
    PatchError,
    apply_exact_text_replacements,
    remove_exact_text_replacements,
)


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
INSTALLER = REPOSITORY_ROOT / "z_Install.py"
TARGETS = (
    "plugins/xlua/scripts/B738.a_fms/B738.a_fms.lua",
)
BASELINES = (
    ("zibo-4.05.35", "ZIBO_40535_ROOT", "B737-800X", "\r\n", "\r\n"),
    ("levelup-v2.s1.50", "LEVELUP_V2S150_ROOT", "LevelUp V2.S1.50", "\r\n", "\r\n"),
)
CPDLC_MARKERS = (
    "-- CPDLC PATCH: unknown or empty response attribute = no response required",
    "-- CPDLC PATCH: STANDBY is an intermediate status until the final response",
    "-- CPDLC PATCH: STANDBY stays available until it has been sent (status 3)",
    "-- CPDLC PATCH: FANS has no automatic abort of an unanswered uplink;",
    "-- CPDLC PATCH: reach the ATC pages without an ATC key",
    "-- BEGIN CPDLC PATCH MODULE",
    "-- END CPDLC PATCH MODULE",
    "\tcpdlc_patch_overlay()\t-- CPDLC PATCH",
    "dlnk_in_use = dlnk_in_use + cpdlc_patch_in_use()\t-- CPDLC PATCH",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def find_lua51_compiler() -> str | None:
    seen: set[str] = set()
    for command in ("luac5.1", "luac-5.1", "luac"):
        compiler = shutil.which(command)
        if compiler is None or compiler in seen:
            continue
        seen.add(compiler)
        version = subprocess.run(
            [compiler, "-v"], capture_output=True, text=True, check=False
        )
        banner = " ".join(part.strip() for part in (version.stdout, version.stderr) if part.strip())
        if version.returncode == 0 and re.search(r"\bLua\s+5\.1(?:\.\d+)?\b", banner):
            return compiler
    return None


class TextPatchUnitTests(unittest.TestCase):
    def test_lua54_compiler_is_not_selected(self) -> None:
        def which(command: str) -> str | None:
            return "/usr/bin/luac" if command == "luac" else None

        completed = subprocess.CompletedProcess(
            ["/usr/bin/luac", "-v"], 0, "Lua 5.4.8", ""
        )
        with patch.object(shutil, "which", side_effect=which), patch.object(
            subprocess, "run", return_value=completed
        ):
            self.assertIsNone(find_lua51_compiler())

    def test_ambiguous_original_block_is_rejected(self) -> None:
        spec = {
            "format": "exact-text-replacements-v1",
            "replacements": [
                {
                    "name": "ambiguous",
                    "oldLines": ["old"],
                    "newLines": ["new"],
                }
            ],
        }
        with self.assertRaisesRegex(PatchError, "original=2"):
            apply_exact_text_replacements(b"old\nold\n", spec)

    def test_line_endings_and_final_newline_are_preserved(self) -> None:
        spec = {
            "format": "exact-text-replacements-v1",
            "replacements": [
                {
                    "name": "replace",
                    "oldLines": ["one"],
                    "newLines": ["one", "two"],
                }
            ],
        }
        self.assertEqual(
            b"one\r\ntwo\r\nthree\r\n",
            apply_exact_text_replacements(b"one\r\nthree\r\n", spec),
        )

    def test_remove_preserves_unowned_content(self) -> None:
        spec = {
            "format": "exact-text-replacements-v1",
            "replacements": [
                {
                    "name": "owned",
                    "oldLines": ["anchor"],
                    "newLines": ["anchor", "-- BEGIN OWNED", "value", "-- END OWNED"],
                }
            ],
        }
        installed = apply_exact_text_replacements(b"before\nanchor\nafter\n", spec)
        installed += b"-- unrelated later patch\n"
        self.assertEqual(
            b"before\nanchor\nafter\n-- unrelated later patch\n",
            remove_exact_text_replacements(installed, spec),
        )


class InstallerIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        missing = [
            environment
            for _, environment, _, _, _ in BASELINES
            if not os.environ.get(environment)
        ]
        if missing:
            raise unittest.SkipTest(
                "Set all integration baseline roots: " + ", ".join(missing)
            )
        cls.baselines = [
            (identifier, Path(os.environ[environment]), name, fms_eol, tablet_eol)
            for identifier, environment, name, fms_eol, tablet_eol in BASELINES
        ]

    def copy_baseline(self, upstream: Path, aircraft_root: Path) -> dict[str, str]:
        for relative in TARGETS:
            source = upstream / relative
            destination = aircraft_root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        return {
            relative: sha256(aircraft_root / relative) for relative in TARGETS
        }

    def run_installer(
        self, aircraft_root: Path, action: str, expected: int = 0
    ) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [
                sys.executable,
                str(INSTALLER),
                action,
                "--aircraft-root",
                str(aircraft_root),
            ],
            cwd=REPOSITORY_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(expected, result.returncode, msg=result.stdout + result.stderr)
        return result

    def test_check_install_verify_and_uninstall(self) -> None:
        for identifier, upstream, name, fms_eol, tablet_eol in self.baselines:
            with self.subTest(baseline=identifier), tempfile.TemporaryDirectory(
                prefix="cpdlc-test-"
            ) as temporary:
                aircraft_root = Path(temporary) / name
                original_hashes = self.copy_baseline(upstream, aircraft_root)

                check = self.run_installer(aircraft_root, "check")
                self.assertIn(f"Detected baseline: {identifier}", check.stdout)
                self.assertEqual(
                    original_hashes,
                    {relative: sha256(aircraft_root / relative) for relative in TARGETS},
                )

                self.run_installer(aircraft_root, "install")
                self.run_installer(aircraft_root, "verify")
                self.run_installer(aircraft_root, "install")

                state = json.loads(
                    (aircraft_root / ".zibo-cpdlc-patch/state.json").read_text(
                        encoding="utf-8"
                    )
                )
                self.assertEqual("wahltho.zibo-40535.cpdlc", state["packageId"])
                self.assertEqual("1.0.0", state["packageVersion"])
                self.assertEqual(identifier, state["baselineId"])
                self.assertEqual(1, len(state["files"]))

                fms_bytes = (aircraft_root / TARGETS[0]).read_bytes()
                fms = fms_bytes.decode("utf-8")
                if fms_eol == "\r\n":
                    self.assertEqual(fms_bytes.count(b"\n"), fms_bytes.count(b"\r\n"))
                else:
                    self.assertEqual(0, fms_bytes.count(b"\r\n"))
                for marker in CPDLC_MARKERS:
                    self.assertEqual(1, fms.count(marker), marker)
                self.assertEqual(1, fms.count('elseif msg_val == "Y" then'))
                self.assertEqual(1, fms.count("if atc_msg_rsp[ggg] ~= 0 and atc_msg_rcv_snd[ggg] == 1 then"))
                self.assertEqual(1, fms.count('line2_l = "<ATC            AOC STD>"'))
                self.assertEqual(1, fms.count("if atc_msg_status[in_msg] ~= 3 then"))
                self.assertEqual(14, fms.count('if cpdlc_patch_lsk("'))
                self.assertEqual(2, fms.count("atc_proc_dir = word_txt[4]\t-- CPDLC PATCH: the fix follows DIRECT TO"))
                self.assertEqual(1, fms.count("function cpdlc_patch_load_direct()"))

                luac = find_lua51_compiler()
                if luac:
                    syntax = subprocess.run(
                        [luac, "-p", str(aircraft_root / TARGETS[0])],
                        text=True,
                        capture_output=True,
                        check=False,
                    )
                    self.assertEqual(0, syntax.returncode, msg=syntax.stdout + syntax.stderr)

                installed = (aircraft_root / TARGETS[0]).read_bytes()
                separator = b"" if installed.endswith((b"\r", b"\n")) else fms_eol.encode()
                unrelated = separator + b"-- later change" + fms_eol.encode()
                (aircraft_root / TARGETS[0]).write_bytes(installed + unrelated)
                self.run_installer(aircraft_root, "uninstall")
                self.assertEqual(
                    original_hashes[TARGETS[0]],
                    hashlib.sha256(
                        (aircraft_root / TARGETS[0]).read_bytes().replace(unrelated, b"")
                    ).hexdigest(),
                )
                self.assertTrue((aircraft_root / TARGETS[0]).read_bytes().endswith(unrelated))
                self.assertFalse((aircraft_root / ".zibo-cpdlc-patch").exists())
                self.run_installer(aircraft_root, "check")

    def test_unowned_source_change_is_preserved(self) -> None:
        for identifier, upstream, name, _, _ in self.baselines:
            with self.subTest(baseline=identifier), tempfile.TemporaryDirectory(
                prefix="cpdlc-modified-"
            ) as temporary:
                aircraft_root = Path(temporary) / name
                self.copy_baseline(upstream, aircraft_root)
                tablet = aircraft_root / TARGETS[0]
                original = tablet.read_bytes()
                eol = b"\r\n" if original.count(b"\r\n") > 0 else b"\n"
                separator = b"" if original.endswith((b"\r", b"\n")) else eol
                unrelated = separator + b"-- local modification" + eol
                tablet.write_bytes(original + unrelated)
                before = {
                    relative: sha256(aircraft_root / relative) for relative in TARGETS
                }
                result = self.run_installer(aircraft_root, "check")
                self.assertIn("validated structurally", result.stdout)
                self.assertEqual(
                    before,
                    {relative: sha256(aircraft_root / relative) for relative in TARGETS},
                )
                self.run_installer(aircraft_root, "install")
                self.run_installer(aircraft_root, "uninstall")
                self.assertTrue(tablet.read_bytes().endswith(unrelated))

    def test_state_without_baseline_keys_remains_verifiable_and_uninstallable(self) -> None:
        identifier, upstream, name, _, _ = self.baselines[0]
        with tempfile.TemporaryDirectory(prefix="cpdlc-v010-") as temporary:
            aircraft_root = Path(temporary) / name
            original_hashes = self.copy_baseline(upstream, aircraft_root)
            self.run_installer(aircraft_root, "install")

            state_path = aircraft_root / ".zibo-cpdlc-patch/state.json"
            state = json.loads(state_path.read_text(encoding="utf-8"))
            state.pop("baselineId")
            state.pop("aircraftFamily")
            state.pop("aircraftRelease")
            state["packageVersion"] = "0.0.9"
            state_path.write_text(
                json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )

            verify = self.run_installer(aircraft_root, "verify")
            self.assertIn("0.0.9", verify.stdout)
            reinstall = self.run_installer(aircraft_root, "install")
            self.assertIn("Already installed and verified", reinstall.stdout)
            self.run_installer(aircraft_root, "uninstall")
            self.assertEqual(
                original_hashes,
                {relative: sha256(aircraft_root / relative) for relative in TARGETS},
            )


if __name__ == "__main__":
    unittest.main()
