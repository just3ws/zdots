---
id: Z-130
title: Shrink the AI Invocation Interface — stop leaking via env vars
status: To Do
assignee: []
created_date: '2026-06-05 19:58'
labels:
  - architecture
  - refactor
dependencies: []
priority: medium
ordinal: 21890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Architecture candidate #5 (Worth exploring). The AI Invocation Interface's real contract is undocumented env vars and a thrice-asserted gate.

Files: lib/ai-invoke.bash, lib/ai-query-lib.bash, lib/ai_boundary.bash, bin/ai-query

Problem: zdots_ai_distill/zdots_ai_infer_raw coordinate behaviour (AIQ_TEMPERATURE, AIQ_ENABLE_THINKING, AIQ_SUPPRESS_RAW_WARN) by exporting env vars read four frames down in aiq_submit; the locality+gate check fires three times (bin/ai-query, zdots_ai_infer_raw, aiq_submit). The seam is wider than its signature admits.

Solution: promote temperature/thinking to parameters of the interface; assert the gate once. Everything a caller must know moves into the signature.

Wins: interface shrinks to what is true, locality (one gate assertion), testable without env mutation, deletes the AIQ_SUPPRESS_RAW_WARN coupling.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 temperature and thinking are explicit parameters, not exported env vars
- [ ] #2 the gate/locality check is asserted at exactly one layer
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
