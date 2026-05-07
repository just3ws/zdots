# Zsh Configuration & Toolchain Dependencies
# This file tracks Homebrew dependencies required for this shell environment.

# ------------------------------------------------------------------------------
# Core Shell & Prompt (Powering the Interactive Experience)
# ------------------------------------------------------------------------------
tap "romkatv/powerlevel10k"
brew "zsh"              # Primary shell; configured via .zshrc and conf.d/
brew "powerlevel10k"    # Prompt engine; depends on Fira Code Nerd Font for glyphs.
brew "vivid"            # LS_COLORS generator; used in conf.d/30-env.zsh for theme-specific colors.

# ------------------------------------------------------------------------------
# Navigation & Search (Fundamentals of the Shell)
# ------------------------------------------------------------------------------
brew "zoxide"           # Better 'cd' (aliased to 'z'); initialized in conf.d/70-integrations.zsh.
brew "fzf"              # Fuzzy finder; provides Ctrl-R/Ctrl-T widgets via conf.d/70-integrations.zsh.
brew "fzf-tab"          # Replaces zsh completion menu with fzf; sourced in conf.d/70-integrations.zsh.
brew "eza"              # Modern 'ls'; used for aliases (ls, ll, la) in .aliasrc.
brew "fd"               # Modern 'find'; search backend for fzf in fzfrc.
brew "ripgrep"          # Fast text search; used as grep alternative and fzf backend.
brew "ack"              # Alternative search tool; found in history usage.
brew "tree"             # Directory tree visualization; used for fzf previews in fzfrc.
brew "sd"               # Intuitive find & replace CLI (sed alternative); used for refactoring.
brew "television"       # Modern TUI browser; agent-friendly interface for data navigation.

# ------------------------------------------------------------------------------
# AI & Agent Infrastructure (Maximizing Token Efficiency & Context)
# ------------------------------------------------------------------------------
brew "repomix"          # Packs repository context for LLMs (Critical for token efficiency).
brew "rtk"              # CLI proxy to minimize LLM token consumption (High-signal summaries).
brew "backlog-md"       # Markdown task manager; provides project state/roadmap to agents.
brew "tokei"            # Blazingly fast code stats; provides project metadata to agents.
brew "universal-ctags"  # Symbol indexing; allows agents to find definitions without deep scans.
brew "ast-grep"         # Structural code search (sg); used for complex refactoring by agents.
brew "fabric-ai"        # AI workflow pattern executor.
brew "llama.cpp"        # Local LLM inference server; OpenAI-compatible API on :8080.
brew "whisper.cpp"      # High-performance inference of OpenAI's Whisper ASR models.
brew "otel-cli"         # OpenTelemetry CLI; useful for ad-hoc shell spans.
brew "gemini-cli"       # Google Gemini AI CLI; aliased to 'gm' in conf.d/80-aliases.zsh.
brew "usage"            # CLI specification tool; helps agents understand CLI parameters.

# ------------------------------------------------------------------------------
# Data Processing (Structured Context for Humans and Agents)
# ------------------------------------------------------------------------------
brew "jq"               # JSON processor; used via 'J' global alias in conf.d/80-aliases.zsh.
brew "yq"               # YAML processor; essential for config manipulation (mise, fly, actions).
brew "dasel"            # Unified JSON/YAML/TOML/XML query tool; used for agent-friendly config lookups.
brew "fx"               # Terminal JSON viewer; interactive data exploration.
brew "jless"            # Interactive JSON pager; similar to 'less' but for structured data.
brew "glow"             # Markdown renderer; used for reading repository docs (README, CLAUDE.md).

# ------------------------------------------------------------------------------
# UI & Productivity
# ------------------------------------------------------------------------------
brew "atuin"            # SQLite-backed history sync/search; replaces Ctrl-R in conf.d/70-integrations.zsh.
brew "lazygit"          # Git TUI; aliased to 'lg' in conf.d/80-aliases.zsh.
brew "bat"              # Syntax-highlighted 'cat' and fzf previewer; used in .aliasrc and fzfrc.
brew "bottom"           # Graphical process monitor; aliased to 'top' and 'htop' in conf.d/80-aliases.zsh.
brew "tealdeer"         # Fast 'tldr' client; provides command examples aliased to 'help'.
brew "boxes"            # Draws ASCII boxes; used for banners and code documentation.

# ------------------------------------------------------------------------------
# Development Toolchain & Runtimes
# ------------------------------------------------------------------------------
brew "mise"             # Polyglot runtime manager; replaces asdf; activated in .zprofile.
brew "pnpm"             # Fast package manager; used extensively in TS/JS development.
brew "uv"               # Extremely fast Python package manager; modern standard for Python.
brew "gh"               # GitHub CLI; provides _gh completion and repo management.
# gh extension install dlvhdr/gh-dash (TUI for GitHub PRs/Issues)
brew "git-absorb"       # Automatic git commit --fixup (Highly efficient for agents).
brew "flyctl"           # Fly.io CLI (fly); used for cloud deployments via 'fd' aliases.
brew "hyperfine"        # Benchmarking tool; used by bin/check to enforce performance budget.
brew "broot"            # Weighted tree navigation and project mapping.
brew "postgresql@18"    # Postgres client tools; path managed in .zshenv.
brew "openjdk"          # Java Runtime; JAVA_HOME and path managed in .zshenv.

# ------------------------------------------------------------------------------
# Security, Infrastructure & Validation
# ------------------------------------------------------------------------------
brew "bats-core"        # Bash Automated Testing System; core runner.
brew "bats-support"     # Bats helper library: base utilities for test output.
brew "bats-assert"      # Bats helper library: assert_output, assert_failure, etc.
brew "bats-file"        # Bats helper library: assert_file_exists, assert_dir_exists.
brew "shellcheck"       # Bash/sh linter; used by bin/check to validate repo scripts.
brew "shfmt"            # Shell script formatter.
brew "actionlint"       # GitHub Actions linter; ensures CI stability.
brew "act"              # Run GitHub Actions locally for rapid iteration.
brew "colima"           # Container runtime (lightweight CLI-driven alternative to Docker Desktop).
brew "docker"           # Docker CLI client.
brew "docker-compose"   # Docker Compose V2 plugin.
brew "docker-compose-langserver" # LSP for Docker Compose.
brew "pre-commit"       # Git hook manager; automates safety and quality checks.
brew "gitleaks"         # Secret scanner; prevents sensitive data leaks.
brew "trufflehog"       # Advanced secret scanner; deep historical scanning.
brew "git-lfs"          # Git Large File Storage; manages binary assets.
brew "sqlite"           # SQLite CLI; powers atuin and bin/history-import.
brew "coreutils"        # GNU system utilities; provides consistent behavior across platforms.
brew "openssl@3"        # Cryptography toolkit; dependency for Node/Ruby builds.
brew "jemalloc"         # High-performance malloc; optimized for Ruby (RUBY_CONFIGURE_OPTS).

# ------------------------------------------------------------------------------
# Zsh Plugins (Sourced in .zshrc or conf.d/70-integrations.zsh)
# ------------------------------------------------------------------------------
brew "zsh-autosuggestions"          # Fish-like autosuggestions.
brew "zsh-completions"              # Additional completion definitions.
brew "zsh-syntax-highlighting"      # Fish-like syntax highlighting.
brew "zsh-history-substring-search" # Up/Down arrows search through history matches.
brew "zsh-history-enquirer"         # Interactive history cleanup and management.
brew "zsh-autopair"                 # Auto-close brackets, quotes, etc.
brew "zsh-you-should-use"           # Alias coach; reminds you of existing shortcuts.
brew "zsh-vi-mode"                  # Improved Vi-mode experience with mode indicators.

# ------------------------------------------------------------------------------
# Casks
# ------------------------------------------------------------------------------
cask "font-fira-code-nerd-font"      # Preferred font for Powerlevel10k and UI glyphs.
