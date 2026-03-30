# providers/python/mise.zsh — Mise implementation for the python-runtime service

zdots_python_runtime_init() {
  command -v mise >/dev/null || return 1

  _zdots_mise_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/mise_activate_python"
  # We reuse the same mise activation if already initialized, but for clarity:
  if [[ -z "${_ZDOTS_MISE_INITIALIZED:-}" ]]; then
    if [[ ! -r "$_zdots_mise_cache" || "${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml" -nt "$_zdots_mise_cache" ]]; then
      mkdir -p "$_zdots_mise_cache:h" 2>/dev/null || true
      zdots_cmd_timeout mise activate zsh > "$_zdots_mise_cache" 2>/dev/null || true
    fi

    if [[ -r "$_zdots_mise_cache" && -s "$_zdots_mise_cache" ]]; then
      source "$_zdots_mise_cache" || true
    else
      eval "$(zdots_cmd_timeout mise activate zsh)"
    fi
    _ZDOTS_MISE_INITIALIZED=1
  fi
  unset _zdots_mise_cache
  _ZDOTS_PYTHON_MISE_INITIALIZED=1
}

zdots_python_runtime_paths() {
  if [ -n "${ZSH_VERSION:-}" ]; then
    typeset -gU path
    path=(
      "$XDG_DATA_HOME/mise/shims"
      $path
    )
  else
    PATH="$XDG_DATA_HOME/mise/shims:$PATH"
    export PATH
  fi
}
