---
id: Z-188
title: Self-improving transcription loop (reprocess + hints)
status: To Do
assignee: []
created_date: '2026-07-01 22:01'
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
8. Capture hints in the my.local transcriptions UI (interactive); CLI as scriptable fallback; never hand-edit retention files.
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
- [ ] #1 reprocess <source> re-runs cleaned+distilled from existing raw (no re-download/transcribe), applying current known_terms
- [ ] #2 reprocess --transcribe clears the raw stage and re-transcribes primed by current known_terms (chunked reuses WAV)
- [ ] #3 source resolvable by id or uri/title substring with disambiguation
- [ ] #4 raw stays immutable; corrections remain the edit mechanism (edits-as-corrections)
- [ ] #5 P2/P3 (hint capture, diarization hints) tracked as follow-on
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
