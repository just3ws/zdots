# vim:ft=zsh

export XDG_ROOT="$HOME/Dropbox/$(whoami)"

export XDG_CONFIG_HOME="$XDG_ROOT/.config" && [[ ! -d "$XDG_CONFIG_HOME" ]] && mkdir -p "$XDG_CONFIG_HOME"
export ZDOTDIR="$XDG_CONFIG_HOME/zdots" && [[ ! -d "$ZDOTDIR" ]] && mkdir -p "$ZDOTDIR"

export XDG_DATA_HOME="$XDG_ROOT/.local/share" && [[ ! -d "$XDG_DATA_HOME" ]] && mkdir -p "$XDG_DATA_HOME"
export GOPATH="$XDG_DATA_HOME/golang" && [[ ! -d "$GOPATH" ]] && mkdir -p "$GOPATH"
export ADOTDIR="$XDG_DATA_HOME/antigen" && [[ ! -d "$ADOTDIR" ]] && mkdir -p "$ADOTDIR"

export XDG_CACHE_HOME="$XDG_ROOT/.cache" && [[ ! -d "$XDG_CACHE_HOME" ]] && mkdir -p "$XDG_CACHE_HOME"
[[ ! -d "$XDG_CACHE_HOME/node" ]] && mkdir -p "$XDG_CACHE_HOME/node"
[[ ! -d "$XDG_CACHE_HOME/zsh" ]] && mkdir -p "$XDG_CACHE_HOME/zsh"
[[ ! -d "$XDG_CACHE_HOME/antigen" ]] && mkdir -p "$XDG_CACHE_HOME/antigen"

source "$XDG_DATA_HOME/.env"

export ANTIGEN_CACHE="$XDG_CACHE_HOME/antigen/init.zsh"

export TERM='xterm-256color'

# {{{ [EDITOR]
alias vim='/usr/local/bin/mvim -v'
alias vi='/usr/local/bin/mvim -v'

export EDITOR='vim'
export ALTERNATE_EDITOR="$EDITOR"
export BUNDLER_EDITOR="$EDITOR"
export REACT_EDITOR="$EDITOR"
export FCEDIT="$EDITOR"
export CVSEDITOR="$EDITOR"
export GEM_EDITOR="$EDITOR"
export GIT_EDITOR="$EDITOR"
export PSQL_EDITOR="$EDITOR"
export SUDO_EDITOR="$EDITOR"
export SVN_EDITOR="$EDITOR"
export VISUAL="$EDITOR"
# }}}

export XML_CATALOG_FILES='/usr/local/etc/xml/catalog'

export WORDCHARS='*?.[]~=&;!#$%^(){}<>@'
export CLICOLOR=1

export HOMEBREW_CASK_OPTS='--appdir=/Applications'
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1

export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export LC_COLLATE='en_US.UTF-8'
export LC_CTYPE='en_US.UTF-8'
export LC_MESSAGES='en_US.UTF-8'
export LC_MONETARY='en_US.UTF-8'
export LC_NUMERIC='en_US.UTF-8'
export LC_TIME='en_US.UTF-8'

export JAVA_HOME='/Library/Java/JavaVirtualMachines/jdk-10.jdk/Contents/Home'
export MAVEN_OPTS='-Xms2048m -Xmx4096m -XX:PermSize=2048m'

export PERL5LIB='/usr/local/lib/perl5/site_perl':$PERL5LIB
export PERL_MB_OPT="--install_base '$HOME/perl5'"
export PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"

export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'

export HYPHEN_INSENSITIVE=true

export KEYTIMEOUT=1

export HISTCONTROL='erasedups:ignoreboth'
export HISTFILESIZE=1000000000
export HISTSIZE=1000000000

export NODE_REPL_HISTORY_SIZE=1000000000
export NODE_REPL_MODE='sloppy'

export NODE_REPL_HISTORY="$XDG_CACHE_HOME/node/history"
export HISTFILE="$XDG_CACHE_HOME/zsh/history"

export ARCHFLAGS='-arch x86_64'

# export CC='/usr/local/bin/gcc-7'
# export CXX='/usr/local/bin/g++-7'
# export CPP='/usr/local/bin/cpp-7'
# export LD='/usr/local/bin/gcc-7'
#
# export HOMEBREW_CC='gcc-7'
# export HOMEBREW_CXX='g++-7'
#
# alias c++='/usr/local/bin/c++-7'
# alias g++='/usr/local/bin/g++-7'
# alias gcc='/usr/local/bin/gcc-7'
# alias cpp='/usr/local/bin/cpp-7'
# alias ld='/usr/local/bin/gcc-7'
# alias cc='/usr/local/bin/gcc-7'

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done

fpath=(
  $ZDOTDIR/functions/enabled/
  /usr/local/share/zsh-completions/
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
