---
id: Z-031
title: >-
  Z-031 - Optimize shell performance by eliminating redundant forking in
  observability hooks
status: In Progress
assignee:
  - mike
created_date: '2026-04-04 15:15'
updated_date: '2026-04-14 21:19'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current observability hooks (`preexec`, `precmd`, `chpwd`) and shell initialization scripts contain multiple redundant calls to external binaries (`date`, `sed`, `echo`, `openssl`, `uptime`, `awk`, `yq`). This results in 10+ process forks for every command executed, significantly impacting shell responsiveness and startup time, violating the "Dwight Schrute principle" of performance-conscious engineering. The task is to replace these external calls with Zsh built-ins, parameter expansion, or cached values where possible.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Replace `date` calls in `zdots_trace_log` and `zdots_trace_redact` with Zsh `$strftime` (requires `zsh/datetime`).
- [ ] #2 Replace `sed` and `echo` forks for string escaping/redaction in `zdots_trace_log` and `zdots_trace_redact` with Zsh parameter expansion (e.g., `${var//search/replace}`).
- [ ] #3 Replace `openssl` or `date` forks for `ZDOTS_SPAN_ID` generation with Zsh-native random string generation.
- [ ] #4 Replace synchronous `uptime` and `awk` calls in `conf.d/05-observability.zsh` with a backgrounded or cached load-average capture mechanism.
- [ ] #5 Implement caching for the `yq` model-resolution call in `providers/ai/ollama.zsh` to avoid forking on every shell start.
- [ ] #6 Ensure that the number of forks per command execution (preexec/precmd) is reduced from ~10+ to 0-2 (excluding optional backgrounded telemetry).
- [ ] #7 Verify that all existing observability and security tests in `tests/observability.bats` and `tests/security.bats` pass after the optimization.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output
- [ ] #2 file path
- [ ] #3 or test result)
- [ ] #4 make check passes with output captured in task notes or commit message
- [ ] #5 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
