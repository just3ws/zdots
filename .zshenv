# vim:ft=zsh:

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

DIRSTACKSIZE=16
DIRSTACKFILE="$ZSH_CACHE_DIR/dirstack"

LC_ALL="en_US.UTF-8"
LANG="en_US.UTF-8"

SAVEHIST=10000
HISTSIZE=13300 # Allows room for `hist_expire_dupes_first` processing duplicated events
HISTFILE="$ZSH_CACHE_DIR/history"

HOMEBREW_CASK_OPTS="$HOMEBREW_CASK_OPTS --caskroom=/opt/homebrew-cask/Caskroom"
HOMEBREW_NO_ANALYTICS=1
HOMEBREW_NO_INSECURE_REDIRECT=1

PERL5LIB="/usr/local/lib/perl5/site_perl":$PERL5LIB

# "$(/usr/libexec/java_home)"
JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_131.jdk/Contents/Home"

export PYENV_VIRTUALENV_DISABLE_PROMPT=1
PYENV_ROOT="$HOME/.pyenv"

VIM="/usr/local/bin/nvim"
VIMRUNTIME="/usr/local/share/nvim/runtime"

EDITOR=vim
VISUAL="$EDITOR"
ALTERNATE_EDITOR="$EDITOR"
GEM_EDITOR="$EDITOR"

WORDCHARS='!$%&*-;<>?@[]^_~'

export rvmsudo_secure_path=1
nginx_path="/opt/nginx/sbin"
[[ -d "$nginx_path" ]] && [[ ! ("$path" =~ "$nginx_path") ]] && path=(/opt/nginx/sbin $path)

path=(
  /usr/local/opt/coreutils/libexec/gnubin
  /usr/local/opt/gnu-tar/libexec/gnubin
  /usr/local/opt/findutils/libexec/gnubin
  /usr/local/opt/gnu-sed/libexec/gnubin
  /usr/local/bin
  /usr/local/sbin
  /usr/bin
  /usr/sbin
  /bin
  /sbin
  ./bin
  $HOME/.pyenv/bin
  $JAVA_HOME/bin
  /usr/local/opt/go/libexec/bin
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
