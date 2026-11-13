---
id: Z-361
title: Local AI modernization for the 16 GB baseline
status: In Progress
assignee:
  - '@mike'
created_date: '2026-11-13T17:22:00Z'
updated_date: '2026-11-13T19:54:00Z'
labels:
  - ai-tooling
dependencies: []
priority: medium
ordinal: 232895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bring the local AI stack up to date without breaking the baseline machine (M4, 16 GB RAM, 256 GB disk). Defaults must fit that baseline; bigger models stay per-machine opt-ins in .zdots.local. Order: subtasks in dependency order. Resume: read this task, then the first subtask not Done. Research (2026-11-13): MLX decodes ~1.4-1.8x faster than llama.cpp on M-series but trails on long-prompt prefill and tool calling; macOS 27 ships Apple's fm CLI (Foundation Models, ~3B on-device, OpenAI-compatible fm serve) behind a one-time per-machine license.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-13 — paused by the operator to focus on stability. Done: .01 (work-light → Qwen3-4B-Instruct-2507), .02 (Apple on-device engine via fm, locked to the device). Deferred: .03 zaider edit format, .04 benchmark, .05 MLX lane, .06 GGUF cleanup. Resume with `backlog task view Z-361.03`. Benchmarks for the 16 GB baseline should be confirmed on an M4/16 GB machine, not only a larger one.
<!-- SECTION:NOTES:END -->
