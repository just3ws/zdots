# providers/node/mise.zsh — Mise implementation for the node-runtime service

zdots_node_runtime_init() {
  command -v mise >/dev/null || return 1

  # Use a more stable cache for the hook only, avoiding the static PATH snapshot
  _zdots_mise_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/mise_hook"
  if [[ ! -r "$_zdots_mise_cache" || "${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml" -nt "$_zdots_mise_cache" ]]; then
    mkdir -p "$_zdots_mise_cache:h" 2>/dev/null || true
    # Generate the hook without the static PATH export if possible, 
    # or we'll just handle it by ensuring shims are always present.
    rm -f "$_zdots_mise_cache" 2>/dev/null || true
    mise activate zsh --shims > "$_zdots_mise_cache" 2>/dev/null || true
    # If --shims didn't give us the hook, we fall back to standard but we'll be careful.
    if [ ! -s "$_zdots_mise_cache" ]; then
      mise activate zsh > "$_zdots_mise_cache" 2>/dev/null || true
    fi
  fi

  if [[ -r "$_zdots_mise_cache" && -s "$_zdots_mise_cache" ]]; then
    source "$_zdots_mise_cache" || true
  else
    eval "$(mise activate zsh)"
  fi
  
  export MISE_NODE_COREPACK=1
  export _ZDOTS_MISE_INITIALIZED=1
  unset _zdots_mise_cache
}

zdots_node_runtime_paths() {
  # Prepend Mise shims to the PATH.
  # This is the "Source of Truth" for Mise-managed binaries.
  local mise_shims="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
  if [ -n "${ZSH_VERSION:-}" ]; then
    typeset -gU path
    path=(
      "$mise_shims"
      $path
    )
  else
    # POSIX fallback
    case ":$PATH:" in
      *":$mise_shims:"*) ;;
      *) PATH="$mise_shims:$PATH"; export PATH ;;
    esac
  fi
}
