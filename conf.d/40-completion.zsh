fpath=(
  $ZDOTDIR/bin
  $ZDOTDIR/functions/enabled
  $HOMEBREW_PREFIX/share/zsh-completions
  $fpath
)
typeset -gU cdpath fignore fpath mailpath path

if [[ ${+functions[compdef]} -eq 0 ]]; then
  autoload -Uz compinit
  _zdots_compinit_args=()
  if [[ "${ZDOTS_COMPLETION_PERMISSIVE:-0}" == "1" ]]; then
    _zdots_compinit_args=(-i)
  fi
  _zdots_compdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
  if mkdir -p "${_zdots_compdump:h}" 2>/dev/null; then
    # Use -C to skip security checks if the dump file is less than 24h old.
    # bin/check handles the heavy lifting of security validation.
    if [[ -n "$_zdots_compdump"(#qN.m-1) ]]; then
      compinit "${_zdots_compinit_args[@]}" -C -d "$_zdots_compdump"
    else
      compinit "${_zdots_compinit_args[@]}" -d "$_zdots_compdump"
    fi
  else
    compinit "${_zdots_compinit_args[@]}"
  fi
  unset _zdots_compdump _zdots_compinit_args
fi

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "${fn:t}"
done

autoload -Uz colors && colors
if [[ -n "${LS_COLORS:-}" ]]; then
  zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"
fi
