---
id: Z-019
title: Implement Local AI Inference Service and Offloading
status: To Do
assignee: []
created_date: '2026-03-28 00:38'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Introduce a modular AI service provider to handle local inference tasks (e.g., log parsing, history summarization). This offloads low-level processing from frontier models to local instances like Ollama, llama.cpp, or remote-local Pi nodes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Create providers/ai/ directory and interface
- [ ] #2 Implement providers/ai/ollama.zsh and providers/ai/llama-cpp.zsh
- [ ] #3 Implement providers/ai/remote.zsh for Pi/OpenCode integration
- [ ] #4 Refactor 'ai' alias to use injected zdots_ai_infer service
- [ ] #5 Update bin/history-analyze to use local AI for initial data reduction
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
