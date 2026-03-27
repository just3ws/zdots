---
id: Z-009
title: Harden Security of Shell Observability and State
status: To Do
assignee: []
created_date: '2026-03-27 14:10'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Address local information leaks and improve environment security. This includes restricting permissions on trace/history files and ensuring that sensitive command-line arguments are handled more carefully in the observability stack.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Restrict XDG_STATE_HOME/zsh to 700
- [ ] #2 Ensure history and trace files are created with 600 permissions
- [ ] #3 Set a more restrictive umask (077) during startup
- [ ] #4 Add sensitive argument filtering to zdots_trace_log (e.g., masking common password flags)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
