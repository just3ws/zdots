# vim:ft=zsh:

# export VIM="/usr/local/bin/nvim"
# export VIMRUNTIME="/usr/local/share/nvim/runtime"
#
# export EDITOR="$VIM"
# export ALTERNATE_EDITOR="$VIM"
# export FCEDIT="$VIM"
# export GEM_EDITOR="$VIM"
# export PSQL_EDITOR="$VIM"
# export SUDO_EDITOR="$VIM"
# export VISUAL="$VIM"
# #
# # vi () vim $@
#
# # Ensure path arrays do not contain duplicates.
# typeset -gU cdpath fpath mailpath path
#
# XDG_CACHE_HOME="$HOME/.cache"
# XDG_CONFIG_HOME="$HOME/.config"
# XDG_DATA_HOME="$HOME/.local/share"
#
# ZDOTDIR="$XDG_CONFIG_HOME/zsh"
# ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"
#
# # ZSHENV PROFILING START BLOCK {{{
# if [[ "$ZSHENV_PROFILE_STARTUP" == true ]]
# then
#   PS4=$'%D{%M%S%.} %N:%i> '
#   [[ -d "$ZSH_CACHE_DIR/profile"   ]] || mkdir -p "$ZSH_CACHE_DIR/profile"
#   exec 3>&2 2> $ZSH_CACHE_DIR/profile/xtrace.zshenv.$$
#   setopt xtrace
# fi
# # }}}
#
# [[ -d "$ZSH_CACHE_DIR"   ]] || mkdir -p "$ZSH_CACHE_DIR"
# [[ -d "$XDG_CACHE_HOME"  ]] || mkdir -p "$XDG_CACHE_HOME"
# [[ -d "$XDG_CONFIG_HOME" ]] || mkdir -p "$XDG_CONFIG_HOME"
# [[ -d "$XDG_DATA_HOME"   ]] || mkdir -p "$XDG_DATA_HOME"
#
# export DIRSTACKSIZE=16
# export DIRSTACKFILE="$ZSH_CACHE_DIR/dirstack"
#
# export LC_ALL="en_US.UTF-8"
# export LANG="en_US.UTF-8"
#
# SAVEHIST=10000
# HISTSIZE=15000
# HISTFILE="$ZSH_CACHE_DIR/history"
#
# export HOMEBREW_CASK_OPTS="--appdir=/Applications"
# export HOMEBREW_NO_ANALYTICS=1
# export HOMEBREW_NO_INSECURE_REDIRECT=1
#
# export PERL5LIB="/usr/local/lib/perl5/site_perl":$PERL5LIB
#
# # "$(/usr/libexec/java_home)"
# export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_131.jdk/Contents/Home"
#
# export WORDCHARS='!$%&*-;<>?@[]^_~'
#
#
# nginx_path="/opt/nginx/sbin"
# [[ -d "$nginx_path" ]] && [[ ! ("$path" =~ "$nginx_path") ]] && path=(/opt/nginx/sbin $path)
#
# export GOPATH="$HOME/go"
#
# path=(
#   $HOME/.iterm2
#   /usr/local/opt/python/libexec/bin
#   /usr/local/bin
#   /usr/local/sbin
#   /usr/bin
#   /usr/sbin
#   /bin
#   /sbin
#   $JAVA_HOME/bin
#   /usr/local/opt/go/libexec/bin
#   $GOPATH/bin
#   ~/bin
#   $path
#   $HOME/.rvm/bin
# )
#
# # ZSHENV PROFILING END BLOCK {{{
# if [[ "$ZSHENV_PROFILE_STARTUP" == true ]]
# then
#   unsetopt xtrace
#   exec 2>&3 3>&-
# fi
# # }}}

skip_global_compinit=1

export GIT_DISCOVERY_ACROSS_FILESYSTEM=0

# Dont read global configs
# unsetopt GLOBAL_RCS

export VIM="/usr/local/bin/nvim"
export VIMRUNTIME="/usr/local/share/nvim/runtime"

export EDITOR="${VIM}"
export ALTERNATE_EDITOR="$EDITOR"
export CVSEDITOR="$EDITOR"
export FCEDIT="$EDITOR"
export GEM_EDITOR="$EDITOR"
export GIT_EDITOR="$EDITOR"
export PSQL_EDITOR=${EDITOR}
export SUDO_EDITOR="$EDITOR"
export SVN_EDITOR="$EDITOR"
export VISUAL="$EDITOR"

export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"

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

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Use standard ISO 8601 timestamp
# %F equivalent to %Y-%m-%d
# %T equivalent to %H:%M:%S (24-hours format)
export HISTTIMEFORMAT="%F %T "

# Highlight section titles in manual pages.
export LESS_TERMCAP_md="${yellow}"

# Increase Bash history size. Allow 32³ entries; the
# default is 500.
export HISTSIZE="32768"
export SAVEHIST="${HISTSIZE}"
export HISTFILESIZE="${HISTSIZE}"
export HISTFILE="$ZSH_CACHE_DIR/history"
# Make some commands not show up in history
export HISTIGNORE="ls:cd:cd -:pwd:bg:fg:history:clear:exit:date:* --help"
# Omit duplicates and commands that begin with a space from history.
export HISTCONTROL="erasedups:ignoreboth"

export HOMEBREW_CASK_OPTS="--appdir=/Applications"
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_INSECURE_REDIRECT=1

export PERL5LIB="/usr/local/lib/perl5/site_perl":$PERL5LIB

# Avoid issues with `gpg` as installed via Homebrew.
# https://stackoverflow.com/a/42265848/96656
export GPG_TTY="$(tty)"

# "$(/usr/libexec/java_home)"
# Java home directory
export JAVA_HOME="$(/usr/libexec/java_home)"
# export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_131.jdk/Contents/Home"

# declare the environment variables
export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'

# export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
# export WORDCHARS='*?.[]~&;!#$%^(){}<>'
export WORDCHARS='!$%&*-;<>?@[]^_~'

export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"

# Manuals
export MANPATH="/opt/local/share/man:${MANPATH}"

# Don’t clear the screen after quitting a manual page.
export MANPAGER="less -X"

# Specify Node modules path
export NODE_PATH="/usr/local/lib/node_modules"
# Enable persistent REPL history for `node`.
export NODE_REPL_HISTORY="~/.node_history"
# Allow 32³ entries; the default is 1000.
export NODE_REPL_HISTORY_SIZE="32768"
# Use sloppy mode by default, matching web browsers.
export NODE_REPL_MODE="sloppy"

# Make Python use UTF-8 encoding for output to stdin, stdout, and stderr.
export PYTHONIOENCODING="UTF-8"

# Increase Maven memory usage
export MAVEN_OPTS="-Xms1024m -Xmx4096m -XX:PermSize=1024m"

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

zmodload zsh/zpty

# ZSHENV PROFILING END BLOCK {{{
if [[ "$ZSHENV_PROFILE_STARTUP" == true ]]
then
  unsetopt xtrace
  exec 2>&3 3>&-
fi
# }}}
