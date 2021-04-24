# vim:ft=zsh

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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
zstyle :omz:plugins:ssh-agent identities 'id_ed25519' 'id_just3ws@github' 'id_mike-localdev@github' 'id_rsa'

source "$ZDOTDIR/.antigenrc"
source "$ZDOTDIR/.aliasrc"

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

export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"
# eval "$(rbenv init -)"
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"

command -v arkade &>/dev/null 2>&1 && source <(arkade completion zsh)
command -v kubectl &>/dev/null 2>&1 && {
    alias k=kubectl
    source <(kubectl completion zsh)
}

# {{{ FZF
source '/usr/local/opt/fzf/shell/completion.zsh'
source '/usr/local/opt/fzf/shell/key-bindings.zsh'

# # export FZF_DEFAULT_OPTS=' --color=dark --color=bg+:#3B4252,bg:#2E3440,spinner:#D08770,hl:#EBCB8B --color=fg:#D8DEE9,header:#EBCB8B,info:#5E81AC,pointer:#D08770 --color=marker:#D08770,fg+:#ECEFF4,prompt:#5E81AC,hl+:#EBCB8B '
# export FZF_DEFAULT_OPTS=' ' # --color=dark '
#   --tabstop=2 --border --inline-info --cycle 

export FZF_DEFAULT_OPTS='
  --color fg:255,bg:236,hl:84,fg+:255,bg+:236,hl+:215
  --color info:141,prompt:84,spinner:212,pointer:212,marker:212
'

# export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'"
export FZF_COMPLETION_TRIGGER=''

export FZF_CTRL_T_OPTS="--select-1 --exit-0"

export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

export FZF_DEFAULT_COMMAND='ag --hidden --ignore .git -g ""'

fzf-history-widget-accept () {
  fzf-history-widget
  zle accept-line
}

# zmodload zsh/zpty # Required for Vim autocompletion via deoplete-zsh

zle -N fzf-history-widget-accept
bindkey '^X^R' fzf-history-widget-accept

bindkey '^T' fzf-completion
bindkey '^I' $fzf_default_completion

. $HOME/.asdf/asdf.sh

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh
