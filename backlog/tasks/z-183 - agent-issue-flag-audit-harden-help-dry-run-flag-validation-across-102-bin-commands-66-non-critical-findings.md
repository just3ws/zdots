---
id: Z-183
title: >-
  [agent-issue] flag-audit: harden --help/--dry-run/flag-validation across 102
  bin/ commands (66 non-critical findings)
status: To Do
assignee: []
created_date: '2026-06-30 14:19'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 79890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `5a34494e2b29252e0fe90e44150a466e`

Consolidated follow-up to the bin/ flag-handling static audit (the 11 CRITICAL help-side-effect findings are fixed + committed under Z-182). This tracks the remaining 66 non-critical findings: 22 HIGH (destructive/state-changing with no --dry-run or confirmation, incl. destructive verbs that act on --help), 22 MEDIUM (documented-vs-implemented drift + per-subcommand help that doesn't short-circuit), 22 LOW (missing -h alias / cosmetic help drift / silent unknown-flag handling on read-only commands). Audit dimensions: help-side-effect 13, no-dry-run 16, unknown-flag 17, flag-drift 10, missing-h 9, other 1. KEY INSIGHT: a single shared pre-dispatch helper (scan all args for -h|--help before dispatch + reject unknown flags via an explicit -*) arm before the positional catch-all) fixes the bulk of the HIGH/MEDIUM/LOW findings uniformly instead of per-script — concentrated risk is destructive verbs with no --dry-run/confirm (H1, 12 commands) and the cross-cutting 'help runs the verb' pattern (H2+M1, 14 commands). Full structured findings (JSON, result/findings) at /private/tmp/claude-502/-Users-mike-hall--config-zsh/4d0f5b89-3227-4ba8-94f4-45eba9dd9b9c/tasks/weij51wks.output ; the consolidated markdown writeup with per-command lists and suggested order of work is the audit-remainder report at /private/tmp/claude-502/-Users-mike-hall--config-zsh/4d0f5b89-3227-4ba8-94f4-45eba9dd9b9c/tasks/we9totjks.output (result[3].report).

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
