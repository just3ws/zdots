---
id: Z-260
title: >-
  [agent-issue] llama-ctl model lifecycle can silently strand the embed model:
  model-prune treats profile-required n
status: To Do
assignee: []
created_date: '2026-07-24 18:04'
updated_date: '2026-07-24 22:06'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 136895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `38d346f51c4879ad62fa3e922070345d`

llama-ctl model lifecycle can silently strand the embed model: model-prune treats profile-required nomic-embed GGUF as orphan (deleted it while server held the inode), model-download only fetches the chat model and skips embed, and 'embed install' restarts the service without verifying the model file exists — turning a latent failure into an outage. Restored today by manual HF download + sha256 verify. Repro chain and fix surface all in llama-ctl.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ESCALATION 2026-07-24 (2nd + 3rd deletion same day): the embed GGUF was re-downloaded (sha256 verified) at 14:44 and deleted again by ~15:05 (zdots doctor at 15:05 warned 'not downloaded' while the embed server held the dead inode; models dir mtime showed 15:43). Re-downloaded 17:02 and experimentally exonerated: zdots doctor --quiet, zsvc restart worker, graphify update, llama-ctl model-list — file survives all four. Deleter unidentified; candidates in the deletion window: context-engine bin/deploy, bats/rspec runs, backlog CLI. A tripwire watcher now logs the process table + recent command_runs the moment the file vanishes (session scratchpad). Embed restarted onto the live inode at 17:0x; doctor fully clean (0 warnings, hash OK). Treat as active recurring deletion, not one-time prune accident.
<!-- SECTION:NOTES:END -->
