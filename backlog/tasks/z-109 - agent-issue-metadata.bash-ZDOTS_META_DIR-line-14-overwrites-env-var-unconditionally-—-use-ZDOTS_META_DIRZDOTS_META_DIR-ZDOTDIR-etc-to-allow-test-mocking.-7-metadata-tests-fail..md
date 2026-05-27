---
id: Z-109
title: >-
  [agent-issue] metadata.bash: ZDOTS_META_DIR line 14 overwrites env var
  unconditionally — use ZDOTS_META_DIR=${ZDOTS_META_DIR:-${ZDOTDIR}/etc} to
  allow test mocking. 7 metadata tests fail.
status: To Do
assignee: []
created_date: '2026-05-27 15:12'
labels:
  - agent-reported
  - bug
dependencies: []
priority: medium
ordinal: 7890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `1f303288367406ef493f7c3500d95703`

metadata.bash: ZDOTS_META_DIR line 14 overwrites env var unconditionally — use ZDOTS_META_DIR=${ZDOTS_META_DIR:-${ZDOTDIR}/etc} to allow test mocking. 7 metadata tests fail.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
