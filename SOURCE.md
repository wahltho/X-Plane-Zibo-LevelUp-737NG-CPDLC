# Source and owner evidence

## Target baselines

The deltas were derived from locally preserved, untouched stock aircraft
files. No complete upstream file is distributed by this repository.

| Baseline | File | Source SHA-256 | Installed SHA-256 |
|---|---|---|---|
| Zibo B737-800X 4.05.35 | `B738.a_fms.lua` | `ff313b0e88c62845ad1c4a2b1f4bd599f57d8799e8d6707bfc10a3369fd63a8e` | `35e7641e56ce0bcbb29673bf83583ea1052252bfd98539d031a1177d7d876149` |
| LevelUp 737NG Series V2.S1.50 | `B738.a_fms.lua` | `757057120c2953a9cdefbfebcd593bdb4fd9636721328fb1ce6d6550f8f49384` | `b45b173bff71ef535d244014cff1f4871553b02c2721ac746c12bf96a82377ae` |

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

All 22 replacements are owned by `B738.a_fms.lua`: five behavior fixes, two
`PROCEED DIRECT TO` parser fixes, 12 one-line LSK hooks (PREV/NEXT need none: the
pages set `max_page_buf`),
the display overlay hook, the `dlnk_in_use` hook and the page module
(`src/cpdlc_patch_module.lua`, inserted before `B738_fmc_disp_capt()`). Every
old block occurs exactly once in both baselines; the generator in
`tools/make_patch_payloads.py` verifies that and the idempotency of the result
before writing the payload. The module only calls stock functions and globals
that exist in both baselines (`atc_msg_shift`, `send_cpdlc`,
`find_act_route_wpt2`, `create_legs_abeam_list`, `rte_copy`, `rte_paste`,
`lat_lon_legs2/8`, `add_fmc_msg`, `null_fmc_disp`, `reset_fmc_pages`).

## Reference implementation

The behaviors mirror the verified C++ fixes in the WahlthoMod plugin
(`zibomod/fms.inc`, review of 2026-09-09): response attribute default,
STANDBY persistence and prompt gate, uplink abort timer and the datalink menu
ATC prompt.
