---
id: Z-261
title: >-
  [agent-issue] zdots-ctx enqueue printed a stray traceback fragment ('from
  sbin/zdots-brain:1142 in <main>') after
status: To Do
assignee: []
created_date: '2026-07-24 21:56'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 137895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `38d346f51c4879ad62fa3e922070345d`

zdots-ctx enqueue printed a stray traceback fragment ('from sbin/zdots-brain:1142 in <main>') after a successful 'job enqueued (ID: ...)' message — one occurrence 2026-07-24 ~14:50 during Z-229 work, not reproducible on retry (second call hit the idempotent-skip path cleanly). Suggests an exception raised after cmd_enqueue's puts, possibly in an at_exit/shutdown hook. Low urgency; noting for pattern-matching if it recurs.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
