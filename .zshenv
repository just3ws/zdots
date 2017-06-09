# vim:ft=zsh:

# https://specifications.freedesktop.org/basedir-spec/latest/ar01s03.html
XDG_CONFIG_HOME="$HOME/.config"
[[ -d "$XDG_CONFIG_HOME" ]] || mkdir -p "$XDG_CONFIG_HOME"

XDG_DATA_HOME="$HOME/.local/share"
[[ -d "$XDG_DATA_HOME" ]] || mkdir -p "$XDG_DATA_HOME"

XDG_CACHE_HOME="$HOME/.cache"
[[ -d "$XDG_CACHE_HOME" ]] || mkdir -p "$XDG_CACHE_HOME"

# XDG_CONFIG_DIRS="/etc/xdg"
# XDG_DATA_DIRS="/usr/local/share/:/usr/share/"
# XDG_RUNTIME_DIR

ZDOTDIR="$XDG_CONFIG_HOME/zsh"

ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh/cache"
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

DIRSTACKSIZE=9
DIRSTACKFILE="$ZSH_CACHE_DIR/dirstack"

LC_ALL="en_US.UTF-8"
LANG="en_US.UTF-8"

SAVEHIST=10000
HISTSIZE=13300 # allows room for `hist_expire_dupes_first` processing duplicated events
HISTFILE="$ZSH_CACHE_DIR/history"

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

typeset -U manpath
manpath=(
  /usr/local/opt/coreutils/libexec/gnuman
  /usr/local/opt/gnu-tar/libexec/gnuman
  /usr/local/opt/findutils/libexec/gnuman
  /usr/local/opt/gnu-sed/libexec/gnuman
  $manpath
)

# Default Vim environment variables
VIM="/usr/local/bin/nvim"
VIMRUNTIME="/usr/local/share/nvim/runtime"

vim () {
  unset vim

  VIM="/usr/local/bin/nvim"
  VIMRUNTIME="/usr/local/share/nvim/runtime"

  if [[ "$@" =~ ':' ]]
  then
      file_path="$(print $@ | cut -d: -f1)"
      line_number="$(print $@ | cut -d: -f2)"
      $VIM "+$line_number|norm! zz" "$file_path"
  else
    $VIM "$@"
  fi
}

gvim () {
  unset gvim

  VIM="/usr/local/bin/mvim"
  VIMRUNTIME="/usr/local/Cellar/macvim/$(brew info macvim 2> /dev/null | grep -m 1 -o "\d.\d\+-\d\+")/MacVim.app/Contents/Resources/vim/runtime"

  $VIM "$@"
}

EDITOR=vim
VISUAL="$EDITOR"
ALTERNATE_EDITOR="$EDITOR"
GEM_EDITOR="$EDITOR"

# By default, zsh considers many characters part of a word (e.g., _ and -).
# Narrow that down to allow easier skipping through words via M-f and M-b.
WORDCHARS='!$%&*-;<>?@[]^_~'

typeset -U path
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

TRAPUSR1 () {
  # https://superuser.com/questions/852912/reload-all-running-zsh-instances
  if [[ -o INTERACTIVE ]]; then
     exec "${SHELL}"
  fi
}
