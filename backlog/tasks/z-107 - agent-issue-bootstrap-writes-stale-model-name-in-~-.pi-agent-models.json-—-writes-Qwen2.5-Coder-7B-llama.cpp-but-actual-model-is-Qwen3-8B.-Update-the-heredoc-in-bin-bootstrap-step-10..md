---
id: Z-107
title: >-
  [agent-issue] bootstrap writes stale model name in ~/.pi/agent/models.json —
  writes 'Qwen2.5-Coder 7B (llama.cpp)' but actual model is Qwen3-8B. Update the
  heredoc in bin/bootstrap step 10.
status: Done
assignee: []
created_date: '2026-05-27 14:40'
updated_date: '2026-05-27 16:08'
labels:
  - agent-reported
  - bug
dependencies: []
modified_files:
  - bin/bootstrap
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed in commit 146dd4a. Bootstrap heredoc updated from "Qwen2.5-Coder 7B (llama.cpp)" to "Qwen3-8B (llama.cpp)" in the Pi models.json write step.
<!-- SECTION:FINAL_SUMMARY:END -->
