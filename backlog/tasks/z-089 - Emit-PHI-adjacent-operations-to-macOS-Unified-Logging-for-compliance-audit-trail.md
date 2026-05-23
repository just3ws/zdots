---
id: Z-089
title: >-
  Emit PHI-adjacent operations to macOS Unified Logging for compliance audit
  trail
status: To Do
assignee: []
created_date: '2026-05-23 01:20'
labels:
  - phi
  - security
  - audit
  - macos
  - observability
milestone: m-5
dependencies:
  - Z-077
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
OTel spans are excellent for observability but depend on the local LGTM stack being up. macOS Unified Logging is always-on, system-level, queryable by MDM and compliance tooling, and cannot be cleared without root. Every PHI-adjacent operation should emit a structured log entry to the unified log under the zdots subsystem — this is the compliance audit trail that survives OTel being down.\n\nEvents to log: zdots_ai_gate triggered (mode=none), zdots_assert_local_endpoint called (pass/fail + endpoint), zdots-ctx capture invoked (enabled/disabled, bytes written), boundary violation attempts. The `log` CLI writes entries; `log stream --predicate` reads them back.\n\nThis is additive to OTel, not a replacement. The unified log is the always-on floor; OTel is the rich observability layer.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 lib/audit_log.bash provides zdots_audit_log <event> <details> function that writes to macOS Unified Logging via `log` CLI on darwin, no-ops silently on non-darwin
- [ ] #2 Subsystem: com.zdots, category: phi-boundary
- [ ] #3 Events emitted: ai_gate_triggered, endpoint_assertion_pass, endpoint_assertion_fail, capture_invoked, capture_blocked, boundary_violation
- [ ] #4 ai_boundary.bash sources audit_log.bash and emits events at gate/assertion call sites
- [ ] #5 zdots-ctx capture emits capture_invoked or capture_blocked event
- [ ] #6 `log show --predicate 'subsystem == "com.zdots"' --last 1h` returns structured entries
- [ ] #7 zdots-ctl check includes a one-line audit log verification: last entry is readable
- [ ] #8 AGENTS.md and SETUP.md document how to query the audit log
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
