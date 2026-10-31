---
id: Z-339
title: Rotate OpenObserve logs daily
status: Done
assignee: []
created_date: 2026-09-03 13:31
updated_date: '2026-10-31T22:44:00Z'
labels:
  - agent-reported
  - friction
dependencies: []
priority: medium
ordinal: 214895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Resolved storage-hygiene issue. The OpenObserve service log exceeded 100 MB between weekly rotations: it measured 164,076,086 bytes on 2026-10-31. The shared `com.zdots.log-rotate` LaunchAgent now runs daily at 03:15. Rotation compresses and preserves the previous log, truncates the active file in place, and prunes archives older than 30 days. The repeated-ingest-rejection hypothesis from the original report was not investigated; this change controls log growth without claiming to fix its source.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 OpenObserve logs rotate daily at 03:15 using the existing in-place gzip rotation path.
- [x] #2 Compressed rotations retain the existing 30-day pruning policy; OpenObserve remains healthy after rotation.
- [x] #3 Storage hygiene docs describe the schedule and safe manual procedure.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 LaunchAgent plist validates and launchctl shows a daily 03:15 calendar trigger.
- [x] #2 tests/log_rotate.bats passes and the produced archive validates as gzip with the original file retained.
- [x] #3 Storage-hygiene documentation and task evidence are committed.
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
At investigation, openobserve.log had grown to 164,076,086 bytes since the weekly rotation. Manual log-rotate preserved a gzip archive of 14,467,908 bytes and truncated the active file; OpenObserve remained healthy. Updated com.zdots.log-rotate to daily 03:15. Other configured log files observed were at or below 7.2 MB. launchctl print confirms Hour=3, Minute=15 with no Weekday restriction; installed plist matches tracked source. plutil -lint passed; tests/log_rotate.bats passed 11/11.

Historical report (2026-09-03): `zdots-doctor` warned at 106 MB; manual rotation produced a 9 MB compressed archive. The report estimated roughly 26 MB/day and proposed noisy rejected-span logging as a possible cause. That cause remains unverified; no log content was inspected in this audit.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Raised service log rotation cadence from weekly to daily at 03:15 after live evidence showed OpenObserve reached 164 MB between runs. The original log remains available as a verified gzip archive, active logging continues without service restart, and the existing 30-day archive pruning remains unchanged.
<!-- SECTION:FINAL_SUMMARY:END -->
