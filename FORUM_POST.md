# Suggested forum post

## Experimental CPDLC / FANS pages patch for Zibo and LevelUp – testers wanted

This experimental source patch extends the stock CPDLC/ACARS datalink pages of
the Zibo B737-800X 4.05.35 and the LevelUp 737NG V2.S1.50 with the FANS 1/A
page set and fixes a few datalink behaviors. It works with the existing Hoppie
transport (YAL HoppieHelper or the internal bridge of a modified plugin) and
any CPDLC-capable controller client on VATSIM or IVAO.

**What it adds**

- ATC INDEX in the Boeing FANS layout: `<EMERGENCY POS REPORT>`,
  `<REQUEST WHEN CAN WE>`, `<REPORT FREE TEXT>`, `<LOG MONITOR>`,
  `<LOGON/STATUS VOICE>`. The same pages are reachable from the DLK ATC MENU
  and the CPDLC REPORTS/REQUESTS menu, so the standard CDU works as well.
- New pages: WHEN CAN WE, REPORT, POSITION REPORT (filled from the active
  route), EMERGENCY (MAYDAY / PAN PAN, descending, diverting, offsetting,
  fuel/souls, cancel), VOICE (request voice contact). Each downlink is shown
  on a VERIFY page before SEND.
- Request page 2 on the CMU layout: BLOCK altitude, HEADING, OFFSET, WEATHER
  DEVIATION, AT PILOTS DISCRETION. Request texts follow DO-258A
  (`REQUEST CLIMB TO FL350`, `REQUEST DESCENT TO 10000 FT`, `REQUEST 250 KT`,
  `REQUEST M.78`, `REQUEST DIRECT TO XXXXX`, `REQUEST HEADING 270`, ...).
- Loadable `PROCEED DIRECT TO` clearances on the CMU/DLK message page
  (`=LOAD` / `LOAD>`): the direct-to goes into the active route like a LEGS
  1L entry, then EXEC and WILCO.

**What it fixes**

- An uplink with an empty or unknown response attribute no longer demands a
  WILCO/UNABLE answer.
- STANDBY keeps the message in STANDBY until the final answer and stays
  selectable until it has been sent.
- An unanswered ATC uplink stays OPEN with the ATC MSG cue on; it is no longer
  auto-ABORTED after 100 seconds (real FANS has no such timer).
- `<ATC` on the DLNK-APPLICATION MENU when CPDLC is set to FANS, so the ATC
  pages are reachable on a CDU without an ATC key.
- `PROCEED DIRECT TO <fix>` uplinks now store the fix (stock stored the word
  `TO`), and the stock ATC-page LOAD now arms the intercept course in flight.

Only the stock `B738.a_fms.lua` is patched. No complete aircraft file, no
modified `zibomod.xpl`, no change to the tablet or the Hoppie plugin.

**Why I need testers**

I fly a private C++ port of the FMS, so I cannot run the stock Lua result in
the simulator myself. The behaviors are ports of a reviewed and flown C++
implementation, and the Lua result is syntax-checked and structurally
verified against both stock baselines, but nobody has flown it yet. If you
fly CPDLC with a Hoppie logon and a controller who runs a CPDLC client, I
would appreciate feedback against the 15-step test plan in
`RUNTIME_TEST_PLAN.md`, in particular: requests and their wording as seen by
the controller, STANDBY then WILCO, an unanswered uplink after two minutes,
POSITION REPORT with an active route, and LOAD of a direct-to clearance
followed by EXEC.

**Where to get it**

- GitHub: https://github.com/wahltho/X-Plane-Zibo-LevelUp-737NG-CPDLC
  (release v1.1.0). Unpack, close X-Plane, then
  `python3 z_Install.py check --aircraft-root "<aircraft folder>"` and
  `python3 z_Install.py install ...`. The installer validates every owned
  block, keeps a backup and offers `verify` and `uninstall`; unrelated local
  changes in the file are preserved.
- X-Plane 737NG Maintenance Toolkit: listed as the optional catalog module
  `CPDLC FANS PAGES`. Enable it in the Toolkit; it installs, verifies and
  removes the patch through the same structural checks.

Supported: Zibo 4.05.35 and LevelUp V2.S1.50 for X-Plane 12. LevelUp V2.S1
has no CPDLC code and is not supported. Other revisions install only when
every owned block still matches exactly.

Please report findings as GitHub issues or here in the thread, with the
message text as shown on the CDU and, if possible, the controller's view.

This is an unofficial patch and is not supported by Zibo, LevelUp, Hoppie or
Laminar Research.
