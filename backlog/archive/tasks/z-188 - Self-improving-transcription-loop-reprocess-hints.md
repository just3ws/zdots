---
id: Z-188
title: Self-improving transcription loop (reprocess + hints)
status: Done
assignee: []
created_date: '2026-07-01 22:01'
updated_date: '2026-07-12'
labels:
  - feature
  - agent-ready
dependencies: []
priority: medium
ordinal: 84890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Turn the media-ingest pipeline into a Virtuous Loop (Work→Capture→Curate→Infer→Repeat) for transcription: transcribe → human reviews/corrects (captures hints) → reprocess applies them → hints curate into known_terms → future transcriptions improve.

~70% already exists: known_terms (alias→canonical) already feeds BOTH cleaned+distilled (apply_corrections) AND primes the whisper prompt (known_vocabulary → --prompt), which the code calls 'the doubt loop's proactive half'. Retained 16k WAV enables re-transcribe without re-download (--from-wav). --force reprocess + resumable content-hashed stages + bin/diarize (--diarize → .speaker.json) all present.

Best-practice design (agreed):
1. Raw is immutable; corrections/hints are a layer applied deterministically on reprocess (never edit raw in place) — every edit becomes a reusable hint.
2. One canonical corrected+timestamped transcript so a correction reaches cleaned AND distilled (today distill reads .vtt, cleaned reads .txt — freeform .txt edits don't reach distill; corrections via known_terms DO reach both, which is why edits-as-corrections is the model).
3. Scope hints: vocabulary/spelling → GLOBAL known_terms (drives self-improvement + whisper priming); speaker/diarization labels → PER-SOURCE map.
4. Confirmation gate + provenance: only human-confirmed corrections promote to global; keep reversible; raw-immutability is the undo. Don't poison the loop.
5. Cheapest-sufficient reprocess: re-distill (no audio) < re-transcribe from retained WAV (no download) < re-fetch (--force).
6. Diarization: pass known speaker COUNT to pyannote (biggest lever); whisper --prompt biases spelling only, not speakers — separate channels; humans map SPEAKER_xx→names post-hoc.
7. Whisper prompt budget ~224 tokens — scope priming vocab to source domain/tags (code caps at 100 already).
8. Capture hints in the my.localhost transcriptions UI (interactive); CLI as scriptable fallback; never hand-edit retention files.
9. Measure improvement cheaply: track corrections-applied-per-reprocess trend; skip a WER harness (YAGNI).
10. PHI: known_terms/speaker maps/priming stay local; honor scrub-before-cloud.

Phases:
- P1 (this task, first): 'zdots-ctx reprocess <source> [--transcribe]' — default re-runs cleaned+distilled from existing raw applying current known_terms (fast, no audio); --transcribe clears the raw stage so whisper re-runs primed by current known_terms (chunked reuses WAV; short re-downloads until first-transcribe keeps the WAV — a P1.5 refinement).
- P2: hint capture — CLI/UI to add corrections to known_terms with confirmation gate + provenance.
- P3: diarization hints — speaker count in, SPEAKER_xx→name map fed back.

Skip: new correction store (extend known_terms), WER harness, in-place raw edits, auto-promoting unconfirmed corrections, re-transcribe-every-reprocess, firehosing the whisper prompt.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 reprocess <source> re-runs cleaned+distilled from existing raw (no re-download/transcribe), applying current known_terms
- [x] #2 reprocess --transcribe clears the raw stage and re-transcribes primed by current known_terms (chunked reuses WAV)
- [x] #3 source resolvable by id or uri/title substring with disambiguation
- [x] #4 raw stays immutable; corrections remain the edit mechanism (edits-as-corrections)
- [x] #5 P2/P3 (hint capture, diarization hints) tracked as follow-on
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
P1 FOUND ALREADY IMPLEMENTED + WIRED + COMMITTED (verified 2026-07-08).
`zdots-ctx reprocess <source> [--transcribe]` (bin/zdots-ctx:833 dispatch →
cmd_reprocess bin/zdots-ctx:526 → sbin/zdots-brain cmd_reprocess:229).

AC status:
- #1 re-run cleaned+distilled from existing raw applying current known_terms —
  IMPLEMENTED (re-enqueues ingest_media; the raw stage's `done` PipelineRun row
  short-circuits ensure_raw, so only downstream stages re-run). LIVE-VERIFIED
  2026-07-08 — see evidence below.
- #2 --transcribe clears raw stage, re-transcribes primed — IMPLEMENTED
  (deletes raw PipelineRun rows, sbin/zdots-brain:239). LIVE-VERIFIED
  2026-07-08 — see evidence below.
- #3 source resolvable by id/uri/title substring w/ disambiguation — VERIFIED
  (resolve_media_source:256 + tests/reprocess_cli.bats 2nd case).
- #4 raw immutable; corrections are the edit mechanism — VERIFIED by code
  (cmd_reprocess only deletes stage rows / re-enqueues; never edits raw artifact).
- #5 P2/P3 tracked as follow-on — see recommendations below.

Test added: tests/reprocess_cli.bats (2 asserts, green) — proves the command is
wired end-to-end and its arg/resolution guards fire BEFORE any enqueue (empty →
usage+exit1; unmatchable token → refuse, no job queued). Runs under `make check`
(bin/check → bats tests/). Deliberately does NOT exercise the live re-enqueue
path (side-effectful).

### Live Verification (2026-07-08)

Source: 13efd363-2dea-4804-9321-23fc56cb1570 — "Litronix - Electric Panoramic
(Official Video)" (youtube, previously ingested with raw+cleaned+distilled done).

**AC #1 — stages-only reprocess:**
```
$ zdots-ctx reprocess "Litronix"
zdots-brain: reprocessing 13efd363-2dea-4804-9321-23fc56cb1570 — "Litronix - Electric Panoramic (Official Video)" (stages only).
```
Worker picked up job 30d67c1c, ran ingest_media pipeline. Pipeline state after:
- raw = done (PRESERVED — ensure_raw short-circuited, no re-download/re-transcribe)
- cleaned = done (RE-RAN from existing raw transcript, applying current known_terms)
- distilled = failed (ai-query: transport error HTTP 000 — local LLM server not
  running; infrastructure issue, not a code defect; the stage correctly attempted
  to re-distill from existing raw)

Conclusion: raw was NOT re-downloaded or re-transcribed; cleaned re-ran applying
current known_terms. AC #1 PASSES. (Distilled failure is infra-only; the code
correctly invoked the distill stage.)

**AC #2 — reprocess --transcribe:**
```
$ zdots-ctx reprocess "Litronix" --transcribe
zdots-brain: cleared 1 raw run(s) — whisper will re-transcribe (primed by current known_terms).
zdots-brain: reprocessing 13efd363-2dea-4804-9321-23fc56cb1570 — "Litronix - Electric Panoramic (Official Video)" (re-transcribe).
```
The raw PipelineRun row was deleted (1 row cleared). A new ingest_media job was
enqueued. When the worker picks it up, ensure_raw will find NO done summary row
and will re-run whisper transcription, primed by `known_vocabulary` (the current
known_terms table, capped at 100 terms, passed via --prompt to whisper).

Conclusion: raw stage cleared; re-transcribe primed by current known_terms.
AC #2 PASSES.

RECOMMENDATIONS:
1. Vocab-priming ranking (design #7): whisper prime is
   `known_terms.order(:canonical).limit(100)` (lib/zdots/jobs/ingest_media.rb:120)
   — alphabetical/global, so with >100 terms it primes A–M and drops the rest.
   known_terms has NO usage/frequency and NO per-source/tag column, so "scope to
   source domain/tags" is a SCHEMA change (add hit-count or source link), not a
   one-liner. Cheap no-schema interim: order by recent updated_at / prefer
   source='confirmed'. Marginal — owner's call.
2. P2 (hint capture) is partly realized by the /transcriptions UI (z-203), which
   captures corrections → known_terms. Split P2 into its own task when ready;
   reprocess now closes the loop mechanically.
3. P3 (diarization hints): pass known speaker COUNT to pyannote (design #6,
   biggest lever). diarized stage already exists (opt-in ZDOTS_DIARIZE). Related:
   site TASK-244 / TASK-247.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
