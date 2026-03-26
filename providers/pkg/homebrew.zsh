# providers/pkg/homebrew.zsh — Homebrew implementation for the pkg-manager service

# Initialization (Service Implementation)
zdots_pkg_manager_init() {
  local prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
  [[ -x "$prefix/bin/brew" ]] || prefix="/usr/local"
  [[ -x "$prefix/bin/brew" ]] || return 1

  # Manually export Homebrew variables to avoid path_helper reordering in 'brew shellenv'
  export HOMEBREW_PREFIX="$prefix"
  export HOMEBREW_CELLAR="$prefix/Cellar"
  export HOMEBREW_REPOSITORY="$prefix"
  
  if [ -n "${ZSH_VERSION:-}" ]; then
    fpath=("$prefix/share/zsh/site-functions" $fpath)
  fi
  
  export HOMEBREW_CASK_OPTS='--appdir=/Applications'
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_INSECURE_REDIRECT=1
  export HOMEBREW_BUNDLE_FILE="${HOMEBREW_BUNDLE_FILE:-$ZDOTDIR/Brewfile}"
  export HOMEBREW_BAT=1
  
  export _ZDOTS_BREW_INITIALIZED=1
}

# Path setup (Liskov Substitution: Same interface for path manipulation)
zdots_pkg_manager_paths() {
  local prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
  if [ -n "${ZSH_VERSION:-}" ]; then
    typeset -gU path
    path=(
      "$prefix/bin"
      "$prefix/sbin"
      $path
    )
  else
    # POSIX fallback
    PATH="$prefix/bin:$prefix/sbin:$PATH"
    export PATH
  fi
}
