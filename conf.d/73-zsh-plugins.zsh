# conf.d/73-zsh-plugins.zsh - optional Homebrew zsh plugins

if ! typeset -f zdefer >/dev/null 2>&1; then
  [[ -r "$ZDOTDIR/conf.d/70-shell-helpers.zsh" ]] && source "$ZDOTDIR/conf.d/70-shell-helpers.zsh"
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  zdefer source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]]; then
  # zsh-vi-mode default is normal mode on each new line — that causes the
  # first keypress to be interpreted as a vi command (e.g. 'a' appends before
  # inserting, producing 'aack' for 'ack'). Force insert mode at line start.
  function zvm_config() { ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT }
  zdefer source "$HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-autopair/autopair.zsh" ]]; then
  zdefer source "$HOMEBREW_PREFIX/share/zsh-autopair/autopair.zsh"
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh" ]]; then
  zdefer source "$HOMEBREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh"
fi

if [[ "$TERM_PROGRAM" == "iTerm.app" && -o interactive && -t 1 && -r "$ZDOTDIR/.iterm2_shell_integration.zsh" ]]; then
  source "$ZDOTDIR/.iterm2_shell_integration.zsh"
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

return 0
