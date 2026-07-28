---
id: Z-250
title: >-
  [agent-issue] Recurring: embed model (nomic-embed-text-v2-moe.Q8_0.gguf) keeps
  disappearing from ~/.local/share/ll
status: To Do
assignee: []
created_date: '2026-07-22 12:34'
updated_date: '2026-07-28 17:39'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 126895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `255372c5168f0e694bae41e7302a296d`

Recurring: embed model (nomic-embed-text-v2-moe.Q8_0.gguf) keeps disappearing from ~/.local/share/llama-cpp/models — provenance WARNs 'not downloaded' while embeddings keep working (embed server PID 42821 up since Jul 20 09:43 held the fd open after the file was unlinked; re-downloaded Jul 22 07:29). Ruled out: disk (623G free), config rename (ai-models.yaml embed model_file unchanged), stray copies (none), model-prune (protects .profiles.<p>.model_file for ALL profiles incl embed). No static zdots code path deletes the protected embed model; needs cross-session/cron forensics. ADJACENT confirmed bug: 'llama-ctl model-download' with no args only fetches the active CHAT model and silently SKIPS embed — recovery needed 'ZDOTS_AI_PROFILE=embed llama-ctl model-download'. model-download should ensure ALL host-required models (chat+embed+active draft) matching the provenance required-set. Fix ideas: (1) model-download ensures embed; (2) provenance distinguishes open-fd-but-unlinked from never-downloaded.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-07-28: recurred again (4th time, 2026-07-27 12:29:32). See Z-260 notes — model restored + sha256-verified, durable tripwire armed (bin/embed-model-tripwire). Scratchpad tripwire from 07-24 died with its session; this one survives reboots.
<!-- SECTION:NOTES:END -->
