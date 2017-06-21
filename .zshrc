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

# }}}

# ALIASES {{{

[ -f "$ZDOTDIR/aliases" ] && source "$ZDOTDIR/aliases"

# }}}

# SETOPTS {{{

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

setopt complete_in_word    # Complete from both ends of a word.
setopt always_to_end       # Move cursor to the end of a completed word.
setopt path_dirs           # Perform path search even on command names with slashes.
setopt auto_menu           # Show completion menu on a successive tab press.
setopt auto_list           # Automatically list choices on ambiguous completion.
setopt auto_param_slash    # If completed parameter is a directory, add a trailing slash.
setopt extended_glob       # Needed for file modification glob modifiers with compinit
unsetopt menu_complete     # Do not autoselect the first completion entry.
unsetopt flow_control      # Disable start/stop characters in shell editor.

# setopt complete_aliases
# setopt glob_complete

# Load and initialize the completion system ignoring insecure directories with a
# cache time of 20 hours, so it should almost always regenerate the first time a
# shell is opened each day.
autoload -Uz compinit
compfiles=($ZSH_CACHE_DIR/.zcompdump(Nm-20))
if [[ $#compfiles > 0 ]]
then
  compinit -i -C
else
  compinit -i
fi

zmodload -i zsh/complist

zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "$ZSH_CACHE_DIR/.zcompcache"

zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# Case-insensitive (all), partial-word, and then substring completion.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
unsetopt case_glob

# Group matches and describe.
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes

# Fuzzy match mistyped completions.
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# Increase the number of errors based on the length of the typed word. But make
# sure to cap (at 7) the max-errors to avoid hanging.
zstyle -e ':completion:*:approximate:*' max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3>7?7:($#PREFIX+$#SUFFIX)/3))numeric)'

# Don't complete unavailable commands.
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'

# Array completion element sorting.
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

# Directories
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'
zstyle ':completion:*' squeeze-slashes true

# History
zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes

# Environmental Variables
zstyle ':completion::*:(-command-|export):*' fake-parameters ${${${_comps[(I)-value-*]#*,}%%,*}:#-*-}

# Populate hostname completion.
zstyle -e ':completion:*:hosts' hosts 'reply=(
  ${=${=${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) 2>/dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ }
  ${=${(f)"$(cat /etc/hosts(|)(N) <<(ypcat hosts 2>/dev/null))"}%%\#*}
  ${=${${${${(@M)${(f)"$(cat ~/.ssh/config 2>/dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}}
)'

# Ignore multiple entries.
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
zstyle ':completion:*:rm:*' file-patterns '*:all-files'

# Kill
zstyle ':completion:*:*:*:*:processes' command 'ps -u $LOGNAME -o pid,user,command -w'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;36=0=01'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:kill:*' force-list always
zstyle ':completion:*:*:kill:*' insert-ids single

# Man
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true

# SSH/SCP/RSYNC
zstyle ':completion:*:(scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
zstyle ':completion:*:ssh:*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|::)([[:xdigit:].]##:(#c,2))##(|%*))' '127.0.0.<->' '255.255.255.255' '::1' 'fe80::*'

# # Case-insensitive completion for `cd` etc *N*
# zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# # Fuzzy matching of completions for when you mistype them:
# zstyle ':completion:*' completer _complete _match _approximate
# zstyle ':completion:*:match:*' original only
# zstyle ':completion:*:approximate:*' max-errors 1 numeric

# # Fuzzy matching of completions for when you mistype them:
# zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
# zstyle ':completion:*:match:*' original only
# zstyle ':completion:*:approximate:*' max-errors 1 numeric

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

[ -f "$ZDOTDIR/prompt" ] && source "$ZDOTDIR/prompt"

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
