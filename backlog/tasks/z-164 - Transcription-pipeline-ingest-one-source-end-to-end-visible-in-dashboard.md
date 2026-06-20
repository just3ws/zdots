---
id: Z-164
title: 'Transcription pipeline: ingest one source end-to-end, visible in dashboard'
status: To Do
assignee: []
created_date: '2026-06-20 18:11'
labels:
  - transcription-pipeline
  - agent-ready
dependencies:
  - Z-163
priority: high
ordinal: 55890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The tracer bullet — one thin path through every layer. Running `zdots-ingest-media <url|file>` ingests a short source and it appears in a read-only /transcriptions list, tracking raw→done.

End-to-end behavior:
- Migrations: `media_sources` (stable identity, unique source_uri, ingest_status) + `pipeline_runs` (per-stage status/content_hash) + a write-once JSONB `source_snapshot` column on media_sources. Reuse the existing `jobs` queue + worker — do not build a new queue.
- `bin/zdots-ingest-media` (bash) captures metadata (`yt-dlp --dump-json`; `stat`+`sha256`+`ffprobe` for local) and pipes JSON to a new Ruby `zdots-brain ingest-media` subcommand, which writes media_sources + source_snapshot and enqueues a job in one transaction (zdots_rw).
- Worker runs the raw stage with whisper `--output-json-full` (token confidence — the current recipe uses plain --output-json and must switch), writing pipeline_runs rows.
- context-engine: read-only `MediaSource`/`PipelineRun` Sequel read models (zdots_ro) + `/transcriptions` index, polled (~3s; reuse the existing dashboard poll pattern — no Turbo/cable yet).

Decision settled in plan: zdots-brain owns the DB write + dashboard polls (not Rails-API+Turbo). Implement against the PHI policy from the blocker.

Demoable: `zdots-ingest-media <short-yt-url>` → row appears in /transcriptions → status goes raw→done.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Migrations create media_sources, pipeline_runs, and the source_snapshot JSONB column; applied via zdots-ctx migrate
- [ ] #2 zdots-ingest-media <url> captures metadata and enqueues via zdots-brain ingest-media in one transaction
- [ ] #3 Re-running the same URL is a no-op without --force; --force reprocesses (reuses enqueue --force)
- [ ] #4 Worker transcribes the raw stage with --output-json-full and records pipeline_runs rows
- [ ] #5 /transcriptions lists the source with live-polled stage status, raw→done
- [ ] #6 Source metadata handled per the PHI policy (Z-163)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
