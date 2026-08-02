---
id: Z-292
title: Untrack the Go binaries — build at install (repo diet)
status: To Do
assignee: []
created_date: '2026-08-02 17:31'
labels: []
dependencies: []
priority: medium
ordinal: 168895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
bin/zdots-phi-scrub and cmd/zdots-phi-scrub/zdots-phi-scrub are 18-20MB tracked binaries (both rebuilt 2026-08-02, each rebuild adds ~20MB of history). Roadmap 90-day debt item: git rm --cached both, gitignore, add a build step (zdots-update-local phase or make target, same shape as CI zdots-secret-scan build) + a doctor check that the binary exists and answers --init. Coordinate with home machine before landing (both machines must gain the build step in the same cycle). Also eliminates the binary-swap exec-window class permanently.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
