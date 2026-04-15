---
id: Z-025
title: Automate AI Model Hydration (Smart Pull)
status: Done
assignee: []
created_date: '2026-03-28 17:23'
updated_date: '2026-04-15 15:42'
labels: []
milestone: m-2
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement a bootstrap mechanism to automatically pull the specific LLM models required by the active ZDOTS_AI_PROFILE. This ensures AI features are ready immediately upon shell initialization while respecting disk space.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Add 'hydrate' command to AI providers
- [x] #2 Integrate model hydration into bin/bootstrap
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
AC #1: llama-ctl hydrate added — idempotent alias for model-download, skips if GGUF already present.\nAC #2: bin/bootstrap step 6 calls llama-ctl hydrate after brew bundle. Graceful skip if llama-ctl unavailable.\nAlso fixed all stale 'llama-server' references in llama-ctl output strings.\nmake check: 14/14 pass.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
