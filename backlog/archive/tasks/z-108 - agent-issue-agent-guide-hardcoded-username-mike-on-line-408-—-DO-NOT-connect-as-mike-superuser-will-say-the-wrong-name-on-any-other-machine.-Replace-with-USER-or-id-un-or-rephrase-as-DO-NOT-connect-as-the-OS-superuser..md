---
id: Z-108
title: >-
  [agent-issue] agent-guide: hardcoded username 'mike' on line 408 — 'DO NOT
  connect as mike (superuser)' will say the wrong name on any other machine.
  Replace with $USER or $(id -un) or rephrase as 'DO NOT connect as the OS
  superuser'.
status: Done
assignee: []
created_date: '2026-05-27 15:11'
updated_date: '2026-05-27 16:08'
labels:
  - agent-reported
  - bug
dependencies: []
modified_files:
  - bin/agent-guide
priority: medium
ordinal: 6890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `1f303288367406ef493f7c3500d95703`

agent-guide: hardcoded username 'mike' on line 408 — 'DO NOT connect as mike (superuser)' will say the wrong name on any other machine. Replace with $USER or $(id -un) or rephrase as 'DO NOT connect as the OS superuser'.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed in commit 146dd4a. Changed "DO NOT connect as mike (superuser)" to "DO NOT connect as the OS superuser for routine queries" — generic across any clone.
<!-- SECTION:FINAL_SUMMARY:END -->
