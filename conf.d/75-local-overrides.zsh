# conf.d/75-local-overrides.zsh - machine-local and private shell overrides

if [[ -r "$ZDOTDIR/.zshrc.local" ]]; then
  source "$ZDOTDIR/.zshrc.local"
fi

return 0
