source "$ZDOTDIR/.aliasrc"

if [[ "$TERM_PROGRAM" == "iTerm.app" && -o interactive && -t 1 && -r "$ZDOTDIR/.iterm2_shell_integration.zsh" ]]; then
  source "$ZDOTDIR/.iterm2_shell_integration.zsh"
fi

if [[ -o interactive && -t 1 && -r "$ZDOTDIR/.fzf.zsh" ]]; then
  source "$ZDOTDIR/.fzf.zsh"
fi

if [[ -o interactive && -t 1 && -r "$ZDOTDIR/fzfrc" ]]; then
  source "$ZDOTDIR/fzfrc"
fi

# Machine-local and private overrides.
[[ -r "$ZDOTDIR/.zshrc.local" ]] && source "$ZDOTDIR/.zshrc.local"

# Keep ^R deterministic: prefer fzf history when available, otherwise use
# built-in incremental history search across keymaps.
if [[ -o interactive ]]; then
  if (( ${+widgets[fzf-history-widget]} )); then
    bindkey '^R' fzf-history-widget
    bindkey -M emacs '^R' fzf-history-widget
    bindkey -M viins '^R' fzf-history-widget
    bindkey -M vicmd '^R' fzf-history-widget
  else
    bindkey '^R' history-incremental-search-backward
    bindkey -M emacs '^R' history-incremental-search-backward
    bindkey -M viins '^R' history-incremental-search-backward
    bindkey -M vicmd '^R' history-incremental-search-backward
  fi
fi
