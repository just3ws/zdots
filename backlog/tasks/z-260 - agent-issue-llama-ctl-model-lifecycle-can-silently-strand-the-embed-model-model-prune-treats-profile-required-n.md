---
id: Z-260
title: >-
  [agent-issue] llama-ctl model lifecycle can silently strand the embed model:
  model-prune treats profile-required n
status: To Do
assignee: []
created_date: '2026-07-24 18:04'
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
