# Source and owner evidence

## Target baselines

The deltas were derived from locally preserved, untouched stock aircraft
files. No complete upstream file is distributed by this repository.

| Baseline | File | Source SHA-256 | Installed SHA-256 |
|---|---|---|---|
| Zibo B737-800X 4.05.35 | `B738.a_fms.lua` | `ff313b0e88c62845ad1c4a2b1f4bd599f57d8799e8d6707bfc10a3369fd63a8e` | `07d99afd43ae9e2dd3349c5b8093303de26438b7267c6c98ef0b412f8a2ef8f7` |
| LevelUp 737NG Series V2.S1.50 | `B738.a_fms.lua` | `757057120c2953a9cdefbfebcd593bdb4fd9636721328fb1ce6d6550f8f49384` | `dfb99321682bebea9a91773b0d103ffd0ffab8cca390af13083ebf0c92906673` |

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

The pipeline on `B738.a_fms.lua` has 15 operations: one
`exact-text-replacements-v1` payload with eight real replacements (five
behavior fixes, two `PROCEED DIRECT TO` parser fixes, the display overlay
hook) and 14 `insert-marked-block-v1` payloads (12 one-line LSK hooks,
PREV/NEXT need none because the pages set `max_page_buf`; the `dlnk_in_use`
hook; the page module `src/cpdlc_patch_module.lua`, inserted before
`B738_fmc_disp_capt()`). Every anchor and every old block occurs exactly once
in both baselines; the generator in `tools/make_patch_payloads.py` verifies
that and the idempotency of the result before writing the payloads. The module only calls stock functions and globals
that exist in both baselines (`atc_msg_shift`, `send_cpdlc`,
`find_act_route_wpt2`, `create_legs_abeam_list`, `rte_copy`, `rte_paste`,
`lat_lon_legs2/8`, `add_fmc_msg`, `null_fmc_disp`, `reset_fmc_pages`).

## Reference implementation

The behaviors mirror the verified C++ fixes in the WahlthoMod plugin
(`zibomod/fms.inc`, review of 2026-09-09): response attribute default,
STANDBY persistence and prompt gate, uplink abort timer and the datalink menu
ATC prompt.
