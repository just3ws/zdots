# AGENTS.md — Core Context for AI Agents

This repository is a modular, high-performance Zsh configuration ("Zdots"). All agents must adhere to the standards and use the tools defined below.

## Build & Validation
- **Run All Checks:** `bin/check` (Validates syntax, keybindings, and dependencies)
- **Bootstrap Environment:** `bin/bootstrap`
- **Benchmark Performance:** `bench 'zsh -i -c exit'` (Target median startup < 0.08s)
- **Environment Inquiries:** Run `bin/capabilities` for a one-turn, high-density summary of all available tools, themes, and shell features (highly token efficient).

## Repository Architecture
- **Environment Variables:** MUST be defined in `.zshenv`.
- **Interactive Modules:** Isolated in `conf.d/*.zsh`.
- **Custom Functions:** Autoloaded from `functions/enabled/`.
- **Aliases:** Global and DSL-like aliases live in `conf.d/80-aliases.zsh`.
- **Startup Logic:** Use the `zdefer` helper in `conf.d/70-integrations.zsh` for lazy-loading.

## Theme & Visual Standards
- **Theme:** `ZDOTS_THEME=dracula-pro` (Sub-variants: `nord`, `dracula`).
- **Prompt:** Powerlevel10k with rounded segment separators (`\uE0B4`).
- **Styles:** Theme-specific syntax highlighting and autosuggestions in `assets/`.

## Agent Efficiency Infrastructure
- **Context:** Use `repomix` to pack the repo into high-density context.
- **Metadata:** Use `tokei` for codebase stats and `universal-ctags` for symbols.
- **Token Optimization:** Proxy expensive commands through `rtk` (e.g., `rtk pnpm test`).
- **Project State:** Refer to `backlog task list` for the current roadmap and milestones.
- **Config Parsing:** Use `dasel` or `yq` for safe structured data querying.

## Tooling Standards
- **History:** `atuin` (SQLite) with `history_enquire` (`he`) for maintenance.
- **Search:** `fzf` + `fzf-tab` integration.
- **File System:** `zoxide` (`z`) and `eza` (aliased to `ls`).
- **Data Handling:** `jless`/`fx` for interactive JSON exploration.
