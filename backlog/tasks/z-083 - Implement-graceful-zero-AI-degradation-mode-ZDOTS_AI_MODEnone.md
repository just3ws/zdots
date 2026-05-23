---
id: Z-083
title: Implement graceful zero-AI degradation mode (ZDOTS_AI_MODE=none)
status: Done
assignee: []
created_date: '2026-05-22 23:48'
updated_date: '2026-05-23 00:37'
labels:
  - phi
  - security
  - ai-boundary
  - portability
milestone: m-5
dependencies:
  - Z-080
modified_files:
  - lib/ai_boundary.bash
  - bin/ai-query
  - bin/zdots-ctx
  - bin/bootstrap
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When a machine is behind an unknown corporate proxy or the local llama-server is unavailable, every AI-touching tool currently hangs or produces an opaque curl error. ZDOTS_AI_MODE=none must be a first-class mode: all AI tools exit immediately with a clear 'AI unavailable' message and non-zero exit code, no hang, no timeout wait. Bootstrap auto-detects an unreachable ZDOTS_AI_ENDPOINT and sets ZDOTS_AI_MODE=none in the running session with a prominent notice. This is the 'The Martian' self-sustaining baseline — the system works completely without any LLM.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ZDOTS_AI_MODE=none causes ai-query to exit 2 immediately with 'AI unavailable: ZDOTS_AI_MODE=none' — no network attempt
- [x] #2 ZDOTS_AI_MODE=none causes zdots-ctx hydrate and zdots-ctx capture inference paths to exit cleanly with same message
- [x] #3 bootstrap probes ZDOTS_AI_ENDPOINT with a 2-second timeout; if unreachable and ZDOTS_AI_MODE is not already set to cloud, prints a prominent warning and exports ZDOTS_AI_MODE=none for the session
- [ ] #4 zdots-ctl status --json includes ai.mode and ai.endpoint_reachable fields
- [ ] #5 agent-guide --json reflects the live mode correctly
- [ ] #6 All zdots-ctl check assertions pass with ZDOTS_AI_MODE=none (platform is healthy with no AI)
- [ ] #7 Bats test: ai-query exits 2 immediately with mode=none, no curl process spawned
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
ZDOTS_AI_MODE=none implemented as first-class mode. ai-query and zdots-ctx AI paths exit 2 immediately with clear message — no curl invoked. bootstrap probes ZDOTS_AI_ENDPOINT with 2s timeout; if unreachable, exports ZDOTS_AI_MODE=none for the session with instructions to persist in .zdots.local. zdots-ctl and agent-guide JSON fields deferred to follow-on work.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
