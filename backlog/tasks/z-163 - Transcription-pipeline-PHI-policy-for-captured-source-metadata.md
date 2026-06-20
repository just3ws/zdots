---
id: Z-163
title: 'Transcription pipeline: PHI policy for captured source metadata'
status: To Do
assignee: []
created_date: '2026-06-20 18:11'
updated_date: '2026-06-20 18:14'
labels:
  - transcription-pipeline
  - hitl
  - phi
dependencies: []
priority: high
ordinal: 54890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
HITL decision gate. Captured source metadata (yt-dlp info, filenames, paths) lands in the `my` DB and renders on my.local. On a PHI-adjacent machine this needs a policy before any code writes it.

Decide:
- Scrub-before-INSERT: source metadata passes the PHI Scrubber/pseudonymizer before persisting, keyed to the destination model (local vs shared/cloud).
- Whether `media_sources.title` / `source_snapshot` need encrypted-column treatment (like `lessons.content_enc`) for clinical sources — local file paths/filenames are themselves a PHI vector.

Output: a short written policy the AFK slices can implement against. No code in this task.

Part of the transcription-pipeline v1 cut line. Blocks the ingest slice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Written policy states whether/how source metadata is scrubbed before INSERT, keyed to destination
- [ ] #2 Decision recorded on whether media_sources.title and source_snapshot require encrypted-column treatment for clinical sources
- [ ] #3 Policy is concrete enough that the ingest slice can implement against it with no further questions
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
- [ ] #4 This is a no-code policy decision: the deliverable is the written policy recorded in the transcription-pipeline plan (or a doc). The default 'make check' and 'git clean' DoD items are N/A here.
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: claude
created: 2026-06-20 18:14
---
HITL gate. Done = a written PHI policy the AFK slices (Z-164, Z-168) implement against. No code in this task, so the default make-check/commit DoD items don't apply.
---
<!-- COMMENTS:END -->
