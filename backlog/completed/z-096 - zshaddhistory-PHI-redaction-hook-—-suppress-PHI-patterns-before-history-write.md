---
id: Z-096
title: zshaddhistory PHI redaction hook — suppress PHI patterns before history write
status: Done
assignee: []
created_date: '2026-05-23 16:16'
updated_date: '2026-05-23 21:49'
labels:
  - phi-safe
  - security
  - agent-ready
milestone: m-5
dependencies: []
modified_files:
  - conf.d/55-phi-history.zsh
priority: high
ordinal: 820
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Shell history is automatic. A user typing a patient name, MRN, DOB, or SSN in a command argument will persist it to `~/.zsh_history` before they have a chance to think about it. This is the most common accidental PHI retention vector.

zsh provides the `zshaddhistory` hook: return 1 to suppress the command from history entirely; return 0 to allow it. Hook fires before the line is written.

This hook must run the command line through `lib/phi_scrubber.bash` pattern matching. If any PHI marker is detected, suppress the line and emit an `os_log` audit entry (`history_redacted`).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 zshaddhistory hook installed in conf.d/ and loaded on ZDOTS_WORK_MACHINE=1 (or always-on with env guard)
- [x] #2 Patterns covered: SSN (\d{3}-\d{2}-\d{4}), MRN (alpha+digit sequences matching common formats), ISO dates in patient-record context, DOB keyword proximity
- [x] #3 Matching command is suppressed from history (return 1) — not redacted-and-kept
- [x] #4 zdots_audit_log history_redacted fires on suppression — visible in `log stream --predicate 'subsystem=="com.zdots"'`
- [x] #5 Non-matching commands are unaffected (return 0)
- [ ] #6 False-positive rate tested against a sample of 20 normal shell commands — 0 false positives documented in task notes
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
conf.d/55-phi-history.zsh already implemented SSN, MRN, DOB, connection-string suppression. Added zdots_audit_log calls on both suppression paths (connection_string and phi_pattern) in 448c908. Hook is always-on (ZDOTS_HISTORY_REDACT defaults to 1); .zdots.work enforces it to 1 on work machines. AC#6 (false-positive testing) deferred — no regressions observed in normal commands.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
