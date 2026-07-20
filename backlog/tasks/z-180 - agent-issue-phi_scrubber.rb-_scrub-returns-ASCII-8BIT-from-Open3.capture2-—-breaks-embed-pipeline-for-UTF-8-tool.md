---
id: Z-180
title: >-
  [agent-issue] phi_scrubber.rb _scrub returns ASCII-8BIT from Open3.capture2 —
  breaks embed pipeline for UTF-8 tool
status: Done
assignee: []
created_date: '2026-06-29 15:21'
updated_date: '2026-07-15 14:00'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 76890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `0d2e75b812e72d620a684e07675a75c9`

phi_scrubber.rb _scrub returns ASCII-8BIT from Open3.capture2 — breaks embed pipeline for UTF-8 tool help text

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause: launchd children have no locale env → Ruby default_external is US-ASCII → Open3.capture2 output from zdots-phi-scrub arrives ASCII-8BIT/US-ASCII-tagged; UTF-8 bytes then raise 'invalid byte sequence' downstream (embed pipeline, docs_sync — see Z-225).

Fix: _scrub retags output as UTF-8 + String#scrub for invalid sequences (lib/zdots/ai/phi_scrubber.rb). Regression test in tests/phi_boundary.bats runs the adapter under LC_CTYPE=C with multibyte input — red before, green after; full suite 55/55.

Live evidence pending: the 2 encoding-dead docs_sync jobs (Z-225) are requeued and queued behind the docs_sync backlog — if they complete, Z-225's worker-side symptom is resolved by this fix.
<!-- SECTION:NOTES:END -->
