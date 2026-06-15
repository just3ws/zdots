---
id: Z-135
title: 'Runtime-insight feedback loop: scrub-at-ingest + session read-back (work-safe)'
status: Done
assignee: []
created_date: '2026-06-07 16:55'
updated_date: '2026-06-15 01:58'
labels:
  - agent-ready
  - observability
  - phi
  - wave1
dependencies:
  - Z-134
priority: high
ordinal: 26890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Close the runtime-insight loop so OpenObserve telemetry and command outcomes are queryable inside AI sessions to support work, with PHI/secret filtering pushed to the INGEST edge (single-source from etc/phi-patterns.yaml) so the intelligence layer reads already-clean data. CC is a cloud tool that bypasses local phi_scrub; edge scrub is what makes runtime data safe to surface. Must be work-safe (ZDOTS_CONTEXT=work). See AGENTS.md §9 (patterns ONLY in phi-patterns.yaml — collector config must be COMPILED from it, not hand-authored).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Phase 1 (cornerstone): bin/zdots-otel-phi-compile generates collector redaction (attributes, all signals) + transform (log bodies) + filter (suppress) processors FROM etc/phi-patterns.yaml; wired into all 3 pipelines; otel-collector serve regenerates it at boot
- [x] #2 Phase 1 verify: otel-smoke emits PHI/secret-shaped trace+log+metric; confirm masked/dropped in O2 (nothing sensitive lands in storage)
- [x] #3 Phase 2: bin/zdots-o2-query reads already-clean O2 data (errors/slow-spans/failed-service last Nh), light defense-in-depth scrub; work-safe
- [x] #4 Phase 4: cc-hook-session runtime digest (O2 error count + top failing commands + service-health delta), bounded+scrubbed, gated for work
- [x] #5 Single-source preserved: no PHI regex authored outside phi-patterns.yaml; cc-doctor/zdots-doctor still green
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
P4 done+committed (786cfc7): cc-hook-session appends a runtime digest at SessionStart — error-log count+top services, failed-span count+top ops over ZDOTS_CC_DIGEST_SINCE (default 6h), via zdots-o2-query read-back. Counts+service/op only (no bodies), bounded (perl alarm 3s/query), fail-open (dead O2 → 0 lines, 0.26s). cc-doctor 29/0/0. AC6 (single-source) preserved throughout: no PHI patterns authored outside phi-patterns.yaml across P1/P2/P4. Status: P1+P2+P4 DONE. P3 (o2 MCP, AC4) remains OPTIONAL — zdots-o2-query already covers on-demand pull from the CLI.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Runtime-insight loop landed (P1+P2+P4). bin/zdots-otel-phi-compile generates collector redaction/transform/filter from etc/phi-patterns.yaml (single-source AC6, verified by phi_boundary 54/54 incl. cross-layer phi_registry); otel-smoke confirmed masking (P1). bin/zdots-o2-query reads already-clean O2 for errors/slow-spans/failed-services, work-safe (P2). cc-hook-session appends a bounded, scrubbed SessionStart runtime digest, gated for work (P4, commit 786cfc7). cc-doctor 29/0/0. Optional Phase-3 o2 MCP server descoped to Z-152 (zdots-o2-query already covers on-demand pull). The Infer step of the Virtuous Loop is closed.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
