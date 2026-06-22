---
id: Z-172
title: AI/observability stack evaluation itinerary
status: To Do
assignee: []
created_date: '2026-06-22 18:25'
labels:
  - epic
  - ai-stack
  - eval
dependencies: []
priority: medium
ordinal: 63890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Sequenced evaluation of SOTA upgrades to the local-first AI + observability stack, ordered by dependency and leverage. Eval harness (Z-133) is the measuring instrument the retrieval/inference stations depend on; observability and the PHI layer are independent tracks. Cloud-touching or content-capturing tools are evaluated on HOME first; work-machine PHI-pipeline changes are operator-coordinated (AGENTS.md §5). Source itinerary doc retained in session scratchpad.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
