# vim:ft=zsh

export XDG_ROOT="$HOME"
export XDG_STATE_HOME="$XDG_ROOT/.local/state"
export XDG_CONFIG_HOME="$XDG_ROOT/.config"
export XDG_CACHE_HOME="$XDG_ROOT/.cache"
export XDG_DATA_HOME="$XDG_ROOT/.local/share"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

export ENABLE_LSP_TOOL=1
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
export ZDOTS_THEME="${ZDOTS_THEME:-dracula-pro}"

if [[ -d "$HOMEBREW_PREFIX/opt/openjdk" ]]; then
  export JAVA_HOME="$HOMEBREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
fi

# Codex sandbox sessions cannot write under ~/.cache, which causes noisy mise
# cache warnings on every shim invocation. Keep normal shells on the standard
# XDG cache path and redirect only sandboxed Codex sessions to a writable temp
# directory.
if [[ -n "${CODEX_SANDBOX:-}" ]]; then
  export MISE_CACHE_DIR="${${TMPDIR:-/tmp}%/}/mise-cache"
fi

# Cheap Homebrew prefix detection for all shell types.
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
  if [[ -d /opt/homebrew ]]; then
    export HOMEBREW_PREFIX=/opt/homebrew
  elif [[ -d /usr/local ]]; then
    export HOMEBREW_PREFIX=/usr/local
  fi
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -x "$HOMEBREW_PREFIX/bin/nvim" ]]; then
  export EDITOR="$HOMEBREW_PREFIX/bin/nvim"
else
  export EDITOR="${EDITOR:-/usr/bin/vi}"
fi
export ALTERNATE_EDITOR="$EDITOR"
export BUNDLER_EDITOR="$EDITOR"
export GEM_EDITOR="$EDITOR"
export GIT_EDITOR="$EDITOR"
export PSQL_EDITOR="$EDITOR"
export SUDO_EDITOR="$EDITOR"
export VISUAL="$EDITOR"

export LANG='en_US.UTF-8'
export PGPASSFILE="${HOME}/.pgpass"
export DOCKER_CLI_HINTS=false
: "${GIT_CONFIG_GLOBAL:=$XDG_CONFIG_HOME/git/config}"
export GIT_CONFIG_GLOBAL

# Prefer 1Password SSH agent when available.
_1p_agent_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S "$_1p_agent_sock" ]]; then
  export SSH_AUTH_SOCK="$_1p_agent_sock"
fi
unset _1p_agent_sock

export HISTSIZE=999999
export HISTFILE="$XDG_DATA_HOME/zsh/history"

export HOMEBREW_CASK_OPTS='--appdir=/Applications'
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1

path=(
  $HOME/.local/bin
  $XDG_DATA_HOME/mise/shims
  $HOME/.cargo/bin
  $PNPM_HOME
  $HOMEBREW_PREFIX/opt/rustup/bin
  $HOMEBREW_PREFIX/opt/postgresql@18/bin
  $HOMEBREW_PREFIX/opt/openjdk/bin
  $HOMEBREW_PREFIX/{bin,sbin}
  /usr/{bin,sbin}
  /{bin,sbin}
  $path
)

fpath=(
  $ZDOTDIR/bin
  $ZDOTDIR/functions/enabled
  $fpath
)

typeset -gU fpath path
