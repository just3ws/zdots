---
id: Z-182
title: >-
  [agent-issue] zdots-ctx migrate ignores --help and runs ALL pending migrations
  — 'zdots-ctx migrate --help' applie
status: To Do
assignee: []
created_date: '2026-06-30 12:14'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 78890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `5a34494e2b29252e0fe90e44150a466e`

zdots-ctx migrate ignores --help and runs ALL pending migrations — 'zdots-ctx migrate --help' applied a PHI-encryption migration that was meant to be held. Fix: honor --help (print usage, don't migrate) and add --to <version> for targeted single-migration apply.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
