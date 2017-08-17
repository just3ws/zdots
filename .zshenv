# vim:ft=zsh:

export VIM="/usr/local/bin/nvim"
export VIMRUNTIME="/usr/local/share/nvim/runtime"

export EDITOR="$VIM"
export ALTERNATE_EDITOR="$VIM"
export FCEDIT="$VIM"
export GEM_EDITOR="$VIM"
export PSQL_EDITOR="$VIM"
export SUDO_EDITOR="$VIM"
export VISUAL="$VIM"
#
# vi () vim $@

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

XDG_CACHE_HOME="$HOME/.cache"
XDG_CONFIG_HOME="$HOME/.config"
XDG_DATA_HOME="$HOME/.local/share"

ZDOTDIR="$XDG_CONFIG_HOME/zsh"
ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"

# ZSHENV PROFILING START BLOCK {{{
if [[ "$ZSHENV_PROFILE_STARTUP" == true ]]
then
  PS4=$'%D{%M%S%.} %N:%i> '
  [[ -d "$ZSH_CACHE_DIR/profile"   ]] || mkdir -p "$ZSH_CACHE_DIR/profile"
  exec 3>&2 2> $ZSH_CACHE_DIR/profile/xtrace.zshenv.$$
  setopt xtrace
fi
# }}}

[[ -d "$ZSH_CACHE_DIR"   ]] || mkdir -p "$ZSH_CACHE_DIR"
[[ -d "$XDG_CACHE_HOME"  ]] || mkdir -p "$XDG_CACHE_HOME"
[[ -d "$XDG_CONFIG_HOME" ]] || mkdir -p "$XDG_CONFIG_HOME"
[[ -d "$XDG_DATA_HOME"   ]] || mkdir -p "$XDG_DATA_HOME"

export DIRSTACKSIZE=16
export DIRSTACKFILE="$ZSH_CACHE_DIR/dirstack"

export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

SAVEHIST=10000
HISTSIZE=15000
HISTFILE="$ZSH_CACHE_DIR/history"

export HOMEBREW_CASK_OPTS="--appdir=/Applications"
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1

export PERL5LIB="/usr/local/lib/perl5/site_perl":$PERL5LIB

# "$(/usr/libexec/java_home)"
export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_131.jdk/Contents/Home"

export WORDCHARS='!$%&*-;<>?@[]^_~'

export rvmsudo_secure_path=1

nginx_path="/opt/nginx/sbin"
[[ -d "$nginx_path" ]] && [[ ! ("$path" =~ "$nginx_path") ]] && path=(/opt/nginx/sbin $path)

export GOPATH="$HOME/go"

path=(
  $HOME/.iterm2
  /usr/local/opt/python/libexec/bin
  /usr/local/bin
  /usr/local/sbin
  /usr/bin
  /usr/sbin
  /bin
  /sbin
  $JAVA_HOME/bin
  /usr/local/opt/go/libexec/bin
  $GOPATH/bin
  ~/bin
  $path
  $HOME/.rvm/bin
)

# ZSHENV PROFILING END BLOCK {{{
if [[ "$ZSHENV_PROFILE_STARTUP" == true ]]
then
  unsetopt xtrace
  exec 2>&3 3>&-
fi
# }}}
