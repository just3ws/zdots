# vim:ft=zsh

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
setopt path_dirs
setopt pushd_ignore_dups
setopt short_loops

unsetopt beep
unsetopt case_glob
unsetopt clobber
unsetopt correct_all
unsetopt menu_complete
unsetopt no_match

# {{{ [HISTORY]
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
setopt inc_append_history
setopt share_history
# }}}

zstyle :omz:plugins:ssh-agent agent-forwarding on
zstyle :omz:plugins:ssh-agent identities 'id_just3ws@github' 'id_just3ws@bitbucket' 'id_rsa-iam-mike'

zle -N znt-history-widget
bindkey "^R" znt-history-widget

case $TERM in
    xterm*)
        precmd () { print -Pn "\e]0;%~\a" }
        ;;
esac

source "$ZDOTDIR/.antigenrc"
source "$ZDOTDIR/.ls_colors"
source "$ZDOTDIR/.lscolors"
source "$ZDOTDIR/.aliasrc"
source "$ZDOTDIR/.iterm2_shell_integration.zsh"
source "$ZDOTDIR/.fzf.zsh"

bindkey '^P' up-line-or-history
bindkey '^N' down-line-or-history

autoload -Uz colors && colors
zstyle :completion:*:default list-colors "${(s.:.)LS_COLORS}"

# Enable Ctrl-x-e to edit command line
autoload -Uz edit-command-line
zle -N edit-command-line
# Emacs style
bindkey '^xe' edit-command-line
bindkey '^x^e' edit-command-line
# Vi style:
bindkey -M vicmd v edit-command-line

eval "$(rbenv init -)"
