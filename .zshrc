# vim:ft=zsh:

# Profiling start block {{{
PROFILE_STARTUP=false

if [[ "$PROFILE_STARTUP" == true ]]
then
	PS4=$'%D{%M%S%.} %N:%i> '
	mkdir -p $ZSH_CACHE_DIR/tmp
	exec 3>&2 2> $ZSH_CACHE_DIR/tmp/xtrace.$$
	setopt xtrace
fi
# }}}

# Function pathes {{{

fpath=(
	$ZDOTDIR/functions
	$ZDOTDIR/completions
	/usr/local/share/zsh/site-functions
	$fpath
)

# }}}

# Autoloads {{{

autoload -Uz compinit
autoload -Uz colors
autoload -Uz edit-command-line
autoload -Uz vcs_info

for fn in $ZDOTDIR/functions/*(x)
do
	autoload -Uz "$(basename $fn)"
done

# }}}

# Editing Mode {{{

# Vi all the things!
set -o vi

# }}}

# Hashes {{{

hash -d zdots="$ZDOTDIR"
hash -d vdots="$HOME/.config/nvim"

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

# Aliases {{{

[ -f "$ZDOTDIR/.zsh_aliases" ] && source "$ZDOTDIR/.zsh_aliases"

# }}}

# Dircolors {{{

export CLICOLOR=1
export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:';

# export BASE16_SHELL=$HOME/.config/base16-shell/
# [ -n "$PS1" ] && [ -s $BASE16_SHELL/profile_helper.sh ] && eval "$($BASE16_SHELL/profile_helper.sh)"

# }}}

# Setopts {{{

# http://zsh.sourceforge.net/Doc/Release/Options.html

# Setopts: PROMPT {{{

# If set, parameter expansion, command substitution and
# arithmetic expansion are performed in prompts.
setopt PROMPT_SUBST

# Remove any right prompt from display when accepting a command
# line.
setopt TRANSIENT_RPROMPT

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

zle -N edit-command-line
zle -N zle-keymap-select
zle -N zle-line-init

# }}}

# Zmodloads {{{

# Colorful autocompletion for `cd` command
zmodload -i zsh/complist

# }}}

# Bindkeys {{{

# vi-mode
bindkey -v
bindkey -M vicmd v edit-command-line

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

# Sources {{{

source "$HOME/.rvm/scripts/rvm"
source "$ZDOTDIR/functions/colored-man-pages"

# }}}

source "$ZDOTDIR/.zprompt"

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# Profiling end block {{{
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

# Glyphs {{{
#
# BRANCH    
# COMMIT  
# COMPARE  
# DELTA Δ
# DIFF 
# DIFF-ADDED 
# DIFF-IGNORED 
# DIFF-MODIFIED 
# DIFF-REMOVED 
# DIFF-RENAMED 
# DOT • ∙ ∘ ⌾
# DOWNLOAD  
# HOME 
# LOGO BITBUCKET   
# LOGO GIT    
# LOGO GITHUB          
# LOGO GITLAB 
# LOGO HEROKU  
# MERGE  
# PULL-REQUEST  
# REPO 
# REPO-CLONE 
# REPO-FORCE-PUSH 
# REPO-FORKED 
# REPO-PULL 
# REPO-PUSH 
# UPLOAD  
# ↪ ↳ ⇲
# ⇄ ⇋ ⇔
# ⋢ ⋣ ⊏ ⊐ ⌀
# 
# 
#     
# 
# 
# 
#  
#    
#  

# }}}
