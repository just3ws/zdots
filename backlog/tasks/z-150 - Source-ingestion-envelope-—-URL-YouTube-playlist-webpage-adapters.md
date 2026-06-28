---
id: Z-150
title: Source-ingestion envelope — URL/YouTube/playlist/webpage adapters
status: In Progress
assignee: []
created_date: '2026-06-15 01:51'
updated_date: '2026-06-28 17:23'
labels:
  - wave2
  - agent-ready
dependencies:
  - Z-135
ordinal: 41890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend zdots-ctx ingest with a uniform source_document envelope so any source (youtube, playlist, webpage + existing pdf/docx/vtt) normalizes to body_md before the Virtuous Loop. Adapters behind the envelope, never new top-level commands. See decision-009 + doc-004.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 source_document table + migration registered in zdots_schema_migrations
- [x] #2 webpage adapter: readability extraction to markdown
- [ ] #3 youtube adapter: transcript to timestamped markdown; playlist fans out to N youtube rows
- [ ] #4 zdots ctx ingest <uri> --type auto detects source_type and distills into the Loop
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC#1 done: source_document table created in migration 20260628000000_add_knowledge_foundation.rb. Applied + verified cold (uuid PKs, grants rw=S/I/U/D ro=S, idempotent, recorded in zdots_schema_migrations).

AC#2 done: lib/zdots/ingest/webpage_adapter.rb — Zdots::Ingest::WebpageAdapter.fetch(uri) returns {source_type:, uri:, title:, body_md:, checksum:, provenance:, fetched_at:}. Uses net/http (stdlib) + nokogiri + reverse_markdown; strips nav/footer/aside/script/style before converting. Follows redirects (max 5). PHI-safe: egress is GET to target URL only.

Remaining: youtube/playlist adapters (AC#3) + zdots-ctx ingest --type auto envelope wiring (AC#4). YouTube investigation needed before building — check how zdots-brain ingest-media + yt-transcribe + media_sources relate to source_document to avoid duplicate stores.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
