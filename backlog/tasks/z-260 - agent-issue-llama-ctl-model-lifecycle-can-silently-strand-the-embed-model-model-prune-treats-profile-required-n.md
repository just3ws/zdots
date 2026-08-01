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

2026-07-31: DELETER IDENTIFIED — tripwire caught the 5th deletion (fired 2026-07-29 09:00:55; second firing 16:28:32 was the already-missing re-check). Snapshot 1 shows `fabric-ai --updatepatterns` (PID 24788, foreground tty s000) starting at 9:00AM in a fresh 08:57 login shell: that is step 4 of `functions/enabled/upgrade-ai`, whose step-3 prune (lines 64-78) deletes EVERY .gguf except the ACTIVE chat profile's model_file — the embed model is permanently "stale" to it. The morning upgrade ritual was the serial killer; llama-ctl model-prune was correctly exonerated on 07-28 (it protects all profiles). FIXED (operator-authorized fix-forward session): upgrade-ai now builds its protect list from `yq '.profiles[].model_file'` — same contract as llama-ctl model_prune. Verified with a scratch models dir: Qwen + nomic protected, true stray pruned. Model restored via `ZDOTS_AI_PROFILE=embed llama-ctl model-download` (sha256 verified), embed restarted onto the live inode (PID 86167), health ok. Remaining upstream ask (original scope): model-download without profile still skips embed; `embed install` still doesn't verify the model file exists before restart.
<!-- SECTION:NOTES:END -->
