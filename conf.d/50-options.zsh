setopt always_to_end
setopt auto_cd
setopt auto_menu
setopt auto_name_dirs
setopt auto_param_slash
setopt cdable_vars
setopt chase_links
setopt combining_chars
setopt complete_aliases
setopt complete_in_word
setopt correct
setopt extended_glob
setopt glob_dots
setopt glob_star_short
setopt interactive_comments
setopt magic_equal_subst
setopt multios
setopt notify
setopt numeric_glob_sort
setopt path_dirs
setopt pushd_ignore_dups
setopt short_loops

unsetopt beep
unsetopt case_glob
unsetopt clobber
unsetopt correct_all
unsetopt menu_complete
unsetopt nomatch

unsetopt hist_beep
setopt append_history
setopt bang_hist
setopt extended_history
setopt hist_expire_dups_first
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_no_functions
setopt hist_reduce_blanks
setopt hist_save_no_dups
setopt hist_verify

# History policy:
# - Default: local append-only with command duration timestamps.
# - Optional: shared history across sessions (disables inc_append_history_time).
if [[ "${ZDOTS_SHARE_HISTORY:-0}" == "1" ]]; then
  unsetopt inc_append_history_time
  setopt share_history
else
  setopt inc_append_history_time
  unsetopt share_history
fi

# Re-assert XDG-compliant HISTFILE after /etc/zshrc (macOS system file) resets it to
# ${ZDOTDIR}/.zsh_history. This must run AFTER /etc/zshrc (which runs between .zshenv
# and .zshrc) to win the race. env.sh sets HISTFILE correctly but /etc/zshrc clobbers it.
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
