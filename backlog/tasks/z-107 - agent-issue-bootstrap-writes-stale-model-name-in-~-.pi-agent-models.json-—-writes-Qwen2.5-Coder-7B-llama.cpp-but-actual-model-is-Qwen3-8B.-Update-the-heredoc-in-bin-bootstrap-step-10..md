---
id: Z-107
title: >-
  [agent-issue] bootstrap writes stale model name in ~/.pi/agent/models.json —
  writes 'Qwen2.5-Coder 7B (llama.cpp)' but actual model is Qwen3-8B. Update the
  heredoc in bin/bootstrap step 10.
status: To Do
assignee: []
created_date: '2026-05-27 14:40'
labels:
  - agent-reported
  - bug
dependencies: []
priority: medium
ordinal: 5890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `1f303288367406ef493f7c3500d95703`

bootstrap writes stale model name in ~/.pi/agent/models.json — writes 'Qwen2.5-Coder 7B (llama.cpp)' but actual model is Qwen3-8B. Update the heredoc in bin/bootstrap step 10.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
