---
id: Z-020
title: Centralize AI Model Configuration
status: Done
assignee: []
created_date: '2026-03-28 02:20'
updated_date: '2026-03-28 02:20'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Move AI model selection and parameters into a central machine-readable configuration file (etc/ai-models.yaml). This allows for easier management of local LLM 'base images' optimized for different tasks (coding, parsing, reasoning).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Create etc/ai-models.yaml with task-specific model mappings
- [x] #2 Update .zdots.env to reference task profiles instead of raw model names
- [x] #3 Modify AI providers to resolve models from the central config
- [x] #4 Document the recommended 'base images' for local inference
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Centralized AI model management. 1. Created etc/ai-models.yaml with task-specific profiles (standard, parser, reasoning). 2. Defined 'qwen3-coder:7b' as the gold-standard base image for coding and CLI generation. 3. Updated ollama provider to resolve models from the YAML config via 'yq' (with a robust llama3.2 fallback). 4. Added AI profile selection to .zdots.env.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
