---
id: Z-150
title: Source-ingestion envelope — URL/YouTube/playlist/webpage adapters
status: To Do
assignee: []
created_date: '2026-06-15 01:51'
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
- [ ] #1 source_document table + migration registered in zdots_schema_migrations
- [ ] #2 webpage adapter: readability extraction to markdown
- [ ] #3 youtube adapter: transcript to timestamped markdown; playlist fans out to N youtube rows
- [ ] #4 zdots ctx ingest <uri> --type auto detects source_type and distills into the Loop
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
