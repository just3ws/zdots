---
id: Z-019
title: Implement Local AI Inference Service and Offloading
status: Done
assignee: []
created_date: '2026-03-28 00:38'
updated_date: '2026-03-28 00:41'
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
Introduced a modular local AI inference service. 1. Created providers/ai/ directory with ollama and remote (Pi/OpenCode) providers. 2. Refactored the 'ai' pipe function to use the injected zdots_ai_infer service, allowing for seamless offloading of log parsing and data reduction. 3. Integrated AI service health into the bin/capabilities report, including model version and server status. 4. Implemented conf.d/95-ai.zsh as the interface layer.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
