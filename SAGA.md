# The Zdots Saga: From Dotfiles to Infrastructure

This document tells the chronological story of the Zdots repository—a journey from a standard Zsh configuration in 2017 to the **Deepened Shell Platform** it is today.

## Era I: Genesis & The Shallow Shell (2017)

**Theme:** Personalization, speed, and the "Standard" shell experience.

*   **2017-05-26**: Repository genesis (`e25021c`). The initial commit establishes a traditional Zsh setup focused on aliases, browser shortcuts, and basic path management.
*   **The "Save Point" Summer**: Hundreds of rapid-fire commits show a developer obsessively iterating on prompt aesthetics and directory navigation.
*   **Key Innovation**: The introduction of `zrecompile` and early lazy-loading attempts, signaling an early preoccupation with shell startup performance.

## Era II: The Refinement (2018–2022)

**Theme:** Standardization and the rise of workflow helpers.

*   **The P10k Pivot (2021)**: The adoption of **Powerlevel10k** (`481fdbf`) marked the end of custom prompt "sketching" and the beginning of a focus on a high-information, professional UI.
*   **Project Helpers**: The appearance of `w3r` and other "jerb" specific commands showed the shell evolving into a dedicated workstation for specific professional contexts.
*   **Liskov Substitution**: Early refactors move hardcoded paths into generic variables, preparing the ground for the "Deep" philosophy.

## Era III: The Great Awakening (Late 2025 – Q1 2026)

**Theme:** Modularization and the removal of technical debt.

*   **The Snapshot (2025-10-23)**: After a dormant period, the repo is revived for a modern age.
*   **Architectural Cleansing**: Removal of `antigen`, `asdf`, and other "shallow" plugin managers in favor of a lean, declarative core (`lib/`).
*   **CLAUDE.md & AGENTS.md**: The first explicit "Agent Instructions" appear, signaling that the primary user of the shell is no longer just a human, but a collaborative human-AI pair.

## Era IV: The Deepening & Local AI (April – May 2026)

**Theme:** High-performance inference and systemic observability.

*   **The AI Pivot (2026-04-18)**: Integration of `llama.cpp` and `whisper.cpp`. The shell becomes a host for local LLMs, with `llama-ctl` managing service lifecycles.
*   **OTel Everywhere**: Every shell command begins emitting OTel spans to a local LGTM stack. The shell is now an **Observable System**.
*   **The Intelligence Layer**: Implementation of `zdots-ctx` and a Postgres-backed "Shell Brain" for long-term memory and session residue distillation.

## Era V: Operation Martian & Sentience (Late May 2026)

**Theme:** Security, PHI safety, and autonomous orchestration.

*   **Operation Martian (2026-05-22)**: A massive security hardening effort. The introduction of the **PHI Scrubber**, history redaction hooks, and the removal of plaintext secrets in favor of the macOS Keychain.
*   **The Sentient Workbench**: Launch of `gemini-invoke`, `zdash`, and the "Smart State Machine" for background job orchestration.
*   **The 2026 SOTA Upgrade**: Integration of Qwen3 models, speculative decoding, and the high-performance YouTube transcription pipeline.

---

## Today: Infrastructure

Zdots is no longer a set of "dotfiles." It is a **deterministic developer enablement platform**. It is built on a performance budget of < 0.08s, guarded by a 300+ test BATS suite, and capable of local-only autonomous reasoning.

**We are Infrastructure.**
