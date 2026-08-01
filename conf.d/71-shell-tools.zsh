# conf.d/71-shell-tools.zsh - command-line navigation and directory tools

if ! typeset -f zdefer >/dev/null 2>&1; then
  [[ -r "$ZDOTDIR/conf.d/70-shell-helpers.zsh" ]] && source "$ZDOTDIR/conf.d/70-shell-helpers.zsh"
fi

# Version-keyed init cache (Z-270): run `<cmd...>` once per tool build, cache
# its stdout under the XDG cache, and source that file on later startups
# instead of spawning the tool every shell. Key = binary path + mtime via
# zstat (no fork), so a tool upgrade regenerates automatically. Guards: an
# uncreatable cache dir degrades to a direct eval; an empty or corrupt cache
# file is regenerated once. Never fails the shell.
_zdots_init_cache() {
  local name="$1" bin="$2"
  shift 2
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  local key cache tmp attempt
  local -a _zic_stat _zic_stale

  zmodload -F zsh/stat b:zstat 2>/dev/null
  if zstat -A _zic_stat +mtime "$bin" 2>/dev/null; then
    key="${bin//[^A-Za-z0-9._-]/_}-${_zic_stat[1]}"
  else
    key="${bin//[^A-Za-z0-9._-]/_}-nover"
  fi
  cache="$dir/${name}-init-${key}.zsh"

  for attempt in 1 2; do
    if [[ ! -s "$cache" ]]; then
      mkdir -p "$dir" 2>/dev/null || { eval "$("$@" 2>/dev/null)"; return 0; }
      tmp="${cache}.tmp.$$"
      if "$@" >"$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        # drop caches keyed to older builds of this tool (and their .zwc)
        _zic_stale=( "$dir/${name}-init-"*.zsh(|.zwc)(N) )
        (( $#_zic_stale )) && rm -f -- "${_zic_stale[@]}"
        mv -f "$tmp" "$cache"
        zcompile "$cache" 2>/dev/null
      else
        rm -f "$tmp"
        return 0
      fi
    fi
    source "$cache" 2>/dev/null && return 0
    rm -f "$cache" "$cache.zwc" # corrupt cache: regenerate once (attempt 2)
  done
  return 0
}

if command -v zoxide >/dev/null 2>&1; then
  _zdots_init_cache zoxide "$commands[zoxide]" zoxide init zsh
fi

if command -v direnv >/dev/null 2>&1; then
  _zdots_init_cache direnv "$commands[direnv]" direnv hook zsh
fi

if command -v atuin >/dev/null 2>&1; then
  # Use --disable-up-arrow because history-substring-search owns arrows.
  # Named function: the command substitution runs inside the deferred body,
  # so nothing atuin-related executes synchronously at startup. A bare
  # `zdefer eval "$(atuin init ...)"` expands the $() immediately (Z-270).
  _zdots_atuin_init() {
    _zdots_init_cache atuin "$commands[atuin]" atuin init zsh --disable-up-arrow
    unfunction _zdots_atuin_init 2>/dev/null
  }
  zdefer _zdots_atuin_init
fi

if command -v broot >/dev/null 2>&1; then
  source "$HOMEBREW_PREFIX/etc/bash_completion.d/broot" 2>/dev/null || true
  alias br='broot'
fi

# k8s native ergonomics
if command -v kubectl >/dev/null 2>&1; then
  alias k=kubectl
  alias kgp='kubectl get pods'
  alias kdp='kubectl describe pod'
  alias kgs='kubectl get svc'
  _zdots_init_cache kubectl "$commands[kubectl]" kubectl completion zsh
fi
# default namespace for the session — tenant-specific, so it lives in
# .zdots.local (ZDOTS_K8S_DEFAULT_NS), never in tracked config
if [[ -n "${ZDOTS_K8S_DEFAULT_NS:-}" ]] && command -v kubens >/dev/null 2>&1; then
  kubens "$ZDOTS_K8S_DEFAULT_NS" >/dev/null 2>&1 || true
fi

return 0
