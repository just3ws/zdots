---
id: Z-254
title: 'Push, don''t poll: Turbo Streams for pipeline events'
status: To Do
assignee: []
created_date: '2026-07-24 12:51'
updated_date: '2026-08-01 09:55'
labels:
  - platform-dynamism
  - agent-ready
dependencies:
  - Z-247
priority: medium
ordinal: 130895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The transcriptions 'live refresh' morph-visits the whole page every N ms (application.js live-refresh IIFE). The pipeline already emits events (OTel spans, and Z-247 adds a structured pipeline event log). Drive the UI from those events instead: broadcast a Turbo Stream on stage transition so only the changed row/status-pill updates — real-time, not near-real-time, and no periodic full-page re-render.

Depends on the structured pipeline event log (Z-247) as the broadcast source. Keep the morph poller as a graceful fallback.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A pipeline stage transition broadcasts a Turbo Stream that updates only the affected row/status in place
- [ ] #2 The periodic morph-visit poller is removed (or demoted to fallback) once streams are live
- [ ] #3 No ActionCable-server regression: verify live update on my.localhost/transcriptions via Playwright
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-01 audit (context-engine seams): turbo-rails wired (Gemfile:8, importmap:4, morph layout) but ZERO broadcasting exists and cable.yml is async in all envs — async cable cannot see pipeline_runs writes from out-of-process zdots workers (ingest_media.rb, context_bot.rb). Transport decision first: PG LISTEN/NOTIFY bridge (fits Sequel/PG stack, covers both writers) > Redis adapter > HTTP endpoint. TRAP: solid_cable in Gemfile is inert (Sequel app, no AR) — flipping cable.yml to it ships silent no-op broadcasts; remove or annotate. Quick win now: show.html.erb:2 still hard-reloads via meta refresh — migrate to the live-refresh-ms morph pattern index uses.
<!-- SECTION:NOTES:END -->
