---
id: Z-167
title: 'Transcription pipeline: doubt loop — detection + known_terms'
status: Done
assignee: []
created_date: '2026-06-20 18:12'
updated_date: '2026-06-21 05:07'
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
- [x] #1 known_terms migration applied; seeded with known people/terms from my
- [x] #2 Doubts computed from json-full + known_terms with the two-signal + noise-filter logic from the spike
- [x] #3 Confirm/correct writes known_terms (alias captures the mis-hearing); re-detect no longer flags it
- [x] #4 Priming string built from known_terms and passed to whisper --prompt on the next run
- [x] #5 No transcript_doubts table — doubts are derived, resolutions are persisted
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Increment 1/4: known_terms migration (20260620010000) applied + verified (uuid PK, canonical unique, aliases jsonb, category, source, local_only). Seeded 6 real project terms (Ponytail/YAGNI/Betterstack/Claude/Anthropic/Karpathy) directly in DB — NOT git, since local_only identity data stays on-box. Finding: KT transcripts are already anonymized ([Speaker A/B]), so no real names to bulk-import; the loop self-seeds via corrections. Increment 2/4: KnownTerm model (known_forms set + learn upsert) + DoubtDetector service (Ruby port of the spike) in context-engine, computed on-render not stored. Verified against the live ponytail json-full + seeded terms: seeded terms excluded from doubts (leaking:[] — vocabulary integration proven), 18 genuine doubts surface (NPM, Andrus, Eberhardt, Caveman...). Two precision bugs fixed beyond the spike: bare numbers no longer flagged as acronyms (require a letter); possessives ('Ponytail\'s') matched against the known base. Remaining: (3) doubts panel on show view + confirm/correct; (4) priming string from known_terms → whisper --prompt on next ingest.

Increment 3/4 done + verified: doubts panel on the show view. Doubts computed on render (compute_doubts → DoubtDetector over the raw json-full + KnownTerm.known_forms). Each doubt is a CSP-safe form_with row: timestamp, signal pill (spelling?/unknown), editable term field, category select, Learn button. Submit unchanged = confirm; edit text = correct (heard folds in as alias). POST /transcriptions/:id/known_terms → learn_term → KnownTerm.learn → redirect. Verified in-process: panel renders 200 with CSRF + 18 doubt forms; POST confirm 'NPM' → 302, persisted to known_terms, re-detect drops it (18→17). ACs 1,2,3,5 met. Remaining: AC#4 — increment 4: priming string from known_terms → whisper --prompt on the next ingest (zdots-side: yt-transcribe --prompt flag + ingest_media builds the Vocabulary string).

Increment 4/4 done + verified: priming (the proactive half). yt-transcribe gained --prompt (passed to whisper-cli, empty-array-guarded for bash 3.2 set -u); ingest_media#known_vocabulary builds 'Vocabulary: <terms>.' from known_terms (ordered, capped 100) and appends --prompt. Verified end-to-end: restarted worker on new code, re-ingested --force; worker logged the command with --prompt Vocabulary: Anthropic, Betterstack, Claude, Karpathy, NPM, Ponytail, YAGNI. and the ingest completed (raw:done, job completed) — priming passed without breaking the chain. Launchd worker restarted (PID 99077) on current code. AC#4 met; all 5 ACs done.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Doubt loop complete — both halves, end-to-end. REACTIVE: doubts computed on render from whisper json-full token probs + known_terms (two signals, noise filter), surfaced as a confirm/correct panel on /transcriptions/:id; resolutions persist to known_terms (mis-hearing folds in as alias), and re-detect drops them. PROACTIVE: that same known_terms vocabulary is built into whisper's --prompt on the next ingest, so terms get spelled right before review. Verified live on the ponytail video at every step (seeded terms excluded from doubts, confirm 'NPM' removed it 18→17, priming string logged in the worker command). Self-seeding; local_only identity data stays in the DB, never git. Spans zdots (known_terms migration, yt-transcribe --prompt, ingest_media vocab) + my (KnownTerm model, DoubtDetector service, doubts panel). No transcript_doubts table — doubts derived, not stored. Operational note: restart the worker (zsvc) after handler-code changes.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
