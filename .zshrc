# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -o interactive && -z "${ZSH_EXECUTION_STRING:-}" && -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# vim:ft=zsh

# Load Powerlevel10k directly (no Antigen framework on startup path).
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
unset P10K_THEME P10K_THEME_CANDIDATES

# Refresh full Homebrew shellenv in interactive shells.
if [[ -o interactive && -t 1 ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

export MALLOC_ARENA_MAX=2
export RUBY_CONFIGURE_OPTS="--with-jemalloc=$HOMEBREW_PREFIX/opt/jemalloc --with-openssl-dir=$HOMEBREW_PREFIX/opt/openssl@3"
# export RUBYOPT='-W:no-deprecated -W:no-experimental'

# . "$HOME/.asdf/asdf.sh"
if [[ -r "$HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh" ]]; then
  . "$HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh"
fi

export ANSIBLE_COW_SELECTION=random
export ANSIBLE_NOCOWS=1

export CLICOLOR=1
if command -v vivid >/dev/null 2>&1; then
  export LS_COLORS="$(vivid generate nord)"
fi
export DISABLE_SPRING=true
export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'
export HYPHEN_INSENSITIVE=true
export KEYTIMEOUT=1
export WORDCHARS='-*?.[]~=&;!#$%^(){}<>@'

fpath=(
  $ZDOTDIR/bin
  $ZDOTDIR/functions/enabled
  $HOME/.asdf/completions
  $HOMEBREW_PREFIX/share/zsh-completions
  $fpath
)
typeset -gU cdpath fignore fpath mailpath path

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done

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
setopt inc_append_history
setopt share_history

zstyle :omz:plugins:ssh-agent agent-forwarding on
zstyle :omz:plugins:ssh-agent identities 'id_ed25519' 'id_just3ws@github' 'id_mike-zalewhol@github' 'id_omf@github' 'id_omf@mike.hall' 'id_rsa'

bindkey '^P' up-line-or-history
bindkey '^N' down-line-or-history

autoload -Uz colors && colors
if [[ -n "${LS_COLORS:-}" ]]; then
  zstyle :completion:*:default list-colors "${(s.:.)LS_COLORS}"
fi

# Enable Ctrl-x-e to edit command line
autoload -Uz edit-command-line
zle -N edit-command-line

bindkey '^xe' edit-command-line
bindkey '^x^e' edit-command-line
bindkey -M vicmd v edit-command-line

. "${ZDOTDIR}/.aliasrc"
if [[ "$TERM_PROGRAM" == "iTerm.app" && -o interactive && -t 1 && -r "${ZDOTDIR}/.iterm2_shell_integration.zsh" ]]; then
  . "${ZDOTDIR}/.iterm2_shell_integration.zsh"
fi
if [[ -o interactive && -t 1 ]]; then
  . "${ZDOTDIR}/.fzf.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
[[ -o interactive && -z "${ZSH_EXECUTION_STRING:-}" ]] || typeset -g POWERLEVEL9K_DISABLE_GITSTATUS=true
if [[ -o interactive && -z "${ZSH_EXECUTION_STRING:-}" && -f ~/.config/zsh/.p10k.zsh ]]; then
  source ~/.config/zsh/.p10k.zsh
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# . "$HOME/.local/share/../bin/env"
