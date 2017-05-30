# vim:set filetype=zsh expandtab shiftwidth=2 textwidth=64:

ZDOTDIR="$HOME/.config/zsh"

ZSH_CACHE_DIR="$HOME/.local/share/zsh/cache"
[ -d "$ZSH_CACHE_DIR" ] || mkdir -p "$ZSH_CACHE_DIR"

DIRSTACKSIZE=9
DIRSTACKFILE="$ZSH_CACHE_DIR/.zdirs"

LC_ALL="en_US.UTF-8"
LANG="en_US.UTF-8"

SAVEHIST=10000
HISTSIZE=13300 # allows room for `hist_expire_dupes_first` processing duplicated events
HISTFILE="$ZSH_CACHE_DIR/.zhistory"

HOMEBREW_CASK_OPTS="$HOMEBREW_CASK_OPTS --caskroom=/opt/homebrew-cask/Caskroom"
HOMEBREW_NO_ANALYTICS=1
HOMEBREW_NO_INSECURE_REDIRECT=1

# /usr/libexec/java_home
JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_131.jdk/Contents/Home"

export PYENV_VIRTUALENV_DISABLE_PROMPT=1
PYENV_ROOT="$HOME/.pyenv"
pyenv () {
  unset pyenv
  eval "$(command pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
  pyenv "$@"
}

# Default Vim environment variables
VIM="/usr/local/bin/nvim"
VIMRUNTIME="/usr/local/share/nvim/runtime"

vim () {
  unset vim

  VIM="/usr/local/bin/nvim"
  VIMRUNTIME="/usr/local/share/nvim/runtime"

  $VIM "$@"
}

# TODO: Safely lazy-load RVM while not breaking Bundler, etc.
# rvm () {
#   unfunction rvm
#
#   source "$HOME/.rvm/scripts/rvm"
#
#   rvm "$@"
# }

gvim () {
  unset gvim

  VIM="/usr/local/bin/mvim"
  VIMRUNTIME="/usr/local/Cellar/macvim/$(brew info macvim 2> /dev/null | grep -m 1 -o "\d.\d\+-\d\+")/MacVim.app/Contents/Resources/vim/runtime"

  $VIM "$@"
}

EDITOR=vim
VISUAL="$EDITOR"
ALTERNATE_EDITOR="$EDITOR"

# By default, zsh considers many characters part of a word (e.g., _ and -).
# Narrow that down to allow easier skipping through words via M-f and M-b.
WORDCHARS='*?[]~&;!$%^<>'

typeset -U path
nginx_path="/opt/nginx/sbin"
[ -d "$nginx_path" ] && [[ ! ("$path" =~ "$nginx_path") ]] && path=(/opt/nginx/sbin $path)

path=(
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

ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="/usr/local/share/zsh-syntax-highlighting/highlighters"

TRAPUSR1 () {
  # https://superuser.com/questions/852912/reload-all-running-zsh-instances
  if [[ -o INTERACTIVE ]]; then
     exec "${SHELL}"
  fi
}
