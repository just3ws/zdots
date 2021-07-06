# vim:ft=zsh

export XDG_ROOT="$HOME" && [[ ! -d "$XDG_ROOT" ]] && mkdir -p "$XDG_ROOT"
export XDG_STATE_HOME="$XDG_ROOT/.local/state" && [[ ! -d "$XDG_STATE_HOME" ]] && mkdir -p "$XDG_STATE_HOME"
export XDG_CONFIG_HOME="$XDG_ROOT/.config" && [[ ! -d "$XDG_CONFIG_HOME" ]] && mkdir -p "$XDG_CONFIG_HOME"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh" && [[ ! -d "$ZDOTDIR" ]] && mkdir -p "$ZDOTDIR"
. "$XDG_CONFIG_HOME/env"
export XDG_CACHE_HOME="$XDG_ROOT/.cache" && [[ ! -d "$XDG_CACHE_HOME" ]] && mkdir -p "$XDG_CACHE_HOME"
export XDG_DATA_HOME="$XDG_ROOT/.local/share" && [[ ! -d "$XDG_DATA_HOME" ]] && mkdir -p "$XDG_DATA_HOME"
[[ ! -d "$XDG_DATA_HOME/nvim" ]] && mkdir -p "$XDG_DATA_HOME/nvim"
[[ ! -d "$XDG_DATA_HOME/node" ]] && mkdir -p "$XDG_DATA_HOME/node"
[[ ! -d "$XDG_DATA_HOME/python" ]] && mkdir -p "$XDG_DATA_HOME/python"
[[ ! -d "$XDG_DATA_HOME/psql" ]] && mkdir -p "$XDG_DATA_HOME/psql"
[[ ! -d "$XDG_DATA_HOME/ruby" ]] && mkdir -p "$XDG_DATA_HOME/ruby"
export ADOTDIR="$XDG_DATA_HOME/antigen" && [[ ! -d "$ADOTDIR" ]] && mkdir -p "$ADOTDIR"
[[ ! -d "$XDG_CACHE_HOME/zsh" ]] && mkdir -p "$XDG_CACHE_HOME/zsh"
[[ ! -d "$XDG_CACHE_HOME/antigen" ]] && mkdir -p "$XDG_CACHE_HOME/antigen"
export ANTIGEN_CACHE="$XDG_CACHE_HOME/antigen/init.zsh"
[[ ! -d "$XDG_DATA_HOME/zsh" ]] && mkdir -p "$XDG_DATA_HOME/zsh"
[[ ! -d "$XDG_DATA_HOME/antigen" ]] && mkdir -p "$XDG_DATA_HOME/antigen"
touch "$XDG_DATA_HOME/antigen/debug.log"

export EDITOR='/usr/local/bin/nvim'
export ALTERNATE_EDITOR='/usr/local/bin/nvim'
export BUNDLER_EDITOR='/usr/local/bin/nvim'
export GEM_EDITOR='/usr/local/bin/nvim'
export GIT_EDITOR='/usr/local/bin/nvim'
export PSQL_EDITOR='/usr/local/bin/nvim'
export SUDO_EDITOR='/usr/local/bin/nvim'
export VISUAL='/usr/local/bin/nvim'

alias vim='/usr/local/bin/nvim'
alias vi='/usr/local/bin/nvim'

export PYTHON_HOST_PROG="$HOME/.asdf/shims/python2"
export PYTHON3_HOST_PROG="/usr/local/bin/python3"

export GOPATH="$HOME" && [[ ! -d "$GOPATH" ]] && mkdir -p "$GOPATH"
# export GOARCH='amd64'
# export GOHOSTARCH='amd64'
# export GOOS='darwin'
export GOBIN="$GOPATH/bin"

export LANG='en_US.UTF-8'

# Nord
export LSCOLORS='ExgxfxdacxDADAdxhbhefx'
export LS_COLORS='no=00:rs=0:fi=00:di=01;34:ln=36:mh=04;36:pi=04;01;36:so=04;33:do=04;01;36:bd=01;33:cd=33:or=31:mi=01;37;41:ex=01;36:su=01;04;37:sg=01;04;37:ca=01;37:tw=01;37;44:ow=01;04;34:st=04;37;44:*.7z=01;32:*.ace=01;32:*.alz=01;32:*.arc=01;32:*.arj=01;32:*.bz=01;32:*.bz2=01;32:*.cab=01;32:*.cpio=01;32:*.deb=01;32:*.dz=01;32:*.ear=01;32:*.gz=01;32:*.jar=01;32:*.lha=01;32:*.lrz=01;32:*.lz=01;32:*.lz4=01;32:*.lzh=01;32:*.lzma=01;32:*.lzo=01;32:*.rar=01;32:*.rpm=01;32:*.rz=01;32:*.sar=01;32:*.t7z=01;32:*.tar=01;32:*.taz=01;32:*.tbz=01;32:*.tbz2=01;32:*.tgz=01;32:*.tlz=01;32:*.txz=01;32:*.tz=01;32:*.tzo=01;32:*.tzst=01;32:*.war=01;32:*.xz=01;32:*.z=01;32:*.Z=01;32:*.zip=01;32:*.zoo=01;32:*.zst=01;32:*.aac=32:*.au=32:*.flac=32:*.m4a=32:*.mid=32:*.midi=32:*.mka=32:*.mp3=32:*.mpa=32:*.mpeg=32:*.mpg=32:*.ogg=32:*.opus=32:*.ra=32:*.wav=32:*.3des=01;35:*.aes=01;35:*.gpg=01;35:*.pgp=01;35:*.doc=32:*.docx=32:*.dot=32:*.odg=32:*.odp=32:*.ods=32:*.odt=32:*.otg=32:*.otp=32:*.ots=32:*.ott=32:*.pdf=32:*.ppt=32:*.pptx=32:*.xls=32:*.xlsx=32:*.app=01;36:*.bat=01;36:*.btm=01;36:*.cmd=01;36:*.com=01;36:*.exe=01;36:*.reg=01;36:*~=02;37:*.bak=02;37:*.BAK=02;37:*.log=02;37:*.log=02;37:*.old=02;37:*.OLD=02;37:*.orig=02;37:*.ORIG=02;37:*.swo=02;37:*.swp=02;37:*.bmp=32:*.cgm=32:*.dl=32:*.dvi=32:*.emf=32:*.eps=32:*.gif=32:*.jpeg=32:*.jpg=32:*.JPG=32:*.mng=32:*.pbm=32:*.pcx=32:*.pgm=32:*.png=32:*.PNG=32:*.ppm=32:*.pps=32:*.ppsx=32:*.ps=32:*.svg=32:*.svgz=32:*.tga=32:*.tif=32:*.tiff=32:*.xbm=32:*.xcf=32:*.xpm=32:*.xwd=32:*.xwd=32:*.yuv=32:*.anx=32:*.asf=32:*.avi=32:*.axv=32:*.flc=32:*.fli=32:*.flv=32:*.gl=32:*.m2v=32:*.m4v=32:*.mkv=32:*.mov=32:*.MOV=32:*.mp4=32:*.mpeg=32:*.mpg=32:*.nuv=32:*.ogm=32:*.ogv=32:*.ogx=32:*.qt=32:*.rm=32:*.rmvb=32:*.swf=32:*.vob=32:*.webm=32:*.wmv=32:';

export CLICOLOR=1

export HISTFILESIZE=999999
export HISTSIZE=999999

export HOMEBREW_CASK_OPTS='--appdir=/Applications'
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1

export GITHUB_USER=just3ws
export GITHUB_TOKEN='[REDACTED_GITHUB_TOKEN]'
export GITHUB_PASSWORD="$GITHUB_TOKEN"
export HOMEBREW_GITHUB_API_TOKEN='[REDACTED_GITHUB_TOKEN]'


export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'

export HYPHEN_INSENSITIVE=true
export HISTFILE="$XDG_DATA_HOME/zsh/history"
export KEYTIMEOUT=1
export WORDCHARS='-*?.[]~=&;!#$%^(){}<>@'

export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/usr/local/share/zsh-syntax-highlighting/highlighters

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done

fpath=(
  $ZDOTDIR/functions/enabled
  $HOME/.asdf/completions
  /usr/local/share/zsh-completions
  $fpath
)

path=(
  $GOBIN
  /usr/local/{bin,sbin}
  /usr/{bin,sbin}
  /{bin,sbin}
  $path
)

typeset -gU cdpath fignore fpath mailpath path

export OUTLIER_JOBS_DATABASE_URL='postgres://outlier_jobs:window.snow@malina103/outlier_jobs_production'
export OUTLIER_JOBS_REDIS_CACHE_URL='redis://localhost:6379/0'
export OUTLIER_JOBS_REDIS_SIDEKIQ_URL='redis://localhost:6379/0'
