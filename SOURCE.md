# Source and owner evidence

## Target baselines

The deltas were derived from locally preserved, untouched stock aircraft
files. No complete upstream file is distributed by this repository.

| Baseline | File | Source SHA-256 | Installed SHA-256 |
|---|---|---|---|
| Zibo 4.05.35 | `B738.a_fms.lua` | `ff313b0e88c62845ad1c4a2b1f4bd599f57d8799e8d6707bfc10a3369fd63a8e` | `1c37e88b69162ab0d747541ba287dc8327a7de097c9d6c15d61c73ee10857f03` |
| LevelUp V2.S1.50 | `B738.a_fms.lua` | `757057120c2953a9cdefbfebcd593bdb4fd9636721328fb1ce6d6550f8f49384` | `c70b28fe874f600680c7d79ceace5091025f5dd7a406670e986ea0f387ded5a9` |

Both baselines use CRLF in `B738.a_fms.lua`; the installer preserves the
target's existing convention. LevelUp V2.S1 contains no CPDLC code and is not
a baseline.

## Owner chain

```text
Hoppie transport plugin -> hoppiebridge/poll_message_*
  -> parse_cpdlc()            (response attribute, block 1)
  -> atc_msg_* arrays         (message store)
  -> B738_atc_comm()          (response commit, block 2; message timers, block 4)
  -> dl_cpdlc_message()       (CMU message page prompts, block 3)
  -> dl_menu()                (DLNK-APPLICATION MENU, block 5)
```

All five blocks are owned by `B738.a_fms.lua`. Every block occurs exactly
once in both baselines; the generator in `tools/make_patch_payloads.py`
verifies that before writing the payload.

## Reference implementation

The behaviors mirror the verified C++ fixes in the WahlthoMod plugin
(`zibomod/fms.inc`, review of 2026-09-09): response attribute default,
STANDBY persistence and prompt gate, uplink abort timer and the datalink menu
ATC prompt.
