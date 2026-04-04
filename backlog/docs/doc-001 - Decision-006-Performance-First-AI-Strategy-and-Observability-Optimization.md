---
id: doc-001
title: Decision 006 - Performance-First AI Strategy and Observability Optimization
type: other
created_date: '2026-04-04 15:31'
---
# Decision 006: Performance-First AI Strategy & Observability Optimization

**Date:** 2026-04-04
**Status:** Active
**Context:** The "Dwight Schrute Principle" (avoiding idiocy/inefficiency) has been adopted as a foundational mandate.

## Problem Statement
1. **Observability Overhead:** The current shell observability hooks (`preexec`, `precmd`) fork 10+ external processes (date, sed, openssl) per command, causing measurable latency.
2. **Storage Constraints:** The user has limited primary storage and has uninstalled Ollama.
3. **Blocking AI Init:** AI initialization currently performs synchronous `curl` health checks that block shell startup.

## Strategic Shift
- **Primary Goal:** Minimize shell latency and process forking.
- **AI Focus:** Transition to `llama.cpp` for performance and storage efficiency.
- **Storage Strategy:** Support external model storage via `ZDOTS_AI_MODELS_DIR` and implement model pruning.
- **Asynchronicity:** All health checks and telemetry must be backgrounded or cached.

## Current Prioritization (Next Best Actions)
1. **[Z-031] Optimize Observability Hooks:** Replace external forks in `preexec`/`precmd` with Zsh built-ins (strftime, parameter expansion). **This is the highest priority.**
2. **[Z-033] Hardened llama.cpp Integration:** Implement non-blocking init and external storage support for `llama.cpp`.
3. **[Z-034] Context-Aware AI Shell Integration:** Design the `?` / `ai` alias for high-signal shell assistance.

## Implementation Notes for Future Agents
- **No Bypassing:** Never use `--no-verify` or suppress performance warnings.
- **Zsh-Native First:** Always prefer `${var//search/replace}` over `sed` and `zsh/datetime` over `date`.
- **Backgrounding:** Use `&!` for telemetry and health checks to ensure zero impact on the user's prompt availability.
