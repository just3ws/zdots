# Zsh Configuration & Toolchain Dependencies
# This file tracks all Homebrew dependencies required for the zsh environment.

# ------------------------------------------------------------------------------
# Core Shell & Prompt
# ------------------------------------------------------------------------------
tap "romkatv/powerlevel10k"
brew "zsh"              # The shell itself.
brew "powerlevel10k"    # The theme engine; depends on Fira Code Nerd Font.
brew "vivid"            # LS_COLORS generator; used in conf.d/30-env.zsh for theme-specific colors.

# ------------------------------------------------------------------------------
# Navigation & Search
# ------------------------------------------------------------------------------
brew "zoxide"           # Better 'cd' (aliased to 'z'); initialized in conf.d/70-integrations.zsh.
brew "fzf"              # Fuzzy finder; provides Ctrl-R and Ctrl-T widgets via conf.d/70-integrations.zsh.
brew "fzf-tab"          # Replaces zsh completion menu with fzf; sourced in conf.d/70-integrations.zsh.
brew "eza"              # Modern 'ls' replacement; used for aliases (ls, ll, la) in .aliasrc.
brew "fd"               # Modern 'find' replacement; used as the default search backend in fzfrc.
brew "ripgrep"          # Fast text search; often used as an alternative fzf backend.
brew "tree"             # Directory tree visualization; used for fzf previews in fzfrc.

# ------------------------------------------------------------------------------
# UI & Productivity
# ------------------------------------------------------------------------------
brew "atuin"            # SQLite-backed history sync/search; replaces Ctrl-R in conf.d/70-integrations.zsh.
brew "lazygit"          # Git TUI; aliased to 'lg' in conf.d/80-aliases.zsh.
brew "bat"              # Syntax-highlighted 'cat' and fzf previewer; used in .aliasrc and fzfrc.
brew "jless"            # Interactive JSON pager; used for viewing JSON API responses.
brew "fx"               # Terminal JSON viewer/processor; used for interactive data exploration.
brew "bottom"           # Graphical process monitor; aliased to 'top' and 'htop' in conf.d/80-aliases.zsh.
brew "tealdeer"         # Fast 'tldr' client; provides practical command examples aliased to 'help'.
brew "boxes"            # Draws ASCII boxes around text; occasionally used for banners/comments.

# ------------------------------------------------------------------------------
# Development Toolchain
# ------------------------------------------------------------------------------
brew "mise"             # Polyglot runtime manager; replaces asdf; activated in .zprofile and conf.d/90-mise.zsh.
brew "gh"               # GitHub CLI; provides _gh completion and repo management.
brew "repomix"          # Packs repository context for AI agents (token efficiency).
brew "tokei"            # Fast code statistics; provides high-signal project metadata.
brew "universal-ctags"  # Symbol indexing; allows agents to find definitions quickly.
brew "ast-grep"         # Structural code search/rewrite (binary 'sg'); used for code refactoring.
brew "hyperfine"        # Benchmarking tool; aliased to 'bench' for measuring startup/command performance.
brew "pnpm"             # Fast, disk-efficient package manager; used extensively in TS/JS projects.
brew "flyctl"           # Fly.io CLI (binary 'fly'); used for deployments via 'fd', 'fds', 'fdp' aliases.
brew "rtk"              # CLI proxy to minimize LLM token consumption.
brew "backlog-md"       # Markdown-native task manager (binary 'backlog'); provides agent context.
brew "gemini-cli"       # CLI for Gemini AI; aliased to 'gm' in conf.d/80-aliases.zsh.

# ------------------------------------------------------------------------------
# Security & Validation
# ------------------------------------------------------------------------------
brew "shellcheck"       # Bash/sh script linter; used by bin/check to validate repo scripts.
brew "actionlint"       # GitHub Actions workflow linter; ensures CI stability.
brew "pre-commit"       # Git hook manager; automates safety and quality checks.
brew "dasel"            # JSON/YAML/TOML/XML parser; used for agent-friendly config querying.
brew "sqlite"           # SQLite CLI; used by bin/history-import to manage the history database.
brew "gitleaks"         # Secret scanner; used to prevent sensitive data commits.

# ------------------------------------------------------------------------------
# System Libraries
# ------------------------------------------------------------------------------
brew "coreutils"        # GNU versions of basic system utilities (ls, cp, mv).
brew "jemalloc"         # High-performance malloc implementation; used in RUBY_CONFIGURE_OPTS.
brew "openssl@3"        # Cryptography toolkit; used by Ruby/Node build processes.
brew "postgresql@18"    # Postgres client tools and headers.

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
cask "font-fira-code-nerd-font"      # Preferred font for Powerlevel10k glyphs.
