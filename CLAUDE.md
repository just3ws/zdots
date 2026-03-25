# CLAUDE.md — Agent Reference for Zdots

High-signal guide for AI agents interacting with this repository.

## Build & Validation
- **Run All Checks:** `bin/check` (Validates syntax, keybindings, and dependencies)
- **Bootstrap Environment:** `bin/bootstrap`
- **Benchmark Performance:** `make bench` or `bench 'zsh -i -c exit'`

## Repository Guidelines
- **Shell Startup:** Fast path optimization using `zsh-defer`.
- **Environment Variables:** Must be defined in `.zshenv`.
- **Interactive Modules:** Isolated in `conf.d/*.zsh`.
- **Custom Functions:** Stored in `functions/enabled/` (autoloded).
- **Aliases:** Global and DSL-like aliases are in `conf.d/80-aliases.zsh`.

## Theme & Styles
- **Primary Theme:** `ZDOTS_THEME=dracula-pro` (refined colors, rounded glyphs).
- **Sub-variants:** Supports `nord`, `dracula`, and `dracula-pro`.
- **Prompt:** Powerlevel10k with rounded segment separators (`\uE0B4`).
- **Styles:** Theme-specific syntax highlighting and autosuggestions in `assets/`.

## Performance Budget
- **Target Median Startup:** < 0.08s
- **Optimization Hooks:** `LS_COLORS` cached in `~/.cache/zsh/`, `compinit -C` daily caching.

## Agent Efficiency Tools
- **Codebase Stats:** `tokei`
- **Context Packing:** `repomix` (Generate context for LLMs)
- **Symbol Index:** `universal-ctags` (via `tags` file)
- **Config Parsing:** `dasel` (JSON/YAML/TOML/XML)
