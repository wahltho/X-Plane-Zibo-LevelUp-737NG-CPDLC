# CPDLC fixes for Zibo and LevelUp 737NG

This unofficial source patch corrects five CPDLC/ACARS behaviors in the stock
FMS datalink pages of supported Zibo and LevelUp 737NG aircraft. It does not
contain complete Zibo, LevelUp or X-Plane aircraft files and does not modify
`zibomod.xpl`, the tablet or the Hoppie transport plugin.

## Behavior

1. **Response attribute default.** An uplink whose `/data2/` response field is
   empty or unknown is stored as *no response required*. Stock code treats it
   as *response required* (WILCO/UNABLE prompts, 100 s timer, ABORTED).
   `Y` still means *response required*.
2. **STANDBY status.** After sending STANDBY the message keeps status
   `STANDBY` instead of falling back to `OPEN`, until WILCO, UNABLE, ROGER,
   AFFIRM or NEGATIVE is sent.
3. **STANDBY prompt.** On the CMU message page the `STANDBY=` prompt stays
   available until STANDBY has been sent. Stock code hid it for every viewed
   message.
4. **No automatic abort of uplinks.** An unanswered ATC uplink stays `OPEN`
   with the ATC MSG cue on, as on the real aircraft. Only a crew request that
   ATC never answered still expires after its 270 s timer.
5. **ATC prompt on the DLNK-APPLICATION MENU** when CPDLC is `FANS`, so the
   ATC pages are reachable on a CDU without an ATC key.

Everything else, including the Hoppie transport, the tablet options and all
other datalink pages, keeps the stock behavior. The larger FANS 1/A page set
(WHEN CAN WE, REPORT, EMERGENCY, VOICE, POSITION REPORT, DO-258A request
texts, loadable DIRECT TO clearances) is planned for later releases.

## Supported baselines

- Zibo B737-800X 4.05.35 for X-Plane 12
- LevelUp 737NG Series V2.S1.50 for X-Plane 12

LevelUp V2.S1 has no CPDLC implementation and is not supported. Other
revisions are accepted when every owned block still matches exactly; unrelated
local changes elsewhere in `B738.a_fms.lua` are preserved. See `SOURCE.md`
for the baseline hashes.

## Install

Close X-Plane, then run from the unpacked release folder:

```bash
python3 z_Install.py check --aircraft-root "/path/to/B737-800X"
python3 z_Install.py install --aircraft-root "/path/to/B737-800X"
```

Use the LevelUp aircraft root for LevelUp. On Windows use `py` or `python`.
Restart X-Plane afterwards. `verify` and `uninstall` are available as well;
uninstall restores only the owned blocks and keeps unrelated changes.

The package is Toolkit-compatible (`compatibilityPackage`, manifest schema 3)
and can be installed through the X-Plane 737NG Maintenance Toolkit when it is
listed in its catalog.

## Tests

`python3 -m unittest` runs the package contract tests. Set `ZIBO_40535_ROOT`
and `LEVELUP_V2S150_ROOT` to untouched stock aircraft roots to run the
install/verify/uninstall integration tests. A Lua 5.1 compiler (`luac5.1`),
when available, syntax-checks the patched script.

## Runtime verification

The patch author cannot test the Lua result in the simulator. The behaviors
are ports of verified C++ fixes from the WahlthoMod plugin. `RUNTIME_TEST_PLAN.md`
lists the checks a tester should run with a Hoppie CPDLC controller.
