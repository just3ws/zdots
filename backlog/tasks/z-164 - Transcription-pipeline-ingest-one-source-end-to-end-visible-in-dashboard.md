---
id: Z-164
title: 'Transcription pipeline: ingest one source end-to-end, visible in dashboard'
status: In Progress
assignee: []
created_date: '2026-06-20 18:11'
updated_date: '2026-06-21 00:48'
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
- [x] #1 Migrations create media_sources, pipeline_runs, and the source_snapshot JSONB column; applied via zdots-ctx migrate
- [x] #2 zdots-ingest-media <url> captures metadata and enqueues via zdots-brain ingest-media in one transaction
- [x] #3 Re-running the same URL is a no-op without --force; --force reprocesses (reuses enqueue --force)
- [x] #4 Worker transcribes the raw stage with --output-json-full and records pipeline_runs rows
- [ ] #5 /transcriptions lists the source with live-polled stage status, raw→done
- [x] #6 Source metadata handled per the PHI policy (Z-163)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Increment 1/4 done + verified: migration 20260620000000_add_transcription_pipeline_tables.rb creates media_sources + pipeline_runs (uuid PKs, source_snapshot JSONB write-once column, unique source_uri dedup anchor, unique (media_source_id,stage)). Applied via zdots-ctx migrate; verified columns/indexes/FK/grants with psql zdots_ro. Per ponytail pass, omitted chunk_index (Z-169 adds it). Migration file uncommitted (code commit awaits operator ask). Remaining: (2) bin/zdots-ingest-media + zdots-brain ingest-media write seam, (3) worker raw stage --output-json-full, (4) my-side /transcriptions read model + view (crosses into context-engine — coordinate).

Increment 2/4 done + verified: bin/zdots-ingest-media (bash metadata capture) + zdots-brain ingest-media subcommand (Ruby, one txn: media_sources upsert + job enqueue) + MediaSource model. Verified on real data — public youtube: ingest → idempotent [skip] on re-run → --force reprocesses same row; snapshot holds non-PHI volatile state (view_count etc). Local (non-media, PHI-named file): stores local:sha256:<hash> uri + operator label only, leak-check clean (no filename/path/PHI in DB) per Z-163. Bugs fixed en route: empty ON CONFLICT update SET (mirror cmd_enqueue's DO NOTHING), and set -e killing the ffprobe assignment / partial-output concatenation (normalize probe through jq). Code uncommitted (awaits operator ask). Note: bin/ai-query shows pre-existing working-tree mod, not from this work. Remaining: (3) worker ingest_media handler runs raw stage --output-json-full → pipeline_runs; (4) my-side /transcriptions read model + view (coordinate).

Increment 3/4 done + verified: ingest_media job handler (lib/zdots/jobs/ingest_media.rb) + PipelineRun model + yt-transcribe extended with --json-full (token confidence) and --out-dir (retention store, not ~/Downloads); removed a pre-existing dead var (META_JSON) the lint gate flagged. Live worker ran the ponytail video end-to-end: ingest_status queued→running→done, pipeline_runs raw=done (content-hashed), job completed, retention dir ~/.local/state/zdots/ingest-sources/<mid>/<vid>/ holds txt+vtt+srt+csv+json+info.json, whisper json is json-full with 2099 token probs. OPERATIONAL FINDING: the launchd zdots-worker loads code at start — it was running stale code and orphaned the first ingest_media job (claimed, unknown type, left 'running'). Fix: `zsvc restart worker` after changing job/handler code; required on deploy of this work. Remaining: (4) my-side /transcriptions read model + view (AC#5) — crosses into context-engine, coordinate.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
