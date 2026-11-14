---
id: Z-368
title: >-
  Investigate leveraging Oh-My-Pi (zomp) alongside Claude Code and local LLM on
  work machine
status: To Do
assignee: []
created_date: '2026-11-14T23:12:00Z'
labels:
  - ai
  - omp
  - work
dependencies: []
priority: medium
ordinal: 245895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After pulling zdots and adots on the work machine, verify ZDOTS_CONTEXT=work boundaries, test zomp strictly-local (--offline against llama.cpp), evaluate employer-sanctioned gateway options (ZDOTS_WORK_AI_GATEWAY_URL / NODE_EXTRA_CA_CERTS), and test omp --from-claude session import.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zomp -p works strictly local against 127.0.0.1:11500/v1 on ZDOTS_CONTEXT=work
- [ ] #2 zomp --hybrid and omp-gateway-ctl import-keychain fail closed on ZDOTS_CONTEXT=work
- [ ] #3 Document corporate gateway findings in OMP.md or .zdots.local.example
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
