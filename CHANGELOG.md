# Changelog

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
