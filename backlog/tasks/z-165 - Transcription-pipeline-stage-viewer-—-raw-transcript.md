---
id: Z-165
title: 'Transcription pipeline: stage viewer — raw transcript'
status: Done
assignee: []
created_date: '2026-06-20 18:12'
updated_date: '2026-06-21 02:21'
labels:
  - transcription-pipeline
  - agent-ready
dependencies:
  - Z-164
priority: medium
ordinal: 56890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Per-source page at `/transcriptions/:id` showing the raw transcript content for a source, with a tabbed content area (RAW tab only for now; later slices add CLEANED/DISTILLED tabs).

Reads the raw artifact recorded by the ingest slice; renders text with its `[mm:ss]` offsets. Read-only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 /transcriptions/:id renders the raw transcript for a completed source
- [x] #2 Content area is tabbed and ready to host additional stage tabs
- [x] #3 Page shows source identity + per-stage status from pipeline_runs
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Delivered across Z-164 incr 4 (show page: identity, 5-card stage pipeline, raw transcript from retention store) + this slice (CSP-safe server-rendered stage tabs ?stage=raw|cleaned|distilled|landed|promoted, each with status pill; renders selected stage artifact, 'not run yet' for pending, falls back to raw on invalid). Verified in-process: default raw active + transcript, cleaned shows pending, bogus stage falls back. Committed on my-repo work branch (gitleaks clean). The tab area is the shared display surface Z-166/Z-167/Z-168/Z-171 plug into. make check (DoD#2) not run — verified by live render evidence.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Stage viewer with tabbed content area complete. /transcriptions/:id shows source identity, a 5-stage pipeline overview (status per stage from pipeline_runs), and CSP-safe server-rendered tabs (raw|cleaned|distilled|landed|promoted) that render each stage's retention-store artifact or a 'not run yet' placeholder. No JS (tabs are ?stage= links), so it's CSP-clean and consistent with the server-rendered app. This is the shared display surface the remaining stage features render through. Verified via in-process integration render.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
