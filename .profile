# vim:ft=zsh

export XDG_ROOT="$HOME/Dropbox/$(whoami)"

export XDG_CONFIG_HOME="$XDG_ROOT/.config" && [[ ! -d "$XDG_CONFIG_HOME" ]] && mkdir -p "$XDG_CONFIG_HOME"

export XDG_DATA_HOME="$XDG_ROOT/.local/share" && [[ ! -d "$XDG_DATA_HOME" ]] && mkdir -p "$XDG_DATA_HOME"
export GOPATH="$XDG_DATA_HOME/golang" && [[ ! -d "$GOPATH" ]] && mkdir -p "$GOPATH"

export XDG_CACHE_HOME="$XDG_ROOT/.cache" && [[ ! -d "$XDG_CACHE_HOME" ]] && mkdir -p "$XDG_CACHE_HOME"
[[ ! -d "$XDG_CACHE_HOME/node" ]] && mkdir -p "$XDG_CACHE_HOME/node"

source "$XDG_DATA_HOME/.env"

export TERM='xterm-256color'

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

export XML_CATALOG_FILES='/usr/local/etc/xml/catalog'

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

export HISTFILESIZE=1000000000
export HISTSIZE=1000000000

export NODE_REPL_HISTORY_SIZE=1000000000
export NODE_REPL_MODE='sloppy'
export NODE_REPL_HISTORY="$XDG_CACHE_HOME/node/history"

export ARCHFLAGS='-arch x86_64'

export LS_COLORS='rs=0:di=01;34:ln=00;36:mh=00:pi=40;33:so=00;35:do=00;35:bd=40;33;01:cd=40;33;01:or=40;31:mi=00;05;37;41:su=37;41:sg=33:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=32:*.java=35:*.c++=35:*.h=35:*.py=35:*.sh=35:*.csh=35:*.zsh=35:*.xml=35:*.tar=37:*.tgz=37:*.arj=37:*.taz=37:*.lzh=37:*.lzma=37:*.tlz=37:*.txz=37:*.zip=37:*.z=37:*.Z=37:*.dz=37:*.gz=37:*.lz=37:*.xz=37:*.bz2=37:*.tbz=37:*.tbz2=37:*.bz=37:*.tz=37:*.deb=37:*.rpm=37:*.jar=37:*.rar=37:*.ace=37:*.zoo=37:*.cpio=37:*.7z=37:*.rz=37:*.jpg=36:*.jpeg=36:*.gif=36:*.bmp=36:*.pbm=36:*.pgm=36:*.ppm=36:*.tga=36:*.xbm=36:*.xpm=36:*.tif=36:*.tiff=36:*.png=36:*.svg=36:*.mng=36:*.pcx=36:*.mov=36:*.mpg=36:*.mpeg=36:*.mkv=36:*.mp3=36:*.wmv=36:*.avi=36:*.flv=36:*.xcf=36:*.aac=36:*.mp3=36:*.ogg=36:*.wav=36:*.haml=33:*.md=34:*.rb=31;01:*.erb=31;01:*.gemspec=31;01:*Gemfile=31;01:*Guardfile=31;01:*Rakefile=31;01:*.rake=31;01:*.gemrc=00;31:*Gemfile.lock=31:*.yml=33:*.log=37;01:';
export LSCOLOR='ExgxfxdacxDADAdxhbhefx'

