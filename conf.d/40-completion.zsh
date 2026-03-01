fpath=(
  $ZDOTDIR/bin
  $ZDOTDIR/functions/enabled
  $HOME/.asdf/completions
  $HOMEBREW_PREFIX/share/zsh-completions
  $fpath
)
typeset -gU cdpath fignore fpath mailpath path

if [[ ${+functions[compdef]} -eq 0 ]]; then
  autoload -Uz compinit
  _zdots_compdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
  if mkdir -p "${_zdots_compdump:h}" 2>/dev/null; then
    compinit -i -d "$_zdots_compdump"
  else
    compinit -i
  fi
  unset _zdots_compdump
fi

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done

autoload -Uz colors && colors
if [[ -n "${LS_COLORS:-}" ]]; then
  zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"
fi
