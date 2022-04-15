# vim:ft=zsh

export XDG_ROOT="$HOME"
export XDG_CACHE_HOME="$XDG_ROOT/.cache"
export XDG_CONFIG_HOME="$XDG_ROOT/.config"
export XDG_DATA_HOME="$XDG_ROOT/.local/share"
export XDG_STATE_HOME="$XDG_ROOT/.local/state"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

export ANTIGEN_CACHE="$XDG_CACHE_HOME/antigen/init.zsh"

export EDITOR='/usr/local/bin/nvim'
export ALTERNATE_EDITOR="$EDITOR"
export BUNDLER_EDITOR="$EDITOR"
export GEM_EDITOR="$EDITOR"
export GIT_EDITOR="$EDITOR"
export PSQL_EDITOR="$EDITOR"
export SUDO_EDITOR="$EDITOR"
export VISUAL="$EDITOR"

alias vim="$EDITOR"
alias vi="$EDITOR"

alias vim="$EDITOR"
alias vi="$EDITOR"

export LANG='en_US.UTF-8'

export PGPASSFILE="${HOME}/.pgpass"

export CLICOLOR=1

export HISTFILESIZE=999999
export HISTSIZE=999999

export HOMEBREW_CASK_OPTS='--appdir=/Applications'
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1

export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'

export HYPHEN_INSENSITIVE=true
export HISTFILE="$XDG_DATA_HOME/zsh/history"
export KEYTIMEOUT=1
export WORDCHARS='-*?.[]~=&;!#$%^(){}<>@'

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done

export PROJECTSPATH="$HOME/projects/"
export OMFPATH="$HOME/projects/omf/"
export W3RPATH="$HOME/projects/wwworkremote/"

fpath=(
  $ZDOTDIR/functions/enabled
  $HOME/.asdf/completions
  /usr/local/share/zsh-completions
  $fpath
)

path=(
  $HOME/.local/bin
  $HOME/.asdf/shims
  $HOME/.asdf/bin
  /usr/local/opt/openjdk/bin
  $HOME/perl5/bin
  /usr/local/{bin,sbin}
  /usr/{bin,sbin}
  /{bin,sbin}
  $path
)

typeset -gU cdpath fignore fpath mailpath path
