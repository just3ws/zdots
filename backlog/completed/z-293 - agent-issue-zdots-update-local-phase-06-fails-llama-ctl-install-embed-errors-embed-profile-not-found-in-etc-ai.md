---
id: Z-293
title: >-
  [agent-issue] zdots-update-local phase 06 fails: llama-ctl install-embed
  errors 'embed profile not found in etc/ai
status: Done
assignee: []
created_date: '2026-06-16 14:11'
updated_date: '2026-06-16 14:43'
labels:
  - agent-reported
  - error
dependencies: []
modified_files:
  - bin/llama-ctl
priority: medium
ordinal: 46890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `61a00b107a8e08cb4bd65ada55c93136`

zdots-update-local phase 06 fails: llama-ctl install-embed errors 'embed profile not found in etc/ai-models.yaml' — embed service cannot be registered via update path

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed in bin/llama-ctl (commit 657d2c9). Root cause: install_embed and _register_embed_plist called _meta_get "profiles.embed.*" but _meta_get operates on the flat active-profile JSON (server + resolved profile merged) — the profiles.* namespace never exists there. Switched to _yq_get for profiles.embed.{model_file,ctx_size,n_gpu_layers,hf_repo}, which reads directly from etc/ai-models.yaml. Model downloaded (nomic-embed-text-v2-moe.Q8_0.gguf, 496MB), plist registered, embed service confirmed healthy at http://127.0.0.1:11501.
<!-- SECTION:FINAL_SUMMARY:END -->
