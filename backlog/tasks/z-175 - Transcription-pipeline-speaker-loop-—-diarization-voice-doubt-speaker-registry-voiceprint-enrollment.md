---
id: Z-175
title: >-
  Transcription pipeline: speaker loop — diarization + voice-doubt + speaker
  registry + voiceprint enrollment
status: Done
assignee: []
created_date: '2026-06-28 16:54'
updated_date: '2026-08-01 09:55'
labels:
  - transcription-pipeline
  - dream
dependencies:
  - Z-168
priority: medium
ordinal: 71890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The speaker-identity twin of the shipped term loop (Z-167). Same shape, pointed at 'who is talking' instead of 'how is it spelled'. Diarize speaker turns; derive low-confidence attributions as doubts ON RENDER (not stored, no table — like term doubts); operator labels [Speaker A] -> 'Mike' on the source page; the correction persists to a speaker registry (local-only identity, never git — mirrors known_terms); enrolled voiceprints auto-attribute on the NEXT ingest (proactive, the analog of whisper --prompt priming). Self-seeds from corrections. Open question (flag, don't solve yet): the diarization/voiceprint engine — whisper doesn't diarize; pick a local, PHI-safe option behind the existing envelope, never a new top-level system. Build in the shipped idiom (derive don't store, resolutions persist, human-gated, clinical-source voice data stays local). See doc-007 §3a for the four-surface mapping.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Speaker turns diarized; low-confidence attributions surface as doubts, derived on render (no doubts table)
- [x] #2 Confirm/correct panel labels [Speaker A] -> name; resolution persists
- [x] #3 Speaker registry holds identities local-only (DB, never git), mirroring known_terms
- [x] #4 Enrolled voiceprints auto-attribute speakers on the next ingest (proactive half)
- [x] #5 Clinical-source voice data stays local, never shared/cloud (Z-163 model)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-08-01 audit: Shipped — speaker registry (2c44f760d), diarization stage (5b4ee9388), pyannote 3.1 pin (c954fcd16), num_speakers hint (37280c67f). All 8 AC/DoD boxes checked in-file; status flipped to match.
<!-- SECTION:NOTES:END -->
