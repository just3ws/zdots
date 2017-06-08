# vim:ft=zsh:

# PROFILING START BLOCK {{{
PROFILE_STARTUP=false

if [[ "$PROFILE_STARTUP" == true ]]
then
	PS4=$'%D{%M%S%.} %N:%i> '
	mkdir -p $ZSH_CACHE_DIR/tmp
	exec 3>&2 2> $ZSH_CACHE_DIR/tmp/xtrace.$$
	setopt xtrace
fi
# }}}

# FUNCTION PATHES {{{

typeset -U fpath
fpath=(
  $ZDOTDIR/functions
  $ZDOTDIR/completions
  /usr/local/share/zsh/site-functions
  $fpath
)

# }}}

# AUTOLOADS {{{

autoload -Uz edit-command-line
autoload -Uz vcs_info
autoload -Uz colors && colors

for fn in $ZDOTDIR/functions/*(x)
do
	autoload -Uz "$(basename $fn)"
done

# }}}

# EDITING MODE {{{

# Vi all the things!
set -o vi

# }}}

# HASHES {{{

hash -d zdots="$ZDOTDIR"
hash -d vdots="$HOME/.config/nvim"
hash -d xdots="$HOME/.config"

# Apple
hash -d applications="/Applications"
# ~
hash -d desktop="$HOME/Desktop"
hash -d documents="$HOME/Documents"
hash -d downloads="$HOME/Downloads"
hash -d movies="$HOME/Movies"
hash -d music="$HOME/Music"
hash -d pictures="$HOME/Pictures"

# }}}

# ALIASES {{{

[ -f "$ZDOTDIR/.zsh_aliases" ] && source "$ZDOTDIR/.zsh_aliases"

# }}}

# SETOPTS {{{

# http://zsh.sourceforge.net/Doc/Release/Options.html

# SETOPTS: PROMPT {{{

# If set, parameter expansion, command substitution and
# arithmetic expansion are performed in prompts.
setopt prompt_subst

# Remove any right prompt from display when accepting a command
# line.
setopt transient_rprompt

# }}}2

# SETOPTS: HISTORY {{{2

# Enable "!" history expansion
setopt bang_hist

# When exiting, append history entries to $HISTFILE, rather than
# replacing the old file; this is the default
setopt appendhistory

# Save additional info to $HISTFILE
setopt extended_history

# If the commandline starts with a whitespace, don't add it to
# history
setopt hist_ignore_space

# Append every single command to $HISTFILE immediately after
# hitting ENTER.
setopt inc_append_history

# Always import new commands from $HISTFILE (see
# "inc_append_history" above)
setopt share_history

# If a new command line being added to the history list
# duplicates an older one, the older command is removed from the
# list (even if it is not the previous event).
setopt hist_ignore_all_dups

# When searching for history entries in the line editor, do not
# display duplicates of a line previously found, even if the
# duplicates are not contiguous.
setopt hist_find_no_dups

# Remove superfluous blanks from each command line being added
# to the history list.
setopt hist_reduce_blanks

# When writing out the history file, older commands that
# duplicate newer ones are omitted.
setopt hist_save_no_dups

# If the internal history needs to be trimmed to add the current
# command line, setting this option will cause the oldest
# history event that has a duplicate to be lost before losing a
# unique event from the list.
setopt hist_expire_dups_first

# Remove function definitions from the history list. Note that
# the function lingers in the internal history until the next
# command is entered before it vanishes, allowing you to briefly
# reuse or edit the definition.
setopt hist_no_functions

# Whenever the user enters a line with history expansion, don't
# execute the line directly; instead, perform history expansion
# and reload the line into the editing buffer.
setopt hist_verify

# # (Do not) Beep in ZLE when a widget attempts to access a
# # history entry which isn’t there.
# unsetopt HIST_BEEP

# }}}2

# SETOPTS: CHANGING DIRECTORIES {{{2

# if a directoryname is entered like a command, and there is no
# command of that name; the "cd" command is executed for that
# directory
setopt auto_cd

# if cd would fail, because the arg is not a dir, try to expand
# the argument as if it was called the ~expression way
setopt cdable_vars

# make cd push the old directory to the dirstack
setopt auto_pushd

# don't push multiple copies of the same directory onto the
# directory stack.
setopt pushd_ignore_dups

# make "pushd" with no argument, act like pushd ${home}
setopt pushd_to_home

# exchanges the meanings of `+" and `-" when used with a number
# to specify a directory in the stack.
setopt pushd_minus

# do not print the directory stack after pushd or popd.
setopt pushd_silent

# resolve symbolic links to their true values when changing
# directory.
setopt chase_links

# }}}2

# SETOPTS: COMPLETION {{{2

# don't expand aliases _before_ completion has finished
setopt complete_aliases

# if unset the cursor is set to the end of the word if
# completion is started
setopt complete_in_word

# cycle through globbing matches like menu_complete
setopt glob_complete

# If a completion is performed with the cursor within a word, and a full
# completion is inserted, the cursor is moved to the end of the word. That is,
# the cursor is moved to the end of the word if either a single match is
# inserted or menu completion is performed.
setopt always_to_end

# Automatically use menu completion after the second consecutive request for
# completion, for example by pressing the tab key repeatedly.
setopt auto_menu

# }}}2

# SETOPTS: EXPANSION & GLOBBING {{{2

# If a pattern for filename generation is badly formed, print an error message.
# setopt BAD_PATTERN
# Treat the ‘#’, ‘~’ and ‘^’ characters as part of patterns for filename
# generation, etc. (An initial unquoted ‘~’ always produces named directory
# expansion.)
setopt extendedglob

# Do not require a leading ‘.’ in a filename to be matched explicitly.
setopt glob_dots

# (Do not) Make globbing (filename generation) sensitive to case. Note that other uses
# of patterns are always sensitive to case. If the option is unset, the
# presence of any character which is special to filename generation will cause
# case-insensitive matching.
unsetopt case_glob

# If a pattern for filename generation has no matches, print an error, instead
# of leaving it unchanged in the argument list. This also applies to file
# expansion of an initial ‘~’ or ‘=’.
setopt nomatch

# Treat **word as **/word
setopt globstarshort

# }}}2

# SETOPTS: SCRIPTS & FUNCTIONS {{{2

# enable multiple redirections: uptime > uptime0.txt > uptime1.txt
setopt multios

# }}}2

# SETOPTS: I/O {{{2

# Allows ‘>’ redirection to truncate existing files. Otherwise ‘>!’ or ‘>|’
# must be used to truncate a file.
setopt clobber

# Try to correct the spelling of commands.
setopt correct

# Allow the short forms of for, repeat, select, if, and function constructs.
setopt short_loops

# # if querying the user before executing `rm *" or `rm path/*", first wait ten
# # seconds and ignore anything typed in that time. this avoids the problem of
# # reflexively answering `yes" to the query when one didn"t really mean it.
# setopt rm_star_wait

# # do query the user before executing ‘rm *’ or ‘rm path/*’.
# unsetopt rm_star_silent

# }}}2

# SETOPTS: JOB CONTROL {{{2

# Treat single word simple commands without redirection as candidates for
# resumption of an existing job.
setopt auto_resume

# Run all background jobs at a lower priority.
setopt bg_nice

# Send the HUP signal to running jobs when the shell exits.
setopt hup

# Report the status of background and suspended jobs before exiting a shell
# with job control; a second attempt to exit the shell will succeed.
setopt check_jobs

# Report the status of background jobs immediately, rather than waiting until
# just before printing a prompt.
setopt notify

# }}}2

# ZLE {{{2

# # (do not) beep on error in zle.
# unsetopt beep

# assume that the terminal displays combining characters
# correctly.
setopt combining_chars

# if zle is loaded, turning on this option has the equivalent
# effect of ‘bindkey -v’.
setopt vi

# }}}2

# }}}

# ZLE {{{

zle -N edit-command-line
# zle -N zle-keymap-select
# zle -N zle-line-init

# }}}

# ZMODLOADS {{{

# Colorful autocompletion for `cd` command
zmodload -i zsh/complist

# }}}

# BINDKEYS {{{

# vi-mode
bindkey -v
bindkey -M vicmd v edit-command-line

# !$
bindkey '\e.' insert-last-word

# Add missing Vim key chords to vi-mode fixes backspace deletion issues
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

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $ZSH_CACHE_DIR

# Colorful cd completion
export CLICOLOR=1
export LS_COLORS='rs=00:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:*.rb=00;35:*.zwc=00;22';

# zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Case-insensitive completion for `cd` etc *N*
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Fuzzy matching of completions for when you mistype them:
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# Ignore completion functions for commands you don’t have:
zstyle ':completion:*:functions' ignored-patterns '_*'

# Fuzzy matching of completions for when you mistype them:
zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# Completing process IDs with menu selection:
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*'   force-list always

# cd will never select the parent directory (e.g.: cd ../<TAB>):
zstyle ':completion:*:cd:*' ignore-parents parent pwd

zstyle ':completion:*' file-sort name
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|[._-]=** r:|=**' 'l:|=* r:|=*'
zstyle ':completion:*' menu select=1
zstyle ':completion:*' original true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' verbose true

zstyle :compinstall filename "$ZDOTDIR/.zshrc"

autoload -Uz compinstall
autoload -Uz compinit && compinit

# }}}

# SOURCES {{{

source "$HOME/.rvm/scripts/rvm"
source "$ZDOTDIR/functions/colored-man-pages"

# }}}

source "$ZDOTDIR/.zprompt"

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# PROFILING END BLOCK {{{
if [[ "$PROFILE_STARTUP" == true ]]
then
	unsetopt xtrace
	exec 2>&3 3>&-
fi
# }}}

#
# ()MODIFIED ()ADDED ()REMOVED
# (S)taged/(U)nstaged
# () S(T)ashed
# () (U)ntracked
#
# Count (L)ocal commits not pushed to Remote
# Count (R)emote commits not present in Local
# (D)iverged branch state
#
# (SU SU SU U T) L ⊄ R
#
# no modified, one staged addition, two staged deletions, no untracked files,
# no stashed, no pending commits, no remote commits detected
# (00 10 20 0 0) 0  0
#
# three unstaged modified, zero additions/deletions, two untracked files, one
# stashed, two pending commits, zero remote commits detected
# (03 00 00 2 1) 2 ⊄ 0
#
# = branches =
# == behind remote ==
# ⊂ L is a subset of R, but L is not equal to R
#
# == ahead of remote ==
# ⊃ L is a superset of R, but R is not equal to L
#
# == diverged ==
# ⊄ L is not a subset of R
# ⊅ L is not a superset of R
#
# == clean ==
#  L is equal to R
#
# = status =

