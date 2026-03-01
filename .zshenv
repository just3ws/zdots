# vim:ft=zsh

export XDG_ROOT="$HOME"
export XDG_STATE_HOME="$XDG_ROOT/.local/state"
export XDG_CONFIG_HOME="$XDG_ROOT/.config"
export XDG_CACHE_HOME="$XDG_ROOT/.cache"
export XDG_DATA_HOME="$XDG_ROOT/.local/share"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

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

export HISTFILESIZE=999999
export HISTSIZE=999999
export HISTFILE="$XDG_DATA_HOME/zsh/history"

export HOMEBREW_CASK_OPTS='--appdir=/Applications'
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1

export PROJECTSPATH="$HOME/projects/"
export W3RPATH="$HOME/projects/wwworkremote/"

path=(
  $HOMEBREW_PREFIX/opt/postgresql@17/bin
  $HOME/.local/bin
  $HOME/.asdf/shims
  $HOME/.asdf/bin
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
