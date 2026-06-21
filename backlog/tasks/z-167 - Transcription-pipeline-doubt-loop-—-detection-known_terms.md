---
id: Z-167
title: 'Transcription pipeline: doubt loop — detection + known_terms'
status: In Progress
assignee: []
created_date: '2026-06-20 18:12'
updated_date: '2026-06-21 03:04'
labels:
  - transcription-pipeline
  - agent-ready
dependencies:
  - Z-164
priority: medium
ordinal: 58890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Productionize the spiked doubt loop. The system flags terms it's unsure of; the operator confirms/corrects; corrections persist and improve the next transcription.

End-to-end:
- `known_terms` migration (canonical, category person/brand/jargon/acronym, aliases for mis-hearings, source, local_only). Seed from people already in `my` (KT speaker labels, lessons).
- Doubts computed on the fly from the whisper `--output-json-full` token probabilities + known_terms — NOT stored in a table. Two signals: LOW_CONFIDENCE (spelling) and UNKNOWN_ENTITY (registration). Noise filter: only doubt low-confidence on novel words.
- Surface the doubt list on the source page; confirm/correct writes known_terms (with the mis-hearing as an alias); re-detect clears it.
- Build the whisper `--prompt` priming string from known_terms for the next run.

The spike (scratchpad/doubt-spike) is the reference implementation — it already detects, confirms, re-detects, and primes on real data.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 known_terms migration applied; seeded with known people/terms from my
- [ ] #2 Doubts computed from json-full + known_terms with the two-signal + noise-filter logic from the spike
- [ ] #3 Confirm/correct writes known_terms (alias captures the mis-hearing); re-detect no longer flags it
- [ ] #4 Priming string built from known_terms and passed to whisper --prompt on the next run
- [ ] #5 No transcript_doubts table — doubts are derived, resolutions are persisted
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Increment 1/4: known_terms migration (20260620010000) applied + verified (uuid PK, canonical unique, aliases jsonb, category, source, local_only). Seeded 6 real project terms (Ponytail/YAGNI/Betterstack/Claude/Anthropic/Karpathy) directly in DB — NOT git, since local_only identity data stays on-box. Finding: KT transcripts are already anonymized ([Speaker A/B]), so no real names to bulk-import; the loop self-seeds via corrections. Increment 2/4: KnownTerm model (known_forms set + learn upsert) + DoubtDetector service (Ruby port of the spike) in context-engine, computed on-render not stored. Verified against the live ponytail json-full + seeded terms: seeded terms excluded from doubts (leaking:[] — vocabulary integration proven), 18 genuine doubts surface (NPM, Andrus, Eberhardt, Caveman...). Two precision bugs fixed beyond the spike: bare numbers no longer flagged as acronyms (require a letter); possessives ('Ponytail\'s') matched against the known base. Remaining: (3) doubts panel on show view + confirm/correct; (4) priming string from known_terms → whisper --prompt on next ingest.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
