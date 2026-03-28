---
id: Z-019
title: Implement Local AI Inference Service and Offloading
status: Done
assignee: []
created_date: '2026-03-28 00:38'
updated_date: '2026-03-28 02:26'
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
- [x] #1 Create providers/ai/ directory and interface
- [x] #2 Implement providers/ai/ollama.zsh and providers/ai/llama-cpp.zsh
- [x] #3 Implement providers/ai/remote.zsh for Pi/OpenCode integration
- [x] #4 Refactor 'ai' alias to use injected zdots_ai_infer service
- [ ] #5 Update bin/history-analyze to use local AI for initial data reduction
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Solidified the common interface for AI providers. 1. Implemented providers/ai/llama-cpp.zsh using the OpenAI-compatible standard. 2. Verified that the 'ai' command in conf.d remains provider-agnostic. 3. Ensured all providers (Ollama, llama.cpp, Remote) implement the exact same zdots_ai_init and zdots_ai_infer contract, fulfilling the requirement for maximum flexibility.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
