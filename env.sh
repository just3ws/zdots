# env.sh — POSIX-compatible environment core
# This file is sourced by sh, bash, and zsh.

# 1. XDG Base Directory Specification
export XDG_ROOT="$HOME"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$XDG_ROOT/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$XDG_ROOT/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$XDG_ROOT/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$XDG_ROOT/.local/share}"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# 2. General Environment
export LANG='en_US.UTF-8'
export EDITOR='vi' # Baseline, refined below
export VISUAL="$EDITOR"
export PGPASSFILE="${HOME}/.pgpass"
export DOCKER_CLI_HINTS=false
export ENABLE_LSP_TOOL=1
export ZDOTS_THEME="${ZDOTS_THEME:-dracula-pro}"

# 3. Language-Specific XDG Alignment
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
export GOPATH="$XDG_DATA_HOME/go"
export GEM_HOME="$XDG_DATA_HOME/gem"
export GEM_PATH="$GEM_HOME"
export PYTHONUSERBASE="$XDG_DATA_HOME/python"

# 4. Homebrew Core Detection
if [ -z "${HOMEBREW_PREFIX:-}" ]; then
  if [ -d /opt/homebrew ]; then
    export HOMEBREW_PREFIX=/opt/homebrew
  elif [ -d /usr/local ]; then
    export HOMEBREW_PREFIX=/usr/local
  fi
fi

if [ -n "${HOMEBREW_PREFIX:-}" ]; then
  export HOMEBREW_CASK_OPTS='--appdir=/Applications'
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_INSECURE_REDIRECT=1
  export HOMEBREW_BUNDLE_FILE="$ZDOTDIR/Brewfile"
  export HOMEBREW_BAT=1
  
  # Refine Editor if Neovim is available
  if [ -x "$HOMEBREW_PREFIX/bin/nvim" ]; then
    export EDITOR="$HOMEBREW_PREFIX/bin/nvim"
    export VISUAL="$EDITOR"
  fi
fi

# 5. OpenJDK Configuration
if [ -d "$HOMEBREW_PREFIX/opt/openjdk" ]; then
  export JAVA_HOME="$HOMEBREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
fi

# 6. Path Construction (POSIX-compliant)
# Note: Deduplication is handled by Zsh-specific logic in .zshenv
PATH="$HOME/.local/bin:$ZDOTDIR/bin:$XDG_DATA_HOME/mise/shims:$GOPATH/bin:$GEM_HOME/bin:$HOME/.cargo/bin:$PNPM_HOME"
[ -n "${HOMEBREW_PREFIX:-}" ] && PATH="$PATH:$HOMEBREW_PREFIX/opt/rustup/bin:$HOMEBREW_PREFIX/opt/postgresql@18/bin:$HOMEBREW_PREFIX/opt/openjdk/bin:$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin"
PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

# 7. History (Core settings)
export HISTSIZE=999999
export HISTFILE="$XDG_DATA_HOME/zsh/history"
