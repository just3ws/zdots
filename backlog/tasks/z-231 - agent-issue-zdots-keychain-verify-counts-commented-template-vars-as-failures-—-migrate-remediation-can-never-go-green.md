---
id: Z-231
title: >-
  [agent-issue] zdots-keychain verify counts commented template vars as failures
  — migrate remediation can never go green
status: To Do
assignee: []
created_date: '2026-07-15 19:02'
labels:
  - agent-reported
  - friction
dependencies: []
priority: low
ordinal: 110895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** friction
**Severity:** low
**Trace ID:** `64fc7ae163a5227411ce047015e86825`

The doctor remediation says 'zdots-keychain migrate && zdots-keychain verify, then delete the file'. But verify parses variable names out of COMMENTED template lines in .zdots.secrets (8 of 10 'missing' vars were '# VAR=...' examples; only 2 active assignments existed, both migrated OK). So verify exits 1 on a healthy migration and the remediation instruction can never be satisfied as written. Expected: verify should only consider active (non-comment) assignments, or split reporting into required vs template vars. Evidence: grep -cE '^\s*(export\s+)?[A-Z_]+=' on the file returned 2; verify reported 2 present / 8 missing.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
