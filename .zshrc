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
# Prefer Homebrew installed version.
if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/mike/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
