# Initialize full mise shell integration.
if [[ -z "${_ZDOTS_MISE_INITIALIZED:-}" ]]; then
  _zdots_mise_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/mise_activate"
  # Refresh cache if missing or if mise config changed
  if [[ ! -r "$_zdots_mise_cache" || "${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml" -nt "$_zdots_mise_cache" ]]; then
    mkdir -p "$_zdots_mise_cache:h" 2>/dev/null || true
    if [[ -x /opt/homebrew/bin/mise ]]; then
      /opt/homebrew/bin/mise activate zsh > "$_zdots_mise_cache" 2>/dev/null || true
    elif command -v mise >/dev/null 2>&1; then
      mise activate zsh > "$_zdots_mise_cache" 2>/dev/null || true
    fi
  fi

  if [[ -r "$_zdots_mise_cache" && -s "$_zdots_mise_cache" ]]; then
    source "$_zdots_mise_cache" || true
    export _ZDOTS_MISE_INITIALIZED=1
    export MISE_NODE_COREPACK=1
  elif command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
    export _ZDOTS_MISE_INITIALIZED=1
    export MISE_NODE_COREPACK=1
  fi
  unset _zdots_mise_cache
fi
