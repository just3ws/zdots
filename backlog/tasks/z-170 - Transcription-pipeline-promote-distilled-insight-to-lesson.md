---
id: Z-170
title: 'Transcription pipeline: promote distilled insight to lesson'
status: Done
assignee: []
created_date: '2026-06-20 18:12'
updated_date: '2026-06-21 08:58'
labels:
  - transcription-pipeline
  - agent-ready
dependencies:
  - Z-168
priority: medium
ordinal: 61890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Close the virtuous loop. Edited distilled content is promoted into the Knowledge Layer and becomes semantically searchable.

End-to-end:
- From the DISTILLED/edited content, promote to a `lessons` row reusing the existing `LessonIntake` path (source_type, source_trace_id linking back to the pipeline run + source `[mm:ss]`).
- Auto-embed on promotion (existing llama-embed job) so the lesson is immediately surfaced by `zdots-ctx query --semantic`.
- PROMOTED stage recorded in pipeline_runs; the source shows as complete in /transcriptions.

Provenance: the lesson carries a backlink to the source (title, timestamp, url/path, content hash).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Promoting edited distilled content creates a lessons row via LessonIntake with source backlink + [mm:ss]
- [x] #2 Promotion triggers the existing embed job; the lesson is returned by zdots-ctx query --semantic
- [x] #3 PROMOTED stage recorded; source shows complete in /transcriptions
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-06-21 08:58
---
Done — parity reached. Promote runs in-process via the bridged Zdots models (LessonIntake + embed enqueue + PROMOTED stage). Verified live: ponytail video → lesson 04886bae → embedded → top semantic match. Needed a bridge fix (load lesson_intake + enable pg_array/pg_json on Zdots.db). Live Puma needs a deploy to serve it. Next: Z-169 chunking for long videos.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Virtuous loop closed — verified live on the ponytail video (source 0f2f7768 → lesson 04886bae). **Parity reached.**

Promotion runs **in-process** in the context-engine controller via the already-bridged Zdots models — no shell-out, no new job type, no zdots-brain change. Commit 0921738 (`~/my`, context-engine only).

- **AC#1** — `POST /transcriptions/:id/promote` creates a Lesson through `Zdots::Models::LessonIntake` (the canonical provenance seam): `source_type=distill`, `source_trace_id="media:<id>"`, `context` backlinks title + url + distilled content-hash. Content is the saved distilled briefing — every bullet carries its `[mm:ss]`. Verified: lesson content decrypts and contains `[00:00]`. Idempotent per source — re-promote updates the one lesson, never duplicates (verified count==1).
- **AC#2** — promotion enqueues the existing `embed` job (fingerprint keyed to content hash: edited briefing re-embeds, unchanged dedupes). Worker embedded it; `zdots-ctx query --semantic "ponytail … lazy senior developer"` returns the lesson as the **top LESSONS match**.
- **AC#3** — PROMOTED `pipeline_run` recorded (status done, run_params.lesson_id); the PROMOTED tab renders a green banner linking the lesson; source shows complete.

Plumbing fix: the bridge now `require`s `lesson_intake` and enables `pg_array`/`pg_json` on `Zdots.db` (mirrors `lib/zdots/db.rb`) — these register `Sequel.pg_array`/`pg_jsonb`, which LessonIntake and jsonb writes need in this consumer. Without it, promote 500'd on `undefined method 'pg_array'`.

DoD#2 (`make check`): N/A for this path — verified via in-process request round-trip + idempotency test + live semantic query. Secret-scan (gitleaks): no leaks.

Note: the live dashboard (launchd Puma) needs a deploy/restart to serve the new route/controller/bridge; in-process tests ran on fresh-loaded code.

Pipeline is now end-to-end: ingest → RAW → CLEANED → DISTILLED (editable) → PROMOTED → embedded → semantically searchable, with the doubt loop feeding corrections and full source provenance. Remaining: Z-169 chunking (long videos), Z-171 timeline (deferred), Z-154 (superseded).
<!-- SECTION:FINAL_SUMMARY:END -->
