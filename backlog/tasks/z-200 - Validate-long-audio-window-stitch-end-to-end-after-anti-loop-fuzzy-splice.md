---
id: Z-200
title: Validate long-audio window stitch end-to-end after anti-loop + fuzzy splice
status: To Do
assignee: []
created_date: '2026-07-06 13:26'
labels:
  - request
  - agent-ready
dependencies: []
references:
  - commit 545dc57
  - commit 7899071
modified_files:
  - bin/whisper-ctl
  - lib/zdots/jobs/transcribe_chunk.rb
  - recipes/yt-transcribe
priority: medium
ordinal: 96890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Anti-loop (--max-context 0) now guards all 3 whisper decode sites and the window overlap-dedup was rewritten to normalized fuzzy matching (commits 7899071, 545dc57). splice is unit-tested (7 self-check asserts, green) but has NOT been exercised on a real long (>10 min) source where independently-decoded windows genuinely diverge on the shared ~15s overlap. Confirm the stitched output reads clean at every seam and no window loops.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Run the chunked path (yt-transcribe --from-wav via ingest_media/transcribe_chunk) on a real source over 10 minutes
- [ ] #2 Inspect every window seam in the stitched .txt for duplicated OR dropped words
- [ ] #3 Confirm the splice 'no overlap ... long seam' warn does NOT fire on windows that genuinely overlap
- [ ] #4 Spot-check per-window word counts vs runtime to confirm no turbo repetition loop
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
