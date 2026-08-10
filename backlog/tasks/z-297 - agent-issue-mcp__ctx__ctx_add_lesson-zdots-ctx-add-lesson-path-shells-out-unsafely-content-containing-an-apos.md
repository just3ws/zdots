---
id: Z-297
title: >-
  [agent-issue] mcp__ctx__ctx_add_lesson (zdots-ctx add-lesson path) shells out
  unsafely: content containing an apos
status: To Do
assignee: []
created_date: '2026-08-07 20:11'
labels:
  - agent-reported
  - friction
dependencies: []
priority: low
ordinal: 172895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** friction
**Severity:** low
**Trace ID:** `6c2b280e6d47707657cc35934e3c6cc6`

mcp__ctx__ctx_add_lesson (zdots-ctx add-lesson path) shells out unsafely: content containing an apostrophe or parentheses breaks with bash syntax errors (e.g. "it's", "launcher.rb: `clustered? = ...`"). Had to strip all contractions/backticks/parens from lesson content to get it to save. Looks like content is interpolated into a shell command rather than passed as an argument/stdin.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
