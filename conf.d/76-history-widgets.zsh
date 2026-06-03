# conf.d/76-history-widgets.zsh - interactive history widgets and key bindings

if ! typeset -f _is_zle_safe >/dev/null 2>&1; then
  [[ -r "$ZDOTDIR/conf.d/70-shell-helpers.zsh" ]] && source "$ZDOTDIR/conf.d/70-shell-helpers.zsh"
fi

# Keep ^R deterministic: prefer fzf history when available, otherwise use
# built-in incremental history search across keymaps.
if _is_zle_safe; then
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

if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
  if _is_zle_safe; then
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    zvm_after_init_commands+=('bindkey -M vicmd "k" history-substring-search-up')
    zvm_after_init_commands+=('bindkey -M vicmd "j" history-substring-search-down')
  fi
fi

return 0
