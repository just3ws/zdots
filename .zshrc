# vim:set filetype=zsh expandtab shiftwidth=2 textwidth=64:

# Profiling start block {{{

PROFILE_STARTUP=false

if [[ "$PROFILE_STARTUP" == true ]]; then

  PS4=$'%D{%M%S%.} %N:%i> '

  exec 3>&2 2>$HOME/tmp/startlog.$$

  setopt xtrace
fi

# }}}

# Autoloads {{{

autoload -Uz compinit
compinit

autoload -Uz colors && colors
autoload -Uz promptinit && promptinit
autoload -Uz regexp-replace
autoload -Uz edit-command-line

for fn in $ZDOTDIR/functions/*(x)
do
  autoload -Uz "$( basename $fn )"
done

# zmv "programmable rename"
autoload -Uz zmv

# }}}

# Editing Mode {{{

# Vi all the things!
set -o vi

# }}}

# Hashes {{{

hash -d documents="$HOME/Documents"
hash -d dotfiles="$HOME/dotfiles"
hash -d download="$HOME/Downloads"
hash -d pictures="$HOME/Pictures"
hash -d src="$HOME/src"
hash -d zdots="$ZDOTDIR"
hash -d vdots="$HOME/.config/nvim"

# }}}

# Aliases {{{

[ -f "$ZDOTDIR/.zsh_aliases" ] && source "$ZDOTDIR/.zsh_aliases"

# }}}

# Dircolors {{{

CLICOLOR=YES
LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:';

# }}}

# Setopts {{{

# http://zsh.sourceforge.net/Doc/Release/Options.html

# Setopts: PROMPT {{{

# If set, parameter expansion, command substitution and
# arithmetic expansion are performed in prompts.
setopt PROMPT_SUBST

# Remove any right prompt from display when accepting a command
# line.
unsetopt TRANSIENT_RPROMPT

# }}}2

# Setopts: HISTORY {{{2

# Enable "!" history expansion
setopt BANG_HIST

# When exiting, append history entries to $HISTFILE, rather than
# replacing the old file; this is the default
setopt APPENDHISTORY

# Save additional info to $HISTFILE
setopt EXTENDED_HISTORY

# If the commandline starts with a whitespace, don't add it to
# history
setopt HIST_IGNORE_SPACE

# Append every single command to $HISTFILE immediately after
# hitting ENTER.
setopt INC_APPEND_HISTORY

# Always import new commands from $HISTFILE (see
# "inc_append_history" above)
setopt SHARE_HISTORY

# If a new command line being added to the history list
# duplicates an older one, the older command is removed from the
# list (even if it is not the previous event).
setopt HIST_IGNORE_ALL_DUPS

# When searching for history entries in the line editor, do not
# display duplicates of a line previously found, even if the
# duplicates are not contiguous.
setopt HIST_FIND_NO_DUPS

# Remove superfluous blanks from each command line being added
# to the history list.
setopt HIST_REDUCE_BLANKS

# When writing out the history file, older commands that
# duplicate newer ones are omitted.
setopt HIST_SAVE_NO_DUPS

# If the internal history needs to be trimmed to add the current
# command line, setting this option will cause the oldest
# history event that has a duplicate to be lost before losing a
# unique event from the list.
setopt HIST_EXPIRE_DUPS_FIRST

# Remove function definitions from the history list. Note that
# the function lingers in the internal history until the next
# command is entered before it vanishes, allowing you to briefly
# reuse or edit the definition.
setopt HIST_NO_FUNCTIONS

# Whenever the user enters a line with history expansion, don't
# execute the line directly; instead, perform history expansion
# and reload the line into the editing buffer.
setopt HIST_VERIFY

# # (Do not) Beep in ZLE when a widget attempts to access a
# # history entry which isn’t there.
# unsetopt HIST_BEEP

# }}}2

# Setopts: CHANGING DIRECTORIES {{{2

# If a directoryname is entered like a command, and there is no
# command of that name; the "cd" command is executed for that
# directory
setopt AUTO_CD

# If cd would fail, because the arg is not a dir, try to expand
# the argument as if it was called the ~expression way
setopt CDABLE_VARS

# Make cd push the old directory to the dirstack
setopt AUTO_PUSHD

# Don't push multiple copies of the same directory onto the
# directory stack.
setopt PUSHD_IGNORE_DUPS

# make "pushd" with no argument, act like pushd ${HOME}
setopt PUSHD_TO_HOME

# Exchanges the meanings of `+" and `-" when used with a number
# to specify a directory in the stack.
setopt PUSHD_MINUS

# Do not print the directory stack after pushd or popd.
setopt PUSHD_SILENT

# Resolve symbolic links to their true values when changing
# directory.
setopt CHASE_LINKS

 # }}}2

# Setopts: COMPLETION {{{2

# don't expand aliases _before_ completion has finished
setopt COMPLETE_ALIASES

# if unset the cursor is set to the end of the word if
# completion is started
setopt COMPLETE_IN_WORD

# cycle through globbing matches like menu_complete
setopt GLOB_COMPLETE

# If a completion is performed with the cursor within a word, and a full
# completion is inserted, the cursor is moved to the end of the word. That is,
# the cursor is moved to the end of the word if either a single match is
# inserted or menu completion is performed.
setopt ALWAYS_TO_END

# Automatically use menu completion after the second consecutive request for
# completion, for example by pressing the tab key repeatedly.
setopt AUTO_MENU

# }}}2

# Setopts: EXPANSION & GLOBBING {{{2

# If a pattern for filename generation is badly formed, print an error message.
# setopt BAD_PATTERN
# Treat the ‘#’, ‘~’ and ‘^’ characters as part of patterns for filename
# generation, etc. (An initial unquoted ‘~’ always produces named directory
# expansion.)
setopt EXTENDEDGLOB

# Do not require a leading ‘.’ in a filename to be matched explicitly.
setopt GLOB_DOTS

# (Do not) Make globbing (filename generation) sensitive to case. Note that other uses
# of patterns are always sensitive to case. If the option is unset, the
# presence of any character which is special to filename generation will cause
# case-insensitive matching.
unsetopt CASE_GLOB

# If a pattern for filename generation has no matches, print an error, instead
# of leaving it unchanged in the argument list. This also applies to file
# expansion of an initial ‘~’ or ‘=’.
setopt NOMATCH

# Treat **word as **/word
setopt GLOBSTARSHORT

# }}}2

# Setopts: SCRIPTS AND FUNCTIONS {{{2

# enable multiple redirections: uptime > uptime0.txt > uptime1.txt
setopt MULTIOS

# }}}2

# Setopts: I/O {{{2

# Allow ">" to truncate, and "»" to create files
setopt CLOBBER

# Try to correct the spelling of commands.
setopt CORRECT

# Allow short form loops: `for file in *.pdf; lp ${file}`
setopt SHORT_LOOPS

# # If querying the user before executing `rm *" or `rm path/*", first wait ten
# # seconds and ignore anything typed in that time. This avoids the problem of
# # reflexively answering `yes" to the query when one didn"t really mean it.
# setopt RM_STAR_WAIT

# # Do query the user before executing ‘rm *’ or ‘rm path/*’.
# unsetopt RM_STAR_SILENT

# }}}2

# Setopts: JOB CONTROL {{{2

# If you've got a simple command suspened, say "mutt", and you
# forgot that you have already got a mutt running and try to
# start another mutt, the old running mutt is resumed, rather
# than starting a new process
setopt AUTO_RESUME

# run background jobs at lower priority
setopt BG_NICE

# Send SIGHUP to background processes on exit.
setopt HUP

# report status of bg-jobs if exiting a shell with job control
# enabled
setopt CHECK_JOBS

# Report the status of background jobs immediately, rather than
# waiting until just before printing a prompt.
setopt NOTIFY

# }}}2

# Zle {{{2

# # (Do not) Beep on error in ZLE.
# unsetopt beep

# Assume that the terminal displays combining characters
# correctly.
setopt combining_chars

# If ZLE is loaded, turning on this option has the equivalent
# effect of ‘bindkey -v’.
setopt vi

# }}}2

# }}}

# Zle {{{

# zle -N beep
zle -N edit-command-line

# }}}

# Zmodloads {{{

# Colorful autocompletion for `cd` command
zmodload -i zsh/complist

# }}}

# Bindkeys {{{

# vi-mode
bindkey -v

# ZLE emacs-mode
bindkey "\C-x\C-e" edit-command-line

# ZLE vi-mode
bindkey -M vicmd v edit-command-line

# Add missing Vim key chords to vi-mode
# fixes backspace deletion issues
# http://zshwiki.org/home/zle/vi-mode
bindkey -a u undo
bindkey -a '^r' redo
bindkey '^?' backward-delete-char
bindkey '^H' backward-delete-char

# History search in vi-mode
# http://zshwiki.org/home/zle/bindkeys#why_isn_t_control-r_working_anymore
bindkey -M viins "^r" history-incremental-search-backward
bindkey -M viins "^s" history-incremental-search-forward
bindkey -M vicmd "^s" history-incremental-search-forward

# Emacs key chords in vi-mode
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

# Zstyles {{{

zstyle :compinstall filename "$ZDOTDIR/.zshrc"

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $ZSH_CACHE_DIR

# Colorful cd completion
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Case-insensitive completion for `cd` etc *N*
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Fuzzy matching of completions for when you mistype them:
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# Ignore completion functions for commands you don’t have:
zstyle ':completion:*:functions' ignored-patterns '_*'

# Fuzzy matching of completions for when you mistype them:
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# Completing process IDs with menu selection:
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*'   force-list always

# cd will never select the parent directory (e.g.: cd ../<TAB>):
zstyle ':completion:*:cd:*' ignore-parents parent pwd


# }}}

# Function pathes {{{

fpath=(
  $ZDOTDIR/functions
  $ZDOTDIR/completions
  /usr/local/share/zsh/site-functions/_brew*
  /usr/local/share/zsh/site-functions/_git
  $fpath
)

# }}}

# Sources {{{

source "$HOME/.rvm/scripts/rvm"
source "$ZDOTDIR/functions/colored-man-pages"

# }}}

# Prompt {{{

autoload -Uz vcs_info

zstyle ':vcs_info:*' disable bzr cdv cvs darcs fossil hg mtn p4 svk svn tla
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:*' actionformats '%F{5}(%f%s%F{5})%F{3}-%F{5}[%F{2}%b%F{3}|%F{1}%a%F{5}]%f '
# zstyle ':vcs_info:*' formats '%F{5}[%F{2}%b%F{5}]%f'

# %r The name of the root directory of the repository
# %b Branch information, like master
# %m In case of Git, show information about stashes
# %c Show staged changes in the repository
# %u Show unstaged changes in the repository
# %S The current path relative to the repository root directory
# %s The current version control system, like git or svn.

zstyle ':vcs_info:*' formats ' %F{1}[%r:%S %b %c %u]%f'
zstyle ':vcs_info:git:*:-all-' command /usr/local/bin/git
precmd () vcs_info

# vcs_info_wrapper () {
#   vcs_info
#
#   if [ -n "$vcs_info_msg_0_" ]
#   then
#     echo "%s%{$fg[grey]%}${vcs_info_msg_0_}%{$reset_color%}$del"
#   fi
# }

RPS1='${vcs_info_msg_0_}'
RPS2="$RPS1"

# 
interactive="%{$fg_bold[green]%}%{$reset_color%}"
normal="%{$fg_bold[red]%}%{$reset_color%}"
prompt_decoration="%{$fg_bold[yellow]%}❱%{$reset_color%}%{$fg_bold[blue]%}❱%{$reset_color%}%{$fg_bold[red]%}❱%{$reset_color%}"

zle -N zle-line-init
zle -N zle-keymap-select

function zle-line-init zle-keymap-select {
  local mode="${${KEYMAP/vicmd/ $normal}/(main|viins)/ $interactive}"

  PS1="$mode %2~ $prompt_decoration "
  PS2="$PS1"

  zle reset-prompt
}

# }}}

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# Profiling end block {{{

if [[ "$PROFILE_STARTUP" == true ]]
then
  unsetopt xtrace

  exec 2>&3 3>&-
fi

# }}}
