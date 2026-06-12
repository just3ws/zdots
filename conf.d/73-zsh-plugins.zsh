# conf.d/73-zsh-plugins.zsh - optional Homebrew zsh plugins

if ! typeset -f zdefer >/dev/null 2>&1; then
  [[ -r "$ZDOTDIR/conf.d/70-shell-helpers.zsh" ]] && source "$ZDOTDIR/conf.d/70-shell-helpers.zsh"
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  zdefer source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]]; then
  # ZVM_LINE_INIT_MODE must be set before the plugin sources so the plugin
  # reads 'i' (insert) directly. zvm_config() fails because $ZVM_MODE_INSERT
  # is undefined at call time. Eager sourcing conflicts with autosuggestions
  # (circular self-insert wrapping → FUNCNEST). Keep deferred; set variable.
  ZVM_LINE_INIT_MODE='i'
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
