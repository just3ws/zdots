---
id: decision-005
title: Local LLM Offloading for Shell Intelligence
date: '2026-03-28 17:23'
status: accepted
---
## Context

Shell intelligence features (history analysis, log parsing, command suggestions) require LLM inference. Using frontier models for routine shell-level tasks is wasteful and creates an external dependency. Local inference keeps the shell self-contained and respects the FOSS-native principle.

## Decision

Offload routine shell intelligence tasks to local LLM providers (Ollama, llama.cpp) running on the host or local network. Frontier models are reserved for complex reasoning. The AI service uses the same Dependency Injection pattern as other providers: zdots_ai_init() and zdots_ai_infer() contract, configured via ZDOTS_SERVICE_AI in .zdots.env.

## Consequences

Positive: Shell intelligence works offline. No API costs for routine tasks. Provider-agnostic — switch between Ollama, llama.cpp, or remote with one config change. Negative: Requires local GPU/CPU resources. Model quality is lower than frontier. Initial model download (hydration) adds setup friction.
