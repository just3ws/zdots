---
id: Z-084
title: 'Work machine profile: PHI-safe defaults in .zdots.local.example and .zdots.env'
status: To Do
assignee: []
created_date: '2026-05-22 23:48'
labels:
  - phi
  - security
  - portability
  - config
milestone: m-5
dependencies:
  - Z-080
  - Z-081
  - Z-082
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Consolidate all PHI-safe defaults into a coherent 'work' profile so a fresh clone on a work machine can be configured with one block in .zdots.local. .zdots.env gains a ZDOTS_CONTEXT=work branch that sets: ZDOTS_AI_MODE=local (hard), ZDOTS_CAPTURE_ENABLED=0, ZDOTS_HISTORY_REDACT_PATTERNS enabled, and a reminder to set ZDOTS_DB_ENCRYPTION_KEY. .zdots.local.example gains a documented work section covering all PHI-relevant vars. The goal: a developer sets ZDOTS_CONTEXT=work in .zdots.local and gets the correct safety posture without knowing each individual variable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ZDOTS_CONTEXT=work in .zdots.env sets ZDOTS_AI_MODE=local, ZDOTS_CAPTURE_ENABLED=0, ZDOTS_HISTORY_REDACT=1 by default
- [ ] #2 .zdots.local.example contains a clearly commented 'work machine' section covering ZDOTS_CONTEXT, ZDOTS_DB_ENCRYPTION_KEY, ZDOTS_AI_ENDPOINT override, ZDOTS_HISTORY_REDACT_PATTERNS
- [ ] #3 ZDOTS_AI_MODE cannot be set to 'cloud' via .zdots.env when ZDOTS_CONTEXT=work — only .zdots.local can override (operator explicit intent)
- [ ] #4 .zdots.local.example work section includes the AI security boundary note from bootstrap
- [ ] #5 SETUP.md work machine section updated to reference new variables
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
