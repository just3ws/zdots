# AGENTS.md — Core Context for AI Agents

This repository is a modular, high-performance Zsh configuration ("Zdots"). All agents must adhere to the standards and use the tools defined below.

## Build & Validation
- **Run All Checks:** `make check` (Primary regression suite)
- **Bootstrap:** `make bootstrap`
- **Benchmark:** `make bench`
- **Environment Inquiries:** Run `bin/capabilities --json` for a structured, one-turn summary of all available tools, themes, and shell features (highly token efficient).

## Agent API (Standardized Tasks)
Always prefer these `make` commands for routine operations:
- **Project Mapping:** `make map` (High-signal tree of project structure)
- **Codebase Stats:** `make stats` (Lines of code and languages via `tokei`)
- **Refactoring:** `make refactor OLD='regex' NEW='replacement'` (Safe mass-replacement via `sd`)
- **Context Packing:** `make context` (Generate `.project-context.md` for LLM via `repomix`)
- **Structural Search:** `make search QUERY='pattern'` (AST-based search via `sg`)
- **Symbol Index:** `make tags` (Generate `tags` file for lookups)

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
- **Token Optimization:** **Always proxy high-output commands through `rtk`**.
- **Project State:** Refer to `backlog task list` for the current roadmap and milestones.
- **Config Parsing:** Use `dasel` or `yq` for safe structured data querying.

<!-- rtk-instructions v2 - HISTORY AWARE -->
## RTK (Rust Token Killer) - History-Aware Optimizations

**Golden Rule:** Prefix high-output commands with `rtk` to minimize token noise.

### 1. High-Volume JavaScript/TS Workflow (90% savings)
You frequently run deep verification suites. Always use these:
```bash
rtk pnpm verify:all     # Summarizes massive lint/test/typecheck logs
rtk pnpm playthrough:*  # Collapses long QA/Playwright trace logs
rtk pnpm install        # Compact dependency confirmations
rtk tsc                 # Groups TypeScript errors by file/code
```

### 2. Infrastructure & Cloud (85% savings)
Summarize noisy deployment and log events:
```bash
rtk fly deploy          # Highlights deployment events, hides progress spam
rtk fly logs            # Deduplicates log streams with hit counts
rtk docker logs         # Filters repetitive container output
```

### 3. Git & GitHub (60-80% savings)
Harden your context against massive diffs and logs:
```bash
rtk git status          # Ultra-compact status
rtk git diff            # Summarizes changes, prevents context flooding
rtk git log             # Compact commit history
rtk gh pr checks        # Clean table of CI status
```

### 4. Metadata & Analysis
```bash
rtk tokei               # Instant codebase orientation
rtk summary <cmd>       # Smart summary of any command output
rtk json <file>         # Schema-only view of large JSON files
```
<!-- /rtk-instructions -->

## Backlog.md - Task & Project State
This repository uses `backlog-md` (binary `backlog`) for task management. It is the **Source of Truth** for the project roadmap and task state.

**Agent Instructions:**
- **Discovery:** Run `backlog tasks` to see the current task list and status.
- **Context:** Read individual tasks in the `backlog/` directory for deep requirements.
- **Updates:** After completing a task, update its status via the `backlog` CLI or by editing the Markdown file directly.
- **Standard:** Prefer `backlog` commands for high-level status and manual Markdown edits for detailed notes.

## Tooling Standards
- **History:** `atuin` (SQLite) with `history_enquire` (`he`) for maintenance.
- **Search:** `fzf` + `fzf-tab` integration.
- **File System:** `zoxide` (`z`), `eza` (aliased to `ls`), and `broot` (`br`) for weighted tree navigation.
- **AI Integration:** Use the `ai` function to pipe command output into patterns (e.g., `cat logs.txt | ai summarize`).
- **Data Handling:** `jless`/`fx` for interactive JSON exploration.
- **GitHub:** Use `gh dash` for a full overview of PRs and Issues.

## Safety & Quality
- **Commits:** Use `git absorb` to automatically attribute fixup changes to the correct commit.
- **Guardrails:** This repository uses `pre-commit` to automate secret scanning (`gitleaks`) and script validation.
