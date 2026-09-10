# Changelog

## 1.1.0

- Toolkit-compatible package layout: the 14 insertions (12 LSK hooks, the
  `dlnk_in_use` hook and the FANS pages module) are `insert-marked-block-v1`
  blocks with unique begin/end markers; the eight real replacements stay
  `exact-text-replacements-v1`. One pipeline of 15 operations on
  `B738.a_fms.lua`.
- `dlnk_in_use` hook is idempotent (`if cpdlc_patch_page ~= 0 and
  dlnk_in_use == 0 then dlnk_in_use = 1 end`).
- Standalone installer: per-file operation pipelines, marked-block support,
  and in-place upgrade of a 1.0.0 installation (its unmarked hook lines are
  replaced by marked blocks; the result equals a fresh installation).
- No functional change to the pages.

## 1.0.0

- Boeing FANS ATC INDEX layout (EMERGENCY, POS REPORT, REQUEST, WHEN CAN WE,
  REPORT, FREE TEXT, LOG, LOGON/STATUS, VOICE).
- New pages WHEN CAN WE, REPORT, POSITION REPORT, EMERGENCY, VOICE with a
  shared VERIFY/SEND page and DO-258A downlink texts; reachable from the ATC
  INDEX, the DLK ATC MENU and the CPDLC REPORTS/REQUESTS menu.
- CMU request page 2: BLOCK altitude, HEADING, OFFSET, WEATHER DEVIATION,
  AT PILOTS DISCRETION; DO-258A request texts (CLIMB TO / DESCENT TO, KT, M.xx).
- Loadable PROCEED DIRECT TO clearances on the CMU/DLK message page; fixed
  ident parsing (stock stored "TO") and armed intercept course for the stock
  ATC-page LOAD.
- Fixes from 0.1.0: response attribute default, STANDBY status and prompt,
  no automatic abort of unanswered uplinks, ATC prompt on the datalink menu.

## 0.1.0

- Unknown or empty CPDLC response attribute means no response required.
- STANDBY is kept as the message status until the final response.
- STANDBY stays selectable on the CMU message page until it has been sent.
- No automatic ABORTED status for unanswered ATC uplinks; unanswered crew
  requests still expire.
- ATC prompt on the DLNK-APPLICATION MENU when CPDLC is FANS.
