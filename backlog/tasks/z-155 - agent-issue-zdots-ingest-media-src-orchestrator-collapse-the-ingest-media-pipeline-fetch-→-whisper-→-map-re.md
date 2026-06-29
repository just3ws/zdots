---
id: Z-155
title: >-
  [agent-issue] zdots-ingest-media <src> orchestrator: collapse the
  /ingest-media pipeline (fetch → whisper → map-re
status: To Do
assignee: []
created_date: '2026-06-17 11:57'
updated_date: '2026-06-29 14:09'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 46890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `6bf14d21464f22110cd5256b140c4c30`

zdots-ingest-media <src> orchestrator: collapse the /ingest-media pipeline (fetch → whisper → map-reduce synth → retain → vault+DB ingest) into one observable command with per-stage progress and the Step-5 three-signal verification (lessons-count delta, embed-job completed, keyword+semantic recall). Validated the manual pipeline end-to-end on youtu.be/rlbJr6kenS0 2026-06-17; gaps now fixed in the skill (portable split, empty-input guard, embed-job/worker verification, whisper progress signal) but each run is still ~10 hand-run steps with copy-pasted slug/id/paths. See docs/ingest-media-pipeline.md.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-06-29 investigation finding: Z-164 already automates the first four stages — acquire/transcribe/clean/distill — producing `.distilled.md` in `~/.local/state/zdots/ingest-sources/<mid>/`. The only remaining gap is stage 5: promote-to-vault (write `~/my/knowledge/lessons/<slug>.md` + `zdots-ctx ingest` + embed + three-signal verify). That step crosses the `~/my` boundary and carries a curation gate (slug/tags/faithfulness are operator judgement). Sibling Z-154 (same trace, same manual-skill origin) is dispositioned 'likely SUPERSEDED by Z-164'. Recommend operator decide: (a) close as SUPERSEDED by Z-164 + leave vault write as a manual curation step, or (b) authorize a standalone `zdots-promote-lesson` command for the last mile. Not built — AGENTS.md §5 boundary + token ceiling; stopping here for operator resolution.
<!-- SECTION:NOTES:END -->
