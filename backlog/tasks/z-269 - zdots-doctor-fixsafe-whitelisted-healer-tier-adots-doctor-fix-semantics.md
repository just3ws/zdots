---
id: Z-269
title: >-
  zdots-doctor --fix=safe: whitelisted healer tier (adots-doctor --fix
  semantics)
status: To Do
assignee: []
created_date: '2026-08-01 09:56'
labels:
  - enhancement
  - audit-filed
dependencies: []
priority: medium
ordinal: 145895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Doctor already knows 34 fixes as printed _fix() strings (zdots-update-local, zdots-index-tools --force, log-rotate <svc>, zsvc start colima, llama-ctl install, imperial-date > VERSION). adots-doctor --fix establishes the pattern: mutate-by-default off, repair only enumerated safe drift, fail rather than guess.

Safe tier (idempotent, local, PHI-inert): config regen, cache rebuild, log rotation over threshold, embed model re-download+sha256 when no live fd holds it, launchctl bootstrap of tracked-but-unloaded plists. One attempt per item, re-probe after. MUST stay report-only: FileVault, ZDOTS_AI_MODE, encryption keys, openobserve reinit (wipes telemetry), phi-patterns, deny-list, adots work-tree reverts, scrub/collector restarts mid-flight. Include the tripwire increment: after evidence snapshot, run ZDOTS_AI_PROFILE=embed llama-ctl model-download + log sha256 (detector→healer). (2026-08-01 system audit, selfheal — verified)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
