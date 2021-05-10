# vim:ft=zsh

source "$HOME/.config/profile"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh" && [[ ! -d "$ZDOTDIR" ]] && mkdir -p "$ZDOTDIR"
export ADOTDIR="$XDG_DATA_HOME/antigen" && [[ ! -d "$ADOTDIR" ]] && mkdir -p "$ADOTDIR"

[[ ! -d "$XDG_CACHE_HOME/zsh" ]] && mkdir -p "$XDG_CACHE_HOME/zsh"
[[ ! -d "$XDG_CACHE_HOME/antigen" ]] && mkdir -p "$XDG_CACHE_HOME/antigen"

export ANTIGEN_CACHE="$XDG_CACHE_HOME/antigen/init.zsh"
export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'
export HYPHEN_INSENSITIVE=true
export HISTFILE="$XDG_DATA_HOME/zsh/history"
export KEYTIMEOUT=1
export WORDCHARS='-*?.[]~=&;!#$%^(){}<>@'


source ~/.asdf/asdf.sh

for fn in ${ZDOTDIR}/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done

fpath=(
  ${ZDOTDIR}/functions/enabled
  ${HOME}/.asdf/completions
  /usr/local/share/zsh-completions
  $fpath
)

path=(
  /usr/local/{bin,sbin}
  $path
)

typeset -gU cdpath fignore fpath mailpath path
