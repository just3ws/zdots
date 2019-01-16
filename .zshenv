# vim:ft=zsh

source "$HOME/.config/profile"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh" && [[ ! -d "$ZDOTDIR" ]] && mkdir -p "$ZDOTDIR"
export ADOTDIR="$XDG_DATA_HOME/antigen" && [[ ! -d "$ADOTDIR" ]] && mkdir -p "$ADOTDIR"

[[ ! -d "$XDG_CACHE_HOME/zsh" ]] && mkdir -p "$XDG_CACHE_HOME/zsh"
[[ ! -d "$XDG_CACHE_HOME/antigen" ]] && mkdir -p "$XDG_CACHE_HOME/antigen"

export DEOPLETE_ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh/deoplete" && [[ ! -d "$DEOPLETE_ZSH_CACHE_DIR" ]] && mkdir -p "$DEOPLETE_ZSH_CACHE_DIR"

export ANTIGEN_CACHE="$XDG_CACHE_HOME/antigen/init.zsh"
export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'
export HYPHEN_INSENSITIVE=true
export HISTFILE="$XDG_DATA_HOME/zsh/history"
export KEYTIMEOUT=1
export WORDCHARS='*?.[]~=&;!#$%^(){}<>@'
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/usr/local/share/zsh-syntax-highlighting/highlighters

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done

fpath=(
  $ZDOTDIR/functions/enabled
  /usr/local/share/zsh-completions
  $fpath
)

  # /usr/local/opt/{apr,apr-util}/bin

path=(
  ./bin
  $GOBIN
  /usr/local/opt/{ruby,php,mysql@5.6}/bin
  /usr/local/opt/{coreutils,findutils}/libexec/gnubin
  /usr/local/opt/{go,python}/libexec/bin
  /usr/local/opt/{make,gnu-sed,gnu-tar}/libexec/gnubin
  /usr/local/opt/{file-formula,fzf,gnu-getopt,imagemagick@6,m4}/bin
  /usr/local/{bin,sbin}
  /usr/{bin,sbin}
  /{bin,sbin}
  $path
)

manpath=(
  /usr/local/opt/{coreutils,gnu-sed,gnu-tar,make}/libexec/gnuman
  $manpath
)

typeset -gU cdpath fignore fpath mailpath path
