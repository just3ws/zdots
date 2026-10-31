---
id: Z-236
title: >-
  [agent-issue] zdots-heal Gate 6: 37 agent-facing bin/ commands lack a CC
  allowlist entry in settings.json or setti
status: Done
assignee: []
created_date: '2026-07-21 01:24'
updated_date: '2026-07-21 13:41'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 115895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `2f902b70738550f801577f176ee86c12`

zdots-heal Gate 6: 37 agent-facing bin/ commands lack a CC allowlist entry in settings.json or settings.local.json (e.g. zdots-search, zdots-publish, zdots-ingest-media, gemstash-ctl, diarize, zclaude). Curate which should be granted. Also Gate 3 service list in zdots-heal.md is missing gemstash + zdots-statusd.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
