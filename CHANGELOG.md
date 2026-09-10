# Changelog

## 0.1.0

- Unknown or empty CPDLC response attribute means no response required.
- STANDBY is kept as the message status until the final response.
- STANDBY stays selectable on the CMU message page until it has been sent.
- No automatic ABORTED status for unanswered ATC uplinks; unanswered crew
  requests still expire.
- ATC prompt on the DLNK-APPLICATION MENU when CPDLC is FANS.
- Baselines: Zibo 4.05.35, LevelUp V2.S1.50.
