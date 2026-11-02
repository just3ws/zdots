---
id: Z-357
title: 'Panoramic View: operational activation and SLO calibration'
status: In Progress
assignee: []
created_date: '2026-11-02T15:13:00Z'
updated_date: '2026-11-02T19:23:00Z'
labels: []
dependencies: []
documentation:
  - docs/plans/panoramic-observability.md
  - /Users/mike/github.com/just3ws/media-pipeline/docs/panoramic-view-tracer.md
modified_files:
  - sbin/zdots-brain
  - lib/zdots/jobs/ingest_media.rb
priority: medium
type: task
ordinal: 228895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Complete the live activation and data-bearing calibration phase for the permanent Panoramic View instrumentation implemented across media-pipeline, zdots, and Context Engine. The current Context Engine process predates the aggregate observations route, there are no operational samples yet, and no numeric SLO targets or external Alert delivery are configured. Keep control runs separate from operational cohorts; derive targets from representative observed distributions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Reload the Context Engine application through its authorized lifecycle and verify the authenticated versioned Panoramic aggregate endpoint responds.
- [ ] #2 Collect multiple ordinary operational journeys and separately identified control runs; verify checkpoint counts, route/offramp reasons, queue, inter-marker, handoff, stage, and path latency evidence.
- [ ] #3 Review sample counts and workload/version segments before deriving checkpoint and whole-path operating ranges and proposing explicit versioned SLO windows.
- [ ] #4 Verify SLO evaluations and dashboard Alert state against representative met and breached conditions; document and configure an Alert delivery route before enabling external notifications.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Live activation evidence (2026-11-02): Restarted the launchd-managed Context Engine API; `/api/v1/panoramic/observations` now serves HTTP 200 and returns aggregate-only structured checkpoints. A synthetic control fixture was processed through the dedicated Drive intake target and public test playlist. One journey/run was observed; the title-review offramp was recorded with `title_review_required`, the synthetic title was operator-approved, and the original canonical enqueue failure remains visible. A same-source retry completed all eight canonical stages.

Fixed Panoramic context loss at the zdots async handoff: `zdots-brain` now forwards journey/run/correlation/workflow/flow/run-class fields into the ingest job payload, and raw-stage reuse is scoped by Panoramic run ID. After restarting the existing worker and reprocessing the synthetic source, the Context Engine source API showed all eight stages carrying the same journey/run/workflow/flow IDs; aggregate API returned one control run, one journey, and count/latency distributions across all eight stages.

Remaining: operational cohort is still zero (control data is excluded); one control sample is not a normal-range baseline. Live API currently accepts an invalid bearer because `CONTEXT_ENGINE_BEARER_TOKEN` is unset in its launch environment; secure token provisioning and authenticated verification remain open. Numeric SLOs, multi-run comparisons, representative breach/met evaluation, and external Alert delivery still need operational samples and an explicitly configured receiver. Do not close this task or derive thresholds from this control run.

Live auth activation (2026-11-02): provisioned CONTEXT_ENGINE_BEARER_TOKEN in Keychain and updated the canonical Context Engine and media-pipeline LaunchAgent templates to load it at process start and fail closed if missing. Reloaded both authorized launchd jobs. Verified aggregate endpoint rejects absent and invalid Bearer (401), accepts the Keychain token (200), and `/up` and the media Panoramic page return 200. Commits pushed: my 617355f; media-pipeline b0018b0. Media-pipeline pre-push checks passed: mp-lint clean (mdl unavailable), Brakeman 0 warnings, full RSpec 320 examples/0 failures. Live calibration remains operational run_count=0; no thresholds were fabricated. External Alert receiver and real ordinary production samples remain open. Queue warning is unchanged: two editorial title-review holds and one failed upload needing verified remote reconciliation.

Failed-jobs dashboard triage (2026-11-02): `/jobs/failed/jobs` returns HTTP 200 and lists 16 failed Solid Queue executions, all aged 1–4 days. Eight are ScanIntakeQueuesJob failures with NoMethodError for PipelineConfigService.hydrate_queue; current code defines hydrate_queue and a fresh scanner execution completed successfully (~60 ms), so this failure is historical, not currently reproducing. The remaining entries are worker process exit/pruning records, one historical negative-interval hydration failure, and process exits for publish/enrich. Asset IDs 285, 286, 287, 290, and 297 are currently processed and have YouTube IDs, so the failed job records are stale and must not be retried. The only current failed MediaAsset is #296 with no local YouTube ID; that remains a separate ambiguous-upload reconciliation item. I did not click Retry or Discard and did not mutate job records.
<!-- SECTION:NOTES:END -->
