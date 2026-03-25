# env.sh — POSIX-compatible environment core
# This file is sourced by sh, bash, and zsh.

# 1. XDG Base Directory Specification (Harden & Absolute)
export XDG_ROOT="$HOME"
export XDG_CONFIG_HOME="$XDG_ROOT/.config"
export XDG_STATE_HOME="$XDG_ROOT/.local/state"
export XDG_CACHE_HOME="$XDG_ROOT/.cache"
export XDG_DATA_HOME="$XDG_ROOT/.local/share"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# 2. XDG Tool Overrides (Force compliance for standard tools)
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME/aws/config"
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME/aws/credentials"
export BUNDLE_USER_CONFIG="$XDG_CONFIG_HOME/bundle/config"
export BUNDLE_USER_CACHE="$XDG_CACHE_HOME/bundle"
export BUNDLE_USER_PLUGIN="$XDG_DATA_HOME/bundle"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node/repl_history"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export PSQL_HISTORY="$XDG_STATE_HOME/psql/history"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"

# 3. General Environment
export LANG='en_US.UTF-8'
export EDITOR='vi'
export VISUAL="$EDITOR"
export PGPASSFILE="$XDG_CONFIG_HOME/pgpass"
export DOCKER_CLI_HINTS=false
export ENABLE_LSP_TOOL=1
export ZDOTS_THEME="${ZDOTS_THEME:-dracula-pro}"

# 4. Language-Specific XDG Alignment
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
export GOPATH="$XDG_DATA_HOME/go"
export GEM_HOME="$XDG_DATA_HOME/gem"
export GEM_PATH="$GEM_HOME"
export PYTHONUSERBASE="$XDG_DATA_HOME/python"

# 5. Homebrew Core Detection
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

  if [ -x "$HOMEBREW_PREFIX/bin/nvim" ]; then
    export EDITOR="$HOMEBREW_PREFIX/bin/nvim"
    export VISUAL="$EDITOR"
  fi
fi

# 6. OpenJDK Configuration
if [ -d "$HOMEBREW_PREFIX/opt/openjdk" ]; then
  export JAVA_HOME="$HOMEBREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
fi

# 7. Path Construction (POSIX-compliant)
PATH="$HOME/.local/bin:$ZDOTDIR/bin:$XDG_DATA_HOME/mise/shims:$GOPATH/bin:$GEM_HOME/bin:$HOME/.cargo/bin:$PNPM_HOME"
[ -n "${HOMEBREW_PREFIX:-}" ] && PATH="$PATH:$HOMEBREW_PREFIX/opt/rustup/bin:$HOMEBREW_PREFIX/opt/postgresql@18/bin:$HOMEBREW_PREFIX/opt/openjdk/bin:$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin"
PATH="$PATH:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

# 8. History (XDG Compliance: Move to STATE_HOME)
export HISTSIZE=999999
export HISTFILE="$XDG_STATE_HOME/zsh/history"
