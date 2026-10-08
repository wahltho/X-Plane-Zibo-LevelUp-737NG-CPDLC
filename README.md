# CPDLC fixes for Zibo and LevelUp 737NG

This unofficial source patch corrects five CPDLC/ACARS behaviors in the stock
FMS datalink pages of supported Zibo and LevelUp 737NG aircraft. It does not
contain complete Zibo, LevelUp or X-Plane aircraft files and does not modify
`zibomod.xpl`, the tablet or the Hoppie transport plugin.

## Behavior

**Fixes to the stock pages**

1. An uplink whose `/data2/` response field is empty or unknown is stored as
   *no response required*; `Y` still requires a response.
2. STANDBY keeps the message in status `STANDBY` until the final response and
   stays selectable on the CMU message page until it has been sent.
3. An unanswered ATC uplink stays `OPEN` with the ATC MSG cue on; only a crew
   request ATC never answered expires after 270 s.
4. `<ATC` on the DLNK-APPLICATION MENU when CPDLC is `FANS`.
5. `PROCEED DIRECT TO <fix>` uplinks store the fix (stock stored the word
   `TO`), and the stock ATC-page `LOAD>` arms the intercept course in flight.

**FANS 1/A pages (DO-258A texts)**

- ATC INDEX in the Boeing FANS layout: `<EMERGENCY POS REPORT>`,
  `<REQUEST WHEN CAN WE>`, `<REPORT FREE TEXT>`, `<LOG MONITOR>`,
  `<LOGON/STATUS VOICE>`. The DLK ATC MENU and the CPDLC REPORTS/REQUESTS
  menu offer the same pages.
- WHEN CAN WE: HIGHER/LOWER ALTITUDE, CLIMB TO / DESCENT TO, BACK ON ROUTE,
  SPEED, CRUISE CLIMB TO.
- REPORT: LEAVING, LEVEL, CLIMBING TO, DESCENDING TO, PASSING, BACK ON
  ROUTE, ASSIGNED ALTITUDE, ASSIGNED SPEED, PRESENT SPEED. Present and
  assigned values come from the aircraft (FL above transition altitude).
- POSITION REPORT from the active route: overhead, time, altitude, next with
  ETA, ensuing, speed.
- EMERGENCY: MAYDAY / PAN PAN, DESCENDING TO, DIVERTING TO, OFFSETTING,
  FUEL/SOULS (`HHMM/N`), CANCEL EMERGENCY.
- VOICE: REQUEST VOICE CONTACT with optional frequency.
- Every page composes its downlink on a VERIFY page (`SEND>`); reports are
  sent without response attribute, requests with response attribute `Y`.
- CMU request page 2 (NEXT PAGE): BLOCK altitude, HEADING, OFFSET, WEATHER
  DEVIATION, AT PILOTS DISCRETION. Request texts follow DO-258A: `REQUEST
  CLIMB TO FL350`, `REQUEST DESCENT TO 10000 FT`, `REQUEST 250 KT`,
  `REQUEST M.78`, `REQUEST DIRECT TO XXXXX`, `REQUEST HEADING 270`,
  `REQUEST OFFSET 5NM LEFT OF ROUTE`, `REQUEST WEATHER DEVIATION UP TO ...`,
  modifiers `DUE TO WEATHER`, `DUE TO AIRCRAFT PERFORMANCE`,
  `AT PILOTS DISCRETION`.
- Loadable clearance on the CMU/DLK message page: `=LOAD` (CMU, LSK 5L) or
  `LOAD>` (DLK, LSK 4R) for a `PROCEED DIRECT TO` uplink loads the direct-to
  into the active route as a LEGS 1L entry would; then EXEC and WILCO.
- AOC MISC MENU `FREE TEXT>` opens a four-line message editor with an explicit
  Hoppie station, a VERIFY step and direct `telex` transmission. This path is
  independent of the active ATC logon.

The pages are available with any CMU layout (CPDLC `ATN B1` or `FANS`) as
soon as a CPDLC logon is established. The Hoppie transport, the tablet
options and `zibomod.xpl` are not changed.

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
and is listed in the X-Plane 737NG Maintenance Toolkit catalog as the optional
module `CPDLC FANS PAGES`.

## Updating

Standalone installations of 1.1.0 update directly by running `install` from
the 1.2.0 package. The installer validates the existing owned blocks, adds the
separate AOC free-text module transactionally and retains the original
uninstall contract. Maintenance Toolkit installations update normally through
the Toolkit; the additive marked block preserves other structurally managed
patches in the same FMS Lua file.

## Upgrading from 1.0.0

Run `install` from the current package: the standalone installer replaces the
unmarked 1.0.0 hook lines by marked blocks and the result equals a fresh
installation. When installing through the Maintenance Toolkit over a file that
still carries a 1.0.0 standalone installation, uninstall 1.0.0 with its own
installer first. The Toolkit engine does not remove unmarked lines; a leftover
1.0.0 hook line would be harmless at runtime (the hooks are idempotent) but
the file would not match a clean installation.

## Tests

`python3 -m unittest` runs the package contract tests. Set `ZIBO_40535_ROOT`
and `LEVELUP_V2S150_ROOT` to untouched stock aircraft roots to run the
install/verify/uninstall integration tests. A Lua 5.1 compiler (`luac5.1`),
when available, syntax-checks the patched script.

## Runtime verification

The patch author cannot test the Lua result in the simulator. The behaviors
are ports of the WahlthoMod C++ implementation, which was reviewed and
deployed. `RUNTIME_TEST_PLAN.md` lists the checks a tester should run with a
Hoppie CPDLC controller before relying on the pages in a flight.

## Installation ownership

MTK and the standalone installer remain separate supported installation methods.
Use the same owner for updates and removal. To switch, uninstall through the
current owner first, then install through the other. Neither installer adopts
already patched files on the strength of matching hashes alone.

Keep the complete extracted package, including `standalone_guard.py` and
`standalone-ownership.json`. The standalone installer checks its recorded
original backups and stops if MTK owns this patch or a shared target file.
Unknown, duplicate or incomplete patch blocks and unowned companion files also
block the operation. Other correctly installed patches are preserved.

A failed operation restores the bytes it changed. If the process is interrupted,
keep the `.patch-ownership` receipt, transaction journal and lock, together with
any older patch backup/state directory. Do not delete them to retry. Ask for
support before changing those files.

Older standalone installs without a complete receipt are not automatically
migrated. Remove them using the installer and original backups that created
them. This source change affects installation checks only; runtime payloads and
patch versions are unchanged. Installer and recovery tests cover these checks.
