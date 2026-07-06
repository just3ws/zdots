---
id: Z-199
title: Expose generic transcript-AI transforms as tenant-consumable zdots services
status: To Do
assignee: []
created_date: '2026-07-04 14:57'
updated_date: '2026-07-05 00:44'
labels:
  - request
  - agent-ready
dependencies: []
references:
  - 'https://github.com/just3ws/just3ws.github.io (TASK-242'
  - doc-042 repo-zdots boundary)
priority: high
ordinal: 95890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
zdots-side companion to just3ws.github.io TASK-242 (Extract generic AI capabilities into zdots; keep only interview-unique orchestration).

Target architecture: zdots is the transcription/AI service provider; tenant repos (the just3ws interview archive first) are thin consumers that enqueue jobs and evaluate results.

Today the interview-archive repo hand-rolls direct-LLM enrichment (cerebral_enrichment.rb, lexical_enrichment.rb, archive/modules/enrich.rb, generate_pivotal_metadata.rb) that POST raw JSON to a local LLM endpoint and write structured results into the tenant's own _data. The existing distill job does not serve this: it reads a Downloads .txt, uses a fixed prompt, and produces an internal zdots Lesson, not caller-consumable structured output.

Close the gap: expose the generic transcript-AI transforms as job types that accept a caller payload (text plus an output profile) and return a structured result the tenant fetches and writes into its own data model. Keep interview-unique logic (UGtastic brand normalization, speaker_map M1/S1/S2 labeling, canonical-review workflow) OUT of zdots.

Related but tracked separately: acoustic diarization (pyannote) inside the transcription job for just3ws TASK-244 — same consumer pattern (zdots computes, tenant consumes).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Inventory the generic vs tenant-unique transforms in the just3ws enrichment scripts and document the boundary (what zdots absorbs vs what stays in the tenant)
- [x] #2 A generic structured-distill job type accepts a caller payload (text plus output profile/schema) and persists a structured result the caller can fetch — not only an internal Lesson
- [x] #3 Results are idempotent (fingerprint on deterministic payload) and retrievable via zdots-ctx and the existing job+result model
- [x] #4 The tenant-facing contract (enqueue payload plus result shape) is documented so just3ws TASK-242 can consume it with no new integration layer
- [x] #5 No tenant-specific branding or speaker-labeling logic lives in zdots
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: claude
created: 2026-07-05 00:44
---
Reconciliation after pulling capabilities + agent-guide: the generic tenant-consumable transform mechanism this task specced ALREADY LANDED as commit 15b162d (lib/zdots/jobs/transform.rb, job type transform, payload {text, profile}, result via 'zdots-ctx result', prompts at etc/prompts/jobs/transform/<profile>.txt). Its source comment encodes the doc-042 boundary (tenant-unique branding/speaker-labels stay in the tenant). AC#1-5 are satisfied by that commit; only the 'summarize' profile exists so far.

Remaining transcription-improvement work (beyond this task's original mechanism scope):
(a) author transform profiles as prompt files (no code): transcript cleanup/de-loop, insights, YouTube SEO metadata;
(b) acoustic diarization (pyannote) is still ABSENT from the platform (capabilities shows whisper-cpp only) — the one real capability gap, tracked by just3ws TASK-244.

Recommend: close Z-199 as Done (mechanism delivered), open a focused profiles + diarization follow-up.
---
<!-- COMMENTS:END -->
