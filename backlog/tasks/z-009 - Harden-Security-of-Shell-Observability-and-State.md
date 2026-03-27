---
id: Z-009
title: Harden Security of Shell Observability and State
status: In Progress
assignee:
  - '@myself'
created_date: '2026-03-27 14:10'
updated_date: '2026-03-27 14:10'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. **Restrict State Directory**: Update `env.sh` or `providers/trace/local.zsh` to ensure `XDG_STATE_HOME/zsh` is created with `700` permissions.
2. **Harden umask**: Set `umask 077` early in `env.sh` to ensure all files created by the shell (caches, logs, history) are restricted by default.
3. **Sensitive Data Masking**: Update `zdots_trace_log` in `providers/trace/local.zsh` and `otlp.zsh` to perform basic redaction of common sensitive command-line flags (e.g., `-p`, `--password`, `--api-key`).
4. **Audit and Validate**: Use `bin/check` or a new Bats test to verify that logs and state directories have the correct permissions.
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
