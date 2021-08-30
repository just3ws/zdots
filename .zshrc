# vim:ft=zsh

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  . "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

. "${ZDOTDIR}/.antigenrc"

export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"

. "$HOME/.asdf/asdf.sh"

export ANSIBLE_COW_SELECTION=random
export ANSIBLE_NOCOWS=1

export CLICOLOR=1
export DISABLE_SPRING=true

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

zstyle :omz:plugins:ssh-agent agent-forwarding on
zstyle :omz:plugins:ssh-agent identities 'id_ed25519' 'id_just3ws@github' 'id_mike-zalewhol@github' 'id_omf@github' 'id_omf@mike.hall' 'id_rsa'

bindkey '^P' up-line-or-history
bindkey '^N' down-line-or-history

autoload -Uz colors && colors
zstyle :completion:*:default list-colors "${(s.:.)LS_COLORS}"

# Enable Ctrl-x-e to edit command line
autoload -Uz edit-command-line
zle -N edit-command-line

bindkey '^xe' edit-command-line
bindkey '^x^e' edit-command-line
bindkey -M vicmd v edit-command-line

export PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"
export PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
export PERL_MM_USE_DEFAULT=1
export PERL_CPANM_OPT="--prompt --reinstall -l -I$HOME/perl5/lib/perl5 --mirror http://cpan.cpantesters.org"
export PERL_MB_OPT="--install_base \"$HOME/perl5\""
export PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"

. "${ZDOTDIR}/.aliasrc"
. "${ZDOTDIR}/.iterm2_shell_integration.zsh"
. "${ZDOTDIR}/.fzf.zsh"
. "${ZDOTDIR}/.p10k.zsh"
