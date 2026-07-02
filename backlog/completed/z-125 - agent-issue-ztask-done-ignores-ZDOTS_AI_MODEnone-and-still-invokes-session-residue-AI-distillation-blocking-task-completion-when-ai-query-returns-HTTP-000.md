---
id: Z-125
title: >-
  [agent-issue] ztask done ignores ZDOTS_AI_MODE=none and still invokes session
  residue AI distillation, blocking task completion when ai-query returns HTTP
  000
status: Done
assignee: []
created_date: '2026-06-02 12:43'
updated_date: '2026-06-15 13:07'
labels:
  - agent-reported
  - bug
  - wave2
dependencies:
  - Z-130
priority: medium
ordinal: 16890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `55c70b2536106cad751d6d4e31f23023`

ztask done ignores ZDOTS_AI_MODE=none and still invokes session residue AI distillation, blocking task completion when ai-query returns HTTP 000

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Root cause: cmd_done called 'zdots-ctx capture' unconditionally; inside it zdots_ai_gate does exit 2 when ZDOTS_AI_MODE=none, and under ztask's 'set -eo pipefail' that propagated and aborted cmd_done before the active-task file cleared (same for ai-query HTTP 000). Fix (single gate in bin/ztask cmd_done): _set_task_status Done runs unconditionally; distillation is best-effort — skipped entirely when ZDOTS_AI_MODE=none, and on capture failure logs a non-fatal warning and continues. Completion is never gated on AI. Tests: tests/ztask_e2e.bats 6/6 (new T4 mode=none → no capture call + completes; T5 capture failure → warning + completes). secret-scan OK. Commit 636499e. Operator-defined ACs (task had none). Minor follow-up: uses /tmp/...$$ for transient stderr capture rather than the repo _mktmp helper — low risk, single-user box, file removed immediately. (sonnet worktree fan-out, diff-reviewed.)
<!-- SECTION:FINAL_SUMMARY:END -->
