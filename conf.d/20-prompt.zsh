# Load Powerlevel10k directly.
P10K_THEME_CANDIDATES=(
  "$HOMEBREW_PREFIX/opt/powerlevel10k/powerlevel10k.zsh-theme"
  "$HOMEBREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme"
  "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme"
)
for P10K_THEME in $P10K_THEME_CANDIDATES; do
  if [[ -o interactive && -z "${ZSH_EXECUTION_STRING:-}" && -r "$P10K_THEME" ]]; then
    source "$P10K_THEME"
    break
  fi
done

# Fallback prompt when p10k is unavailable.
if [[ -o interactive && -z "${ZSH_EXECUTION_STRING:-}" && ${+functions[p10k]} -eq 0 ]]; then
  print -u2 "zdots: prompt: p10k not loaded (candidates: ${P10K_THEME_CANDIDATES[*]}); using fallback"
  PROMPT='%F{33}%n@%m%f %1~ %# '
fi

# To customize prompt, run `p10k configure` or edit the p10k config file.
[[ -o interactive && -z "${ZSH_EXECUTION_STRING:-}" ]] || typeset -g POWERLEVEL9K_DISABLE_GITSTATUS=true
if [[ -o interactive && -z "${ZSH_EXECUTION_STRING:-}" ]]; then
  if [[ -f "$ZDOTDIR/assets/$ZDOTS_THEME/p10k.zsh" ]]; then
    source "$ZDOTDIR/assets/$ZDOTS_THEME/p10k.zsh"
  elif [[ -f "$ZDOTDIR/.p10k.zsh" ]]; then
    source "$ZDOTDIR/.p10k.zsh"
  fi

  # Load custom color/UI overrides
  if [[ -f "$ZDOTDIR/assets/$ZDOTS_THEME/p10k-overrides.zsh" ]]; then
    source "$ZDOTDIR/assets/$ZDOTS_THEME/p10k-overrides.zsh"
  fi
fi

unset P10K_THEME P10K_THEME_CANDIDATES
