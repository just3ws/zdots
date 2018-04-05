# vim:ft=zsh

source "$HOME/.profile"

export ZDOTDIR="$XDG_CONFIG_HOME/zdots" && [[ ! -d "$ZDOTDIR" ]] && mkdir -p "$ZDOTDIR"
export ADOTDIR="$XDG_DATA_HOME/antigen" && [[ ! -d "$ADOTDIR" ]] && mkdir -p "$ADOTDIR"

[[ ! -d "$XDG_CACHE_HOME/zsh" ]] && mkdir -p "$XDG_CACHE_HOME/zsh"
[[ ! -d "$XDG_CACHE_HOME/antigen" ]] && mkdir -p "$XDG_CACHE_HOME/antigen"

export ANTIGEN_CACHE="$XDG_CACHE_HOME/antigen/init.zsh"

export ZSH_AUTOSUGGEST_USE_ASYNC=true
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/usr/local/share/zsh-syntax-highlighting/highlighters

export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'

export HYPHEN_INSENSITIVE=true

export HISTFILE="$XDG_CACHE_HOME/zsh/history"

export KEYTIMEOUT=1

export WORDCHARS='*?.[]~=&;!#$%^(){}<>@'

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done

fpath=(
  $ZDOTDIR/functions/enabled
  /usr/local/share/zsh-completions
  $fpath
)

path=(
  /usr/local/opt/go/libexec/bin
  /usr/local/{bin,sbin}
  /usr/{bin,sbin}
  /{bin,sbin}
  $path
)

typeset -gU cdpath fignore fpath mailpath path
