# vim:ft=zsh:

# ZSHRC PROFILING START BLOCK {{{
ZSHRC_PROFILE_STARTUP=false
if [[ "$ZSHRC_PROFILE_STARTUP" == true ]]
then
  PS4=$'%D{%M%S%.} %N:%i> '
  [[ -d "$ZSH_CACHE_DIR/profile"   ]] || mkdir -p "$ZSH_CACHE_DIR/profile"
  exec 3>&2 2> $ZSH_CACHE_DIR/profile/xtrace.zshrc.$$
  setopt xtrace
fi
# }}}

# FUNCTION PATHES {{{

fpath=(
  $ZDOTDIR/functions
  $fpath
)

# }}}

# MAN PATHES {{{

manpath=(
  /usr/local/opt/coreutils/libexec/gnuman
  /usr/local/opt/gnu-tar/libexec/gnuman
  /usr/local/opt/findutils/libexec/gnuman
  /usr/local/opt/gnu-sed/libexec/gnuman
  $manpath
)

# }}}

# AUTOLOADS {{{

autoload -U +X edit-command-line
autoload -U +X colors && colors

for fn in $ZDOTDIR/functions/*(x)
do
  autoload -U +X "$(basename $fn)"
done

# }}}

# EDITING MODE {{{

set -o vi

# }}}

# HASHES {{{

hash -d zdots="$ZDOTDIR"
hash -d vdots="$HOME/.config/nvim"
hash -d xdots="$HOME/.config"

hash -d applications="/Applications"
hash -d desktop="$HOME/Desktop"
hash -d documents="$HOME/Documents"
hash -d downloads="$HOME/Downloads"
hash -d movies="$HOME/Movies"
hash -d music="$HOME/Music"
hash -d pictures="$HOME/Pictures"

# }}}

# ALIASES {{{

[ -f "$ZDOTDIR/aliases" ] && source "$ZDOTDIR/aliases"

# }}}

# SETOPTS {{{

# SETOPTS: PROMPT {{{

setopt prompt_subst
setopt transient_rprompt

# }}}2

# SETOPTS: HISTORY {{{2

setopt bang_hist
setopt appendhistory
setopt extended_history
setopt hist_ignore_space
setopt inc_append_history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_find_no_dups
setopt hist_reduce_blanks
setopt hist_save_no_dups
setopt hist_expire_dups_first
setopt hist_no_functions
setopt hist_verify

# }}}2

# SETOPTS: CHANGING DIRECTORIES {{{2

setopt auto_cd
setopt cdable_vars
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushd_to_home
setopt pushd_minus
setopt pushd_silent
setopt chase_links

# }}}2

# SETOPTS: EXPANSION & GLOBBING {{{2

setopt extendedglob
setopt glob_dots
unsetopt case_glob
setopt nomatch
setopt globstarshort

# }}}2

# SETOPTS: SCRIPTS & FUNCTIONS {{{2

setopt multios

# }}}2

# SETOPTS: I/O {{{2

setopt clobber
setopt correct
setopt short_loops

# }}}2

# SETOPTS: JOB CONTROL {{{2

setopt auto_resume
setopt bg_nice
setopt hup
setopt check_jobs
setopt notify

# }}}2

# ZLE {{{2

setopt combining_chars
setopt vi

# }}}2

# }}}

# ZLE {{{

zle -N edit-command-line
zle -N zle-keymap-select
zle -N zle-line-init

# }}}

# BINDKEYS {{{

bindkey "^B" commit-to-history

bindkey -v
bindkey -M vicmd v edit-command-line

bindkey '\e.' insert-last-word

bindkey -a u undo
bindkey -a '^r' redo
bindkey '^?' backward-delete-char
bindkey '^H' backward-delete-char
bindkey -M viins ‘jk’ vi-cmd-mode
bindkey -M viins "^r" history-incremental-search-backward
bindkey -M viins "^s" history-incremental-search-forward
bindkey -M vicmd "^s" history-incremental-search-forward
bindkey "\C-x\C-e" edit-command-line
bindkey -M viins "^a" beginning-of-line
bindkey -M viins "^b" backward-char
bindkey -M viins "^d" delete-char-or-list
bindkey -M viins "^e" end-of-line
bindkey -M viins "^f" forward-char
bindkey -M viins "^k" kill-line
bindkey -M viins "^n" down-line-or-history
bindkey -M viins "^p" up-line-or-history
bindkey -M viins "^t" transpose-chars
bindkey -M viins "^y" yank

# }}}

# COMPLETION {{{

export CLICOLOR=1
LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:';

setopt complete_aliases
# setopt complete_in_word
# setopt glob_complete
# setopt always_to_end
# setopt auto_menu

autoload -U +X compinit && compinit -d "$ZSH_CACHE_DIR/.zcompdump"
autoload -U +X bashcompinit && bashcompinit

zmodload -i zsh/complist

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $ZSH_CACHE_DIR

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# # Case-insensitive completion for `cd` etc *N*
# zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# # Fuzzy matching of completions for when you mistype them:
# zstyle ':completion:*' completer _complete _match _approximate
# zstyle ':completion:*:match:*' original only
# zstyle ':completion:*:approximate:*' max-errors 1 numeric

# # Ignore completion functions for commands you don’t have:
# zstyle ':completion:*:functions' ignored-patterns '_*'

# # Fuzzy matching of completions for when you mistype them:
# zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
# zstyle ':completion:*:match:*' original only
# zstyle ':completion:*:approximate:*' max-errors 1 numeric

zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*' force-list always

zstyle ':completion:*:cd:*' ignore-parents parent pwd

# zstyle ':completion:*' file-sort name
# zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
# zstyle ':completion:*' matcher-list '' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|[._-]=** r:|=**' 'l:|=* r:|=*'
# zstyle ':completion:*' menu select=1
# zstyle ':completion:*' original true
# zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
# zstyle ':completion:*' verbose true

# zstyle :compinstall filename "$ZDOTDIR/.zshrc"

# }}}

source "$ZDOTDIR/prompt"

group_lazy_load "$HOME/.rvm/scripts/rvm" rvm irb rake rails bundle pry
unset -f group_lazy_load

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# PROFILING END BLOCK {{{
if [[ "$ZSHRC_PROFILE_STARTUP" == true ]]
then
  unsetopt xtrace
  exec 2>&3 3>&-
fi
# }}}
