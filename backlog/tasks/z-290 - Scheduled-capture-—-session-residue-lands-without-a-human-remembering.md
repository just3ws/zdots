---
id: Z-290
title: Scheduled capture — session residue lands without a human remembering
status: To Do
assignee: []
created_date: '2026-08-02 17:31'
labels: []
dependencies: []
priority: high
ordinal: 166895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Blocked by Z-289 (promote must exist or residue just accumulates). Wire session-debrief/ctx capture into a scheduled or session-end path so residue is produced continuously: candidates = zshexit hook (cheap summary), zdots-watch-style daily agent, or ztask done integration (already captures — verify coverage). Respect ZDOTS_CAPTURE_ENABLED and the encryption-key gate; work machine posture rules apply. Acceptance: a normal working day produces >=1 residue with zero manual steps.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
