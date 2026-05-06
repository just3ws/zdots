# Changelog

This changelog summarizes the historical evolution of this repository from existing commit history.

## May 2026 - SOTA AI Upgrade

- Upgraded local inference stack to May 2026 State-of-the-Art models (Qwen 2.5 Coder, DeepSeek V3, Nomic Embed v2 MoE).
- Enhanced `llama-ctl` to support authenticated downloads via `HUGGINGFACE_TOKEN`.
- Optimized Aider for local SOTA with `architect` mode and low-load `laid` command.
- Updated documentation and validation suites for new model capabilities.

## 2026 (36 commits) - Hardening + Modernization

- Modularized startup and removed legacy helper stack.
- Added and expanded `bin/check`, Make workflows, and CI validation gates.
- Hardened shell defaults and diagnostics (startup, compaudit, linting ergonomics).
- Added history import/analyze pipeline with redaction and documentation.
- Strengthened keybinding behavior (`^R`/FZF), history mode policy, and regressions checks.
- Added startup performance budget and non-blocking timing reporting.

## 2025 (1 commit) - Snapshot

- Snapshot before larger refactor/hardening work.

## 2022 (13 commits) - Toolchain + Environment Maintenance

- Iterative updates around asdf/nvim and language tooling.
- Additional iTerm/prompt and config tidy-up passes.
- Mostly maintenance and checkpoint-style changes.

## 2021 (43 commits) - Expansion + Workflow Helpers

- Large update cycle with restoration/cleanup and helper tooling growth.
- Migration toward Powerlevel10k prompt configuration.
- Added/iterated project helper commands and shell ergonomics.

## 2020 (1 commit) - Checkpoint

- Single repository checkpoint.

## 2019 (2 commits) - Sparse Maintenance

- Minor RVM/employer helper adjustments.

## 2018 (14 commits) - Prompt/UI Cleanup Cycle

- Prompt and icon refinement.
- General refactoring and cleanup.
- Removed dead or unused config pieces.

## 2017 (90 commits) - Foundation + Initial Structure

- Initial Zsh setup and bootstrap behavior.
- Heavy reorganization of aliases, functions, prompt, and docs.
- Added iTerm2 integration and zstyle/vcs prompt improvements.
- Reduced hardcoded paths and improved portability.
