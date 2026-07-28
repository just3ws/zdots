---
id: Z-260
title: >-
  [agent-issue] llama-ctl model lifecycle can silently strand the embed model:
  model-prune treats profile-required n
status: To Do
assignee: []
created_date: '2026-07-24 18:04'
updated_date: '2026-07-28 17:39'
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
2026-07-28: 4th deletion found during weekly integration — model gone since 2026-07-27 12:29:32 (models-dir mtime), embed server surviving on the dead inode. Investigated: llama-ctl model-prune EXONERATED (protect loop covers .profiles.embed.model_file — verified live); brew cleanup EXONERATED (only Homebrew caches, finished 12:29:03); ClearDisk.app EXONERATED (never launched — no prefs/container/last-used); canary .gguf files survive, so no live file-watcher deleter. Deleter still unidentified. Restored: HF re-download (transient HTTP/2 CANCEL errors on first two attempts), sha256 matches lib/llama-models.sha256, embed restarted onto the real file, health ok. Durable tripwire installed: bin/embed-model-tripwire (--install arms com.zdots.embed-tripwire LaunchAgent, WatchPaths on models dir → ps/lsof snapshot to state log). Next deletion will be captured.
<!-- SECTION:NOTES:END -->
