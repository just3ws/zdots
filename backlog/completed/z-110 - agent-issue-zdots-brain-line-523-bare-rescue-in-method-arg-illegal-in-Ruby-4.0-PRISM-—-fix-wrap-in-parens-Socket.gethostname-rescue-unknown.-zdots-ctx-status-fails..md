---
id: Z-110
title: >-
  [agent-issue] zdots-brain line 523: bare rescue in method arg illegal in Ruby
  4.0 PRISM — fix: wrap in parens (Socket.gethostname rescue 'unknown').
  zdots-ctx status fails.
status: Done
assignee: []
created_date: '2026-05-27 15:12'
updated_date: '2026-05-27 16:08'
labels:
  - agent-reported
  - bug
dependencies: []
modified_files:
  - sbin/zdots-brain
priority: medium
ordinal: 8890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `1f303288367406ef493f7c3500d95703`

zdots-brain line 523: bare rescue in method arg illegal in Ruby 4.0 PRISM — fix: wrap in parens (Socket.gethostname rescue 'unknown'). zdots-ctx status fails.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed in commit 146dd4a. Wrapped Socket.gethostname rescue "unknown" in parens: (Socket.gethostname rescue "unknown"). Ruby 4.0 PRISM parser rejects bare rescue in method argument position.
<!-- SECTION:FINAL_SUMMARY:END -->
