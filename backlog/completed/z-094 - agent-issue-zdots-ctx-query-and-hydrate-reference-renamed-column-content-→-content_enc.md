---
id: Z-094
title: >-
  [agent-issue] zdots-ctx query and hydrate reference renamed column: content →
  content_enc
status: Done
assignee: []
created_date: '2026-05-23 14:49'
updated_date: '2026-05-23 14:59'
labels:
  - agent-reported
  - bug
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `29ff394918fb4265000d6a5c721c12f4`

zdots-ctx query and hydrate reference renamed column: content → content_enc

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed via commit 65988ca. Three bugs repaired: find_or_create in cmd_add_methodology (NOT NULL on title), cmd_query raw psql referencing content column (now routes through zdots-brain), cmd_hydrate raw psql referencing content column (now routes through zdots-brain cmd_hydrate). Also fixed Methodology.search.limit → .first(5) in zdots-brain. All fixes confirmed: 216/216 tests pass, hydration returns full decrypted methodology content.
<!-- SECTION:FINAL_SUMMARY:END -->
