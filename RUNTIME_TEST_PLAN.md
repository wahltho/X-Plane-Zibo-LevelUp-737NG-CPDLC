# Runtime test plan

Prerequisites: Hoppie logon, a CPDLC-capable controller client (TopSky,
EuroScope CPDLC or the Hoppie web client), CMU enabled, CPDLC ATN B1 or FANS.

| # | Step | Expected |
|---|------|----------|
| 1 | Controller sends an uplink with an empty or unusual response attribute (e.g. free text with rsp `NE`, or a malformed `/data2/1/2//TEXT`) | Message shows without WILCO/UNABLE prompts and without ATC MSG timer; log status closes when viewed. |
| 2 | Controller sends a WU clearance; press STANDBY | Log shows `STANDBY`; the message page still offers WILCO/UNABLE; STANDBY is not offered again. |
| 3 | After step 2 send WILCO | Status becomes ACCEPTED/WILCO; controller receives WILCO with the correct MRN. |
| 4 | Leave a WU uplink unanswered for more than 100 s | Message stays OPEN, ATC MSG cue stays on; no ABORTED entry. |
| 5 | Send a request and get no answer for more than 270 s | Request entry expires (TIMEOUT/EXPIRED label) as before. |
| 6 | Tablet: CPDLC = FANS, standard CDU; MENU, DLK | `<ATC` on L2 of DLNK-APPLICATION MENU opens the ATC index. |
| 7 | ATC INDEX (CPDLC FANS) / DLK ATC MENU / CPDLC REPORTS-REQUESTS menu after logon | New prompts have arrows; each opens its page; RETURN / ATC INDEX goes back to the menu it came from; MENU key leaves the page cleanly. |
| 8 | WHEN CAN WE: press HIGHER ALT; enter `350` on CLIMB TO | VERIFY page shows `WHEN CAN WE EXPECT HIGHER ALTITUDE` / `... CLIMB TO FL350`; SEND delivers it; log entry OPEN; controller receives it. |
| 9 | REPORT: press LEVEL and PASSING without entry | Texts `LEVEL FLxxx` (present level) and `PASSING <previous waypoint>`; entries `100` and `M.78` are accepted on CLIMBING TO / ASSIGNED SPD. |
| 10 | POSITION REPORT with an active route in flight | Overhead, next with ETA and ensuing filled; VERIFY composes `POSITION REPORT OVERHEAD ... ESTIMATING ... AT ...Z NEXT ...`; without route: NO ACTIVE ROUTE. |
| 11 | EMERGENCY: MAYDAY, `100` DESCENDING TO, `EDDF` DIVERT TO, `0130/150` FUEL/SOULS, VERIFY, SEND; then CANCEL EMERGENCY | Text `MAYDAY MAYDAY MAYDAY. DESCENDING TO FL100. DIVERTING TO EDDF. 0130 OF FUEL REMAINING AND 150 SOULS ON BOARD`; CANCEL sends `CANCEL EMERGENCY` and clears the fields. |
| 12 | VOICE: `121.5` then REQUEST VOICE CONTACT | `REQUEST VOICE CONTACT 121.500`. |
| 13 | CMU request: NEXT PAGE, enter `330/350` BLOCK, `270` HEADING, `5L` OFFSET, `10R` WX DEV, toggle PILOT DISC, VERIFY | Text `REQUEST BLOCK FL330 TO FL350. REQUEST HEADING 270. REQUEST OFFSET 5NM LEFT OF ROUTE. REQUEST WEATHER DEVIATION UP TO 10NM RIGHT OF ROUTE AT PILOTS DISCRETION`; SEND clears page 1 and page 2 fields. |
| 14 | Controller sends `PROCEED DIRECT TO <fix in route>` in flight | CMU: `=LOAD` on 5L; DLK: `LOAD>` on 4R; LOAD arms a MOD with EXEC light and intercept course; after EXEC the prompt shows LOADED; WILCO closes the message. Fix not in route: UNLOADABLE CLEARANCE. |
| 15 | Uninstall, repeat 1, 4 and 7 | Stock behavior and stock menus return. |
