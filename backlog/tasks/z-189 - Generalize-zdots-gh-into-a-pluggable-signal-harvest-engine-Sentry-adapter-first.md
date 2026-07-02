---
id: Z-189
title: >-
  Generalize zdots-gh into a pluggable signal-harvest engine (Sentry adapter
  first)
status: To Do
assignee: []
created_date: '2026-07-01 23:21'
labels:
  - feature
  - platform-service
dependencies: []
priority: medium
ordinal: 85890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
From the bear-* consolidation map (extends Z-184: zdots owns engines, tenants own adapters). work-sentry hand-rolls harvest → PHI-safe canonicalize → cumulative TSV; work-zendesk and work-projects-harvest repeat the same skeleton zdots-gh already implements for GitHub (harvest → DuckDB warehouse → dedup → insights, now incremental). Generalize the harvest/warehouse core to pluggable source adapters (source name, fetch fn, schema map) sharing the DuckDB + dedup + report engine. Sentry first: its PHI-safe canonicalization must be the platform PHI Scrubber, not tenant-rolled redaction — a tenant hand-rolling PHI redaction is the one duplication never to allow. Tenant keeps credentials + domain mapping + presentation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Source-adapter seam extracted from zdots-gh (github becomes the first adapter, behavior unchanged)
- [ ] #2 Sentry adapter harvests into the same warehouse pattern with PHI Scrubber canonicalization
- [ ] #3 work-sentry's use case reproducible via the zdots engine (verified read-only against its data shape)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
