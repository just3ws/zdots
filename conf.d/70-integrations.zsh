source "$ZDOTDIR/.aliasrc"

if [[ "$TERM_PROGRAM" == "iTerm.app" && -o interactive && -t 1 && -r "$ZDOTDIR/.iterm2_shell_integration.zsh" ]]; then
  source "$ZDOTDIR/.iterm2_shell_integration.zsh"
fi

if [[ -o interactive && -t 1 && -r "$ZDOTDIR/.fzf.zsh" ]]; then
  source "$ZDOTDIR/.fzf.zsh"
fi

# Machine-local and private overrides.
[[ -r "$ZDOTDIR/.zshrc.local" ]] && source "$ZDOTDIR/.zshrc.local"
