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
| 7 | Uninstall, repeat 1 and 4 | Stock behavior returns (prompts on unknown rsp, ABORTED after 100 s). |
