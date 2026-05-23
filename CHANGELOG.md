# Changelog

This changelog summarizes the historical evolution of this repository from existing commit history.

## May 2026 — Local AI Routing Layer

- `bin/zdots-ask`: domain-aware prompt router — keyword scan → inject system prompt → local llama.cpp; `--dry-run`, `--domain`, `--list-domains` flags.
- `bin/zdots-quiz`: 14-case capability probe with `--quick` (3-case) and `--verbose` flags; retry logic on empty model response.
- `etc/prompts/zdots-{default,shell,ruby,phi}.md`: compact system prompts above 256-token `cache_reuse` threshold; caveman voice enshrined.
- `bin/ai-query`: `AIQ_SUPPRESS_RAW_WARN=1` suppresses raw-mode warning for trusted internal callers.
- `bin/zdots-ctl check`: AI router structural verification section (files, domains, dry-run test).
- `docs/local-ai.md`: full architecture, routing decision tree, failure state diagram, capability delegation map, new-machine verification sequence.
- Backlog: Z-092 (context hydration), Z-093 (zdash/llama-ctl quiz), DRAFT-001 (output contracts).

## May 2026 — Operation Martian (PHI Security + TUI)

**PHI Safety (15-task DAG, Z-077–Z-091 — all complete):**

- Defined PHI data boundary policy (`backlog/docs/doc-002`).
- `lib/ai_boundary.bash`: `zdots_ai_gate` (exit 2 on `ZDOTS_AI_MODE=none`) and `zdots_assert_local_endpoint` (hard-fail if non-RFC-1918 in local mode).
- `lib/phi_scrubber.bash`: SSN, MRN, DOB, connection string redaction before every AI call and history write.
- `zshaddhistory` hook: PHI patterns stripped from shell history (`ZDOTS_HISTORY_REDACT=1`).
- `ZDOTS_AI_MODE=none` graceful degradation: all AI tools exit cleanly with exit code 2.
- Secrets migrated to macOS Keychain: `lib/keychain.bash` + `bin/zdots-keychain` CLI. `.zdots.secrets` is now credential-free.
- `ZDOTS_DB_ENCRYPTION_KEY` in Keychain; pgcrypto migration encrypts PHI columns at rest; `zdots_ro` sees ciphertext only.
- `lib/audit_log.bash`: PHI-adjacent operations logged to macOS Unified Logging (`com.zdots/phi-boundary`).
- `lib/llama-models.sha256`: SHA256 manifest; `llama-ctl start` refuses mismatched model files.
- llama-server loopback-only (`127.0.0.1`), models dir `chmod 700` enforced at install.
- `zdots-ctl check`: llama plist/socket/models, model hash, audit log, macOS posture (FileVault/SIP/Firewall hard-fail on work).
- Bootstrap PHI-SAFE OPERATING MODE banner; `ZDOTS_DB_ENCRYPTION_KEY` warning on work context.
- `AGENTS.md` Section 8: PHI Operating Mode. `AIDER.md`/`GEMINI.md` callouts added.

**TUI + Workflow:**

- `bin/zdash`: fzf task launcher with Pi/Aider/status/done keybindings; self-hosting `--list`/`--preview`.
- `bin/zmorning`: session ritual → zdash by default; `--pi` for conversational orientation.
- `conf.d/97-zle-ai.zsh`: Alt-e (explain), Alt-f (fix last failure), Alt-z (open zdash).
- `providers/ai/pi.zsh`: `zpi()` with boundary enforcement and Keychain session dir.
- `PI.md`: Pi usage guide and Pi↔Aider boundary.

## May 2026 - SOTA AI Upgrade

- Integrated Taoism, Zen, Agile, and Software Craftsmanship manifestos into `GEMINI.md` as foundational architectural values.
- Implemented `DocsSync` pipeline for `GEMINI.md` to ensure automatic alignment with session residues.
- Added baseline database migration for intelligence suite.
- Integrated character-based heuristics (Schrute, Costanza, Malone, et al.) into global memory (local).
- Fixed: set explicit migration table (`zdots_schema_migrations`) in `zdots-migrator` to prevent collision.


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
