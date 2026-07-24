---
id: Z-253
title: 'Close the Virtuous Loop: auto-extract primer context'
status: To Do
assignee: []
created_date: '2026-07-24 12:51'
labels:
  - platform-dynamism
  - knowledge-layer
  - agent-ready
dependencies: []
priority: medium
ordinal: 129895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
/intelligence shows empty 'Extracted Primer Context' for every source: capture runs, but the Curate→Infer legs of the Virtuous Loop (Work→Capture→Curate→Infer→Repeat, AGENTS.md §Knowledge) do not flow back. Half the value is built and stalled.

Wire the loop to self-drive: when a source is captured/distilled, automatically extract primer context (glossary, entities, recurring terms) via the local model and persist it so /intelligence populates without a manual step. Surface the extracted primer on the source page and feed it back into subsequent transcription runs (ties into Z-188 self-improving loop).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Distilling a source auto-extracts primer context via the local model and persists it
- [ ] #2 /intelligence and the source page display the extracted primer (no longer empty)
- [ ] #3 Extracted primer feeds back into subsequent transcription/ingest runs for that source
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
