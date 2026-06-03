# conf.d/74-fzf.zsh - fzf shell integration and Tab policy

if ! typeset -f _is_zle_safe >/dev/null 2>&1; then
  [[ -r "$ZDOTDIR/conf.d/70-shell-helpers.zsh" ]] && source "$ZDOTDIR/conf.d/70-shell-helpers.zsh"
fi

if _is_zle_safe && [[ "${ZDOTS_CHECK_SKIP_FZF:-0}" != "1" && -r "$ZDOTDIR/.fzf.zsh" ]]; then
  source "$ZDOTDIR/.fzf.zsh"
fi

if _is_zle_safe && [[ "${ZDOTS_CHECK_SKIP_FZF:-0}" != "1" && -r "$ZDOTDIR/fzfrc" ]]; then
  source "$ZDOTDIR/fzfrc"
fi

# fzf-tab replaces the zsh completion menu with fzf.
if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh" ]] && _is_zle_safe; then
  source "$HOMEBREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"
fi

# Let fzf-tab or standard completion handle Tab. Keep fzf-completion available
# via its trigger (for example, **<Tab>) without binding raw Tab to it.
if _is_zle_safe; then
  bindkey '^I' expand-or-complete
  bindkey -M main '^I' expand-or-complete
  bindkey -M emacs '^I' expand-or-complete
  bindkey -M viins '^I' expand-or-complete
fi
