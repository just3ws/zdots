---
id: Z-295
title: '[agent-issue] llama.cpp server up but not responding to inference requests'
status: Done
assignee: []
created_date: '2026-08-07 18:13'
updated_date: '2026-08-20 13:55'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 170895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `6c2b280e6d47707657cc35934e3c6cc6`

zdots-watch doctor run (2026-08-07T13:08:46) reported two related FAILs, same root cause:
- AI inference: 'server up but not responding to chat requests'
- AI integration: 'server up but inference not responding after 30s readiness wait'

zsvc list shows llama-server RUNNING (pid 845, http://127.0.0.1:11500) and llama-embed RUNNING (pid 844, http://127.0.0.1:11501) — process is alive but not serving inference. Doctor's own suggested fixes: 'zsvc logs llama' (check for GPU OOM or startup errors), 'zsvc restart llama'.

Evidence: /Users/mike/.local/state/zsh/zdots-watch-runs/doctor-20260807T130846.19320.log

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified resolved 2026-08-20: live curl to /v1/chat/completions returned a proper completion. llama-server answering inference normally.
<!-- SECTION:NOTES:END -->
