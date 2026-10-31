---
id: Z-347
title: Audit Codex session and cache retention
status: To Do
assignee: []
created_date: 2026-10-20 15:37
updated_date: '2026-10-31T22:33:00Z'
labels:
  - agent-reported
  - chore
dependencies: []
priority: medium
type: chore
ordinal: 222895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Codex state currently occupies about 3.5 GiB under ~/.codex. The Oct 20 audit also included Claude Code state; that component has since been archived off the active system under /Volumes/Dock_1TB/zdots-archive, so this task now covers Codex only. Session transcripts and local SQLite databases may be valuable user history and must be preserved until Codex resume, retention, and restore semantics are verified.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Inventory current Codex state by top-level size using metadata only; classify user history, active runtime packages, plugins, and regenerable cache.
- [ ] #2 Verify current Codex session discovery/resume and retention behavior from authoritative local or official documentation before moving or compressing sessions.
- [ ] #3 Preserve session files and SQLite databases; any cold archive must include a manifest, checksums, and a demonstrated restore path before originals can be removed.
- [ ] #4 Document safe cache-only cleanup targets and expected storage recovery; leave ambiguous paths untouched.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31 refresh: metadata-only du reports ~/.codex at 3.5G: sessions 1.5G, packages 747M, plugins 396M, .tmp 165M, computer-use 73M, cache 61M. Session contents were not read. Claude history/cache was archived and removed from active paths; see ~/.config/adots/handoffs/2026-10-31.md for provenance. No Codex state was changed.
<!-- SECTION:NOTES:END -->
