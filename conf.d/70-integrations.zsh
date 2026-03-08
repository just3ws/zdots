source "$ZDOTDIR/.aliasrc"

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

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

# Keep Tab deterministic: prefer fzf completion when available, otherwise use
# default expand-or-complete across common interactive keymaps.
if [[ -o interactive ]]; then
  if (( ${+widgets[fzf-completion]} )); then
    bindkey '^I' fzf-completion
    bindkey -M main '^I' fzf-completion
    bindkey -M emacs '^I' fzf-completion
    bindkey -M viins '^I' fzf-completion
  else
    bindkey '^I' expand-or-complete
    bindkey -M main '^I' expand-or-complete
    bindkey -M emacs '^I' expand-or-complete
    bindkey -M viins '^I' expand-or-complete
  fi
fi

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

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

