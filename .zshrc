# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -o interactive && -z "${ZSH_EXECUTION_STRING:-}" && -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# vim:ft=zsh
: "${ZDOTDIR:=$HOME/.config/zsh}"

# Load modules using the Circuit Breaker
if [[ "${ZDOTS_SAFE_MODE:-0}" == "1" ]]; then
  print -P "%F{yellow}zdots: SAFE MODE — loading essential modules only (05-60)%f" >&2
fi
for conf in "$ZDOTDIR"/conf.d/*.zsh(N); do
  if [[ "${ZDOTS_SAFE_MODE:-0}" == "1" && "${conf:t}" == [7-9]* ]]; then
    continue
  fi
  zdots_safe_source "$conf"
done
unset conf

# Syntax highlighting should be sourced last to catch all aliases and functions.
# Load theme-specific styles first.
# zdefer is provided by 70-integrations.zsh; skip in safe mode.
if [[ "${ZDOTS_SAFE_MODE:-0}" != "1" ]]; then
  if [[ -r "$ZDOTDIR/assets/$ZDOTS_THEME/syntax-highlighting.zsh" ]]; then
    zdefer source "$ZDOTDIR/assets/$ZDOTS_THEME/syntax-highlighting.zsh"
  elif [[ "$ZDOTS_THEME" == dracula-* && -r "$ZDOTDIR/assets/dracula/syntax-highlighting-${ZDOTS_THEME#dracula-}.zsh" ]]; then
    zdefer source "$ZDOTDIR/assets/dracula/syntax-highlighting-${ZDOTS_THEME#dracula-}.zsh"
  fi

  # Prefer Homebrew installed version.
  if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    zdefer source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
fi
# Prefer Vi-style editing while keeping a few essential Emacs motions active.
if [[ -o interactive && -o zle ]]; then
  bindkey -v
  bindkey '^A' beginning-of-line
  bindkey '^E' end-of-line
  bindkey '^K' kill-line
  bindkey '^U' backward-kill-line
  bindkey '^Y' yank
fi

test -e "${ZDOTDIR}/.iterm2_shell_integration.zsh" && source "${ZDOTDIR}/.iterm2_shell_integration.zsh" || true

