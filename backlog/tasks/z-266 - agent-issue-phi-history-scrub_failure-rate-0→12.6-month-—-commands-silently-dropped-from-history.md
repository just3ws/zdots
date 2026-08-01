---
id: Z-266
title: >-
  [agent-issue] phi-history scrub_failure rate 0→12.6%/month — commands silently
  dropped from history
status: To Do
assignee: []
created_date: '2026-08-01 09:56'
updated_date: '2026-08-01 16:20'
labels:
  - agent-reported
  - error
  - audit-filed
dependencies: []
priority: high
ordinal: 142895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
shell_hook_metrics (3,982 rows May 28–Aug 1): clean 3,769, scrub_failure 188, redacted 25. Monthly failure trend: May 0/402, June 88/2,771 (3.2%), July 100/794 (12.6%). Failures avg 5.4ms vs 29ms clean — early abort in the scrub path, not a slow regex. A failed scrub on this machine drops the command from history entirely (history file unusually thin: 59KB/1,411 lines). Both a UX bug (lost history) and an unwatched PHI-pipeline health signal.

Diagnose: what input class makes zdots-phi-scrub exit 1 — reproduce via audit log (log show subsystem com.zdots, history_suppressed reason=scrub_failure). Decide drop-vs-passthrough semantics deliberately. Add doctor/cc-doctor check alerting when scrub_failure >2% over 7 days. (2026-08-01 system audit, usage+perf)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Diagnosis agent spend-limit-killed mid-investigation 2026-08-01. Partial finding preserved: scrub_failure entries BEGIN 2026-06-16 — next step is dating the suspect phi-pattern/hook commits around that date and checking burst-vs-steady session patterns. Re-run diagnosis when budget resets; treat as PHI-pipeline incident per L5.
<!-- SECTION:NOTES:END -->
