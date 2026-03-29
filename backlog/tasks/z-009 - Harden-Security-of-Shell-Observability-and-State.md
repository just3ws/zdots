---
id: Z-009
title: Harden Security of Shell Observability and State
status: Done
assignee:
  - '@myself'
created_date: '2026-03-27 14:10'
updated_date: '2026-03-29 03:09'
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
- [x] #1 Restrict XDG_STATE_HOME/zsh to 700
- [x] #2 Ensure history and trace files are created with 600 permissions
- [x] #3 Set a more restrictive umask (077) during startup
- [x] #4 Add sensitive argument filtering to zdots_trace_log (e.g., masking common password flags)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. **Restrict State Directory**: Update `env.sh` or `providers/trace/local.zsh` to ensure `XDG_STATE_HOME/zsh` is created with `700` permissions.
2. **Harden umask**: Set `umask 077` early in `env.sh` to ensure all files created by the shell (caches, logs, history) are restricted by default.
3. **Sensitive Data Masking**: Update `zdots_trace_log` in `providers/trace/local.zsh` and `otlp.zsh` to perform basic redaction of common sensitive command-line flags (e.g., `-p`, `--password`, `--api-key`).
4. **Audit and Validate**: Use `bin/check` or a new Bats test to verify that logs and state directories have the correct permissions.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Hardened the security of the Zdots control plane and observability stack. 1. Restricted XDG_STATE_HOME/zsh to 700 and traces.jsonl to 600. 2. Set umask 077 early in env.sh to ensure all created files are user-only by default. 3. Implemented a zdots_trace_redact helper to mask sensitive command-line flags (e.g., --password) in both local and OTLP telemetry. 4. Added tests/security.bats to verify these protections in the regression suite.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
