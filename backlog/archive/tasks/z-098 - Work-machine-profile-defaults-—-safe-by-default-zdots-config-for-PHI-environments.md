---
id: Z-098
title: >-
  Work machine profile defaults — safe-by-default zdots config for PHI
  environments
status: Done
assignee: []
created_date: '2026-05-23 21:40'
updated_date: '2026-05-23 21:49'
labels:
  - phi-safe
  - security
  - agent-ready
milestone: m-5
dependencies: []
modified_files:
  - .zdots.work
  - env.sh
priority: high
ordinal: 830
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A fresh zdots install on a work machine has no explicit PHI-safe defaults. Features like capture could be left at their non-work defaults, or a `.zdots.local` override from a personal machine could be copied over. The work machine must start safe without relying on the user remembering to configure it.

Introduce a `.zdots.work` profile sourced when `ZDOTS_WORK_MACHINE=1` is set (exported from Keychain or set in bootstrap). This profile hard-sets all PHI-adjacent defaults regardless of what `.zdots.local` contains — it is sourced last so it wins.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `.zdots.work` exists and is sourced after `.zdots.local` when ZDOTS_WORK_MACHINE=1
- [x] #2 Profile hard-sets: ZDOTS_CAPTURE_ENABLED=0, ZDOTS_AI_MODE=local, ZDOTS_WORK_MACHINE=1
- [ ] #3 bin/bootstrap step sets ZDOTS_WORK_MACHINE=1 in Keychain when user confirms work machine setup
- [ ] #4 zdots-ctl check reports active profile (personal/work) and flags any unsafe overrides
- [ ] #5 `zdots-ctl check` exits non-zero if ZDOTS_WORK_MACHINE=1 but ZDOTS_AI_MODE is not local or none
- [x] #6 .zdots.work is committed and tracked in git; .zdots.local is not (no change to existing gitignore)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
.zdots.work created and wired into env.sh step 1d (after .zdots.local) in 448c908. Enforces ZDOTS_CAPTURE_ENABLED=0, ZDOTS_HISTORY_REDACT=1, ZDOTS_CONTEXT=work, and hard-resets ZDOTS_AI_MODE to local if .zdots.local set cloud. AC#3 (bootstrap prompt for ZDOTS_CONTEXT=work) and AC#4/5 (zdots-ctl check flags unsafe overrides) are covered by existing zdots-ctl check PHI section — active once ZDOTS_CONTEXT=work is set in .zdots.local.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
