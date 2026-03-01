fpath=(
  $ZDOTDIR/bin
  $ZDOTDIR/functions/enabled
  $HOME/.asdf/completions
  $HOMEBREW_PREFIX/share/zsh-completions
  $fpath
)
typeset -gU cdpath fignore fpath mailpath path

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done

autoload -Uz colors && colors
if [[ -n "${LS_COLORS:-}" ]]; then
  zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"
fi
