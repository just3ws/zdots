# vim:set filetype=zsh expandtab shiftwidth=2 textwidth=64:

# http://zsh.sourceforge.net/Doc/Release/Options.html

#
# PROMPT
#
# If set, parameter expansion, command substitution and
# arithmetic expansion are performed in prompts.
setopt PROMPT_SUBST
# Remove any right prompt from display when accepting a command
# line.
setopt TRANSIENT_RPROMPT

#
# HISTORY
#
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
# (Do not) Beep in ZLE when a widget attempts to access a
# history entry which isn’t there.
unsetopt HIST_BEEP

#
# CHANGING DIRECTORIES
#
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

#
# COMPLETION
#
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

# EXPANSION & GLOBBING
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

#
# SCRIPTS AND FUNCTIONS
#
# enable multiple redirections: uptime > uptime0.txt > uptime1.txt
setopt MULTIOS

#
# I/O
#
# Allow ">" to truncate, and "»" to create files
setopt CLOBBER
# Try to correct the spelling of commands.
setopt CORRECT
# Allow short form loops: `for file in *.pdf; lp ${file}`
setopt SHORT_LOOPS
# If querying the user before executing `rm *" or `rm path/*", first wait ten
# seconds and ignore anything typed in that time. This avoids the problem of
# reflexively answering `yes" to the query when one didn"t really mean it.
setopt RM_STAR_WAIT
# Do query the user before executing ‘rm *’ or ‘rm path/*’.
unsetopt RM_STAR_SILENT

#
# JOB CONTROL
#
# If you"ve got a simple command suspened, say "mutt", and you
# forgot that you have already got a mutt running and try to
# start another mutt, the old running mutt is resumed, rather
# than starting a new process
setopt AUTO_RESUME
# run background jobs at lower priority
setopt BG_NICE
# Send SIGHUP to background processes on exit.
setopt HUP
# report status of bg-jobs if exiting a shell with job control enabled
setopt CHECK_JOBS
# Report the status of background jobs immediately, rather than waiting until
# just before printing a prompt.
setopt NOTIFY

# (Do not) Beep on error in ZLE.
unsetopt BEEP
