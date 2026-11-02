---
id: Z-357
title: 'Panoramic View: operational activation and SLO calibration'
status: To Do
assignee: []
created_date: '2026-11-02T15:13:00Z'
labels: []
dependencies: []
documentation:
  - docs/plans/panoramic-observability.md
  - /Users/mike/github.com/just3ws/media-pipeline/docs/panoramic-view-tracer.md
modified_files:
  - docs/plans/panoramic-observability.md
  - app/controllers/api/v1/panoramic_observations_controller.rb
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
- [ ] #1 Reload the Context Engine application through its authorized lifecycle and verify the authenticated versioned Panoramic aggregate endpoint responds.
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
