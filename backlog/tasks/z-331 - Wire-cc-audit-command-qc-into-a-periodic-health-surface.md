---
id: Z-331
title: Wire cc-audit / command-qc into a periodic health surface
status: To Do
assignee: []
created_date: '2026-09-01 13:05'
labels:
  - agent-reported
dependencies: []
priority: low
ordinal: 206895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
zdots-heal (2026-09-01) surfaced settings.json allowlist drift (Z-328) that only /cc-audit and /command-qc catch — neither runs on any cadence. cc-doctor covers config validity but not plugin egress / allowlist scope / per-command QC drift. Fold a lightweight cc-audit check into zdots-doctor (or a weekly cron) so this drift is caught automatically instead of only during a manual heal run.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zdots-doctor (or a scheduled job) runs a cc-audit/command-qc drift check and reports WARN on new drift
- [ ] #2 Does not hard-fail doctor — advisory only
- [ ] #3 Documented in the doctor detector list
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
