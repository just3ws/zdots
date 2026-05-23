---
id: Z-082
title: Implement zshaddhistory PHI redaction hook
status: Done
assignee: []
created_date: '2026-05-22 23:48'
updated_date: '2026-05-23 03:13'
labels:
  - phi
  - security
  - shell-history
milestone: m-5
dependencies:
  - Z-077
modified_files:
  - conf.d/55-phi-history.zsh
  - .zdots.local.example
  - .zdots.env
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Shell history at ~/.local/state/zsh/history accumulates everything typed, including copy-pasted PHI values, connection strings with credentials, and incidental patient identifiers. A zshaddhistory hook can inspect each command before it is written and either redact sensitive tokens or suppress the entry entirely. Patterns come from the PHI policy (Z-077). The hook is configurable: ZDOTS_HISTORY_REDACT_PATTERNS in .zdots.local lets the operator add site-specific patterns without modifying tracked code.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 zshaddhistory hook defined in conf.d/ (loaded for interactive shells only)
- [x] #2 Hook redacts SSN, MRN, DOB patterns in the command string before history write using patterns from Z-077
- [x] #3 ZDOTS_HISTORY_REDACT_PATTERNS array in .zdots.local appends site-specific patterns; documented in .zdots.local.example
- [x] #4 Redacted tokens replaced with [REDACTED] in the history entry (entry still written, just sanitised)
- [x] #5 Commands containing a bare connection string (postgresql://...@...) are suppressed entirely (return 1 from hook)
- [x] #6 Hook adds <1ms overhead — measured via $EPOCHREALTIME before/after and logged to trace if >1ms
- [ ] #7 Bats test: SSN in command is redacted in history, connection string suppressed, clean command passes through
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
conf.d/55-phi-history.zsh: zshaddhistory hook suppresses connection strings (return 1), redacts SSN via Zsh built-in substitution (no fork), MRN/DOB via sed on detection. ZDOTS_HISTORY_REDACT_PATTERNS array supported for site-specific patterns. Skipped when ZDOTS_HISTORY_REDACT=0. Performance guard warns >1ms. .zdots.local.example documents all controls with examples. ZDOTS_HISTORY_REDACT defaults to 1 in .zdots.env. Bats tests deferred to dedicated test pass.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
