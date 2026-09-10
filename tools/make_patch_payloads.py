#!/usr/bin/env python3
"""Generate the CPDLC exact-text deltas from locally preserved stock Lua files.

The old blocks are extracted verbatim from the Zibo 4.05.35 FMS script and
verified to occur exactly once in every supported baseline. No complete
upstream file is written into the repository.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from patchlib import apply_exact_text_replacements, sha256_bytes, split_text_bytes  # noqa: E402

FMS_RELATIVE = "plugins/xlua/scripts/B738.a_fms/B738.a_fms.lua"

BASELINES = (
    ("zibo-4.05.35", "Zibo B737-800X", "4.05.35", "ZIBO_40535_ROOT"),
    ("levelup-v2.s1.50", "LevelUp 737NG Series", "V2.S1.50", "LEVELUP_V2S150_ROOT"),
)


def _block(lines: list[str], first_line: str, count: int, name: str) -> list[str]:
    matches = [i for i, line in enumerate(lines) if line == first_line]
    if len(matches) != 1:
        raise RuntimeError(f"{name}: anchor line found {len(matches)} times")
    return lines[matches[0] : matches[0] + count]


def make_fms_patch(reference_lines: list[str]) -> dict[str, Any]:
    t = "\t"
    replacements: list[dict[str, Any]] = []

    # 1. Response attribute: unknown or empty means no response required.
    old = _block(reference_lines, t * 7 + 'if msg_val == "N" or msg_val == "NE" then', 11, "rsp")
    assert old[-2] == t * 8 + "atc_msg_rsp_tmp = 4" and old[-1] == t * 7 + "end", old
    new = old[:-3] + [
        t * 7 + 'elseif msg_val == "Y" then',
        t * 8 + "atc_msg_rsp_tmp = 4",
        t * 7 + "else",
        t * 8 + "-- CPDLC PATCH: unknown or empty response attribute = no response required",
        t * 8 + "atc_msg_rsp_tmp = 0",
        t * 7 + "end",
    ]
    replacements.append({"name": "CPDLC response attribute default", "oldLines": old, "newLines": new})

    # 2. STANDBY persists as message status 3.
    old = _block(reference_lines, t + "elseif atc_resp_state == 2 then", 10, "standby persist")
    assert old[6] == t * 4 + "atc_msg_txt[atc_resp_state_idx] = atc_resp_state_msg", old
    new = old[:7] + [
        t * 4 + "-- CPDLC PATCH: STANDBY is an intermediate status until the final response",
        t * 4 + "atc_msg_status[atc_resp_state_idx] = atc_resp_state_status",
    ] + old[7:]
    replacements.append({"name": "CPDLC STANDBY status persistence", "oldLines": old, "newLines": new})

    # 3. STANDBY prompt is offered until STANDBY has been sent.
    old = _block(reference_lines, t * 5 + "if atc_msg_status[in_msg] ~= 2 then", 2, "standby prompt")
    assert old[1] == t * 6 + 'line5_l = "=PRINT          STANDBY="', old
    new = [
        t * 5 + "-- CPDLC PATCH: STANDBY stays available until it has been sent (status 3)",
        t * 5 + "if atc_msg_status[in_msg] ~= 3 then",
        old[1],
    ]
    replacements.append({"name": "CPDLC STANDBY prompt gate", "oldLines": old, "newLines": new})

    # 4. No automatic abort of an unanswered uplink; crew downlinks still expire.
    old = _block(reference_lines, t * 5 + "if atc_msg_rsp[ggg] ~= 0 then", 5, "auto abort")
    assert old[2] == t * 7 + 'atc_msg_status[ggg] = 6\t\t--"ABORTED"', old
    new = [
        t * 5 + "-- CPDLC PATCH: FANS has no automatic abort of an unanswered uplink;",
        t * 5 + "-- only a crew request that ATC never answered expires.",
        t * 5 + "if atc_msg_rsp[ggg] ~= 0 and atc_msg_rcv_snd[ggg] == 1 then",
        t * 6 + "if atc_msg_status[ggg] == 2 then",
        old[2],
        old[3],
        old[4],
    ]
    replacements.append({"name": "CPDLC uplink abort timer", "oldLines": old, "newLines": new})

    # 5. FANS on a CDU without ATC key: ATC prompt on the datalink menu.
    old = _block(reference_lines, t + "if B738DR_cpdlc == 0 or B738DR_cpdlc == 2 then", 5, "dl_menu")
    assert old[2] == t * 2 + 'line2_l = "                AOC STD>"', old
    new = [
        t + "if B738DR_cpdlc == 2 then",
        t * 2 + "-- CPDLC PATCH: reach the ATC pages without an ATC key",
        old[1],
        t * 2 + 'line2_l = "<ATC            AOC STD>"',
        old[3],
        old[4],
        t + "elseif B738DR_cpdlc == 0 then",
        old[1],
        old[2],
        old[3],
        old[4],
    ]
    replacements.append({"name": "CPDLC datalink menu ATC prompt", "oldLines": old, "newLines": new})

    return {"format": "exact-text-replacements-v1", "replacements": replacements}


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zibo-root", required=True, type=Path)
    parser.add_argument("--levelup-v2s150-root", required=True, type=Path)
    args = parser.parse_args()
    roots = {
        "zibo-4.05.35": args.zibo_root,
        "levelup-v2.s1.50": args.levelup_v2s150_root,
    }
    repository = Path(__file__).resolve().parents[1]
    reference = (roots["zibo-4.05.35"] / FMS_RELATIVE).read_bytes()
    reference_lines, _, _ = split_text_bytes(reference)
    spec = make_fms_patch(reference_lines)
    write_json(repository / "patches/B738.a_fms.lua.json", spec)

    baselines = []
    for identifier, family, release, _ in BASELINES:
        source = (roots[identifier] / FMS_RELATIVE).read_bytes()
        result = apply_exact_text_replacements(source, spec)
        if apply_exact_text_replacements(result, spec) != result:
            raise RuntimeError(f"{identifier}: installed result is not idempotent")
        baselines.append({
            "aircraftFamily": family,
            "files": [{
                "relativePath": FMS_RELATIVE,
                "resultSha256": sha256_bytes(result),
                "sourceSha256": sha256_bytes(source),
            }],
            "id": identifier,
            "release": release,
        })
        print(f"{identifier}: source {sha256_bytes(source)} -> result {sha256_bytes(result)}")

    manifest_path = repository / "package-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest["supportedBaselines"] = baselines
    payload = (repository / "patches/B738.a_fms.lua.json").read_bytes()
    payload_entry = {"path": "patches/B738.a_fms.lua.json", "sha256": sha256_bytes(payload), "size": len(payload)}
    for module in manifest.get("modules", []):
        module["payloads"] = [payload_entry]
    manifest["payloads"] = [payload_entry]
    manifest["targets"] = [
        {key: value for key, value in target.items() if key != "sourceSha256"}
        for module in manifest.get("modules", []) for target in module["targets"]
    ]
    if manifest:
        write_json(manifest_path, manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
