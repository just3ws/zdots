---
id: Z-361
title: Local AI modernization for the 16 GB baseline
status: In Progress
assignee:
  - '@mike'
created_date: '2026-11-13T17:22:00Z'
updated_date: '2026-11-13T17:22:00Z'
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
