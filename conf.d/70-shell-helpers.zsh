# conf.d/70-shell-helpers.zsh - shared helpers for optional interactive modules

# zsh-defer: lazy-load heavy integrations to improve startup time.
if [[ -r "$ZDOTDIR/functions/enabled/zsh-defer.plugin.zsh" ]]; then
  source "$ZDOTDIR/functions/enabled/zsh-defer.plugin.zsh"
fi

zdefer() {
  if (( $+functions[zsh-defer] )); then
    zsh-defer "$@"
  else
    "$@"
  fi
}

# ZLE-safe guard: prevent noise in non-TTY command execution (zsh -c), but allow
# verification in bin/check via ZDOTS_CHECK_ZLE=1.
_is_zle_safe() {
  [[ -o interactive && -o zle ]] || return 1
  [[ -z "${ZSH_EXECUTION_STRING:-}" || "${ZDOTS_CHECK_ZLE:-0}" == "1" ]]
}
