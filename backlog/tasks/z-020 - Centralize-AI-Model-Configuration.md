---
id: Z-020
title: Centralize AI Model Configuration
status: To Do
assignee: []
created_date: '2026-03-28 02:20'
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
- [ ] #1 Create etc/ai-models.yaml with task-specific model mappings
- [ ] #2 Update .zdots.env to reference task profiles instead of raw model names
- [ ] #3 Modify AI providers to resolve models from the central config
- [ ] #4 Document the recommended 'base images' for local inference
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
