# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -o interactive && -z "${ZSH_EXECUTION_STRING:-}" && -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# vim:ft=zsh

for conf in "$ZDOTDIR"/conf.d/*.zsh(N); do
  source "$conf"
done
unset conf

# Syntax highlighting should be sourced last to catch all aliases and functions.
# Load theme-specific styles first.
if [[ -r "$ZDOTDIR/assets/$ZDOTS_THEME/syntax-highlighting.zsh" ]]; then
  source "$ZDOTDIR/assets/$ZDOTS_THEME/syntax-highlighting.zsh"
fi

# Prefer Homebrew installed version.
if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
# Prefer Vi-style editing while keeping a few essential Emacs motions active.
bindkey -v
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^K' kill-line
bindkey '^U' backward-kill-line
bindkey '^Y' yank
