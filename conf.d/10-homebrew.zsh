# Refresh full Homebrew shellenv.
if [[ -z "${_ZDOTS_BREW_SHELLENV:-}" ]]; then
  _zdots_brew_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/brew_shellenv"
  # Refresh cache if missing or if Brewfile changed (heuristic for system change)
  if [[ ! -r "$_zdots_brew_cache" || "${HOMEBREW_BUNDLE_FILE:-$ZDOTDIR/Brewfile}" -nt "$_zdots_brew_cache" ]]; then
    mkdir -p "$_zdots_brew_cache:h"
    if [[ -x /opt/homebrew/bin/brew ]]; then
      /opt/homebrew/bin/brew shellenv > "$_zdots_brew_cache"
    elif [[ -x /usr/local/bin/brew ]]; then
      /usr/local/bin/brew shellenv > "$_zdots_brew_cache"
    fi
  fi

  if [[ -r "$_zdots_brew_cache" ]]; then
    source "$_zdots_brew_cache"
    export _ZDOTS_BREW_SHELLENV=1
  fi
  unset _zdots_brew_cache
fi
