zstyle ":completion:*" use-cache on
zstyle ":completion:*" cache-path "$ZSH_CACHE_DIR"
zstyle :compinstall filename "$ZDOTDIR/.zshrc"

# http://zsh.sourceforge.net/Doc/Release/Options.html

#
# PROMPT
#
# If set, parameter expansion, command substitution and arithmetic expansion
# are performed in prompts.
setopt prompt_subst
# Remove any right prompt from display when accepting a command line.
setopt transient_rprompt

#
# HISTORY
#
setopt bang_hist # Enable "!" history expansion
# When exiting, append history entries to $HISTFILE, rather than replacing the
# old file; this is the default
setopt appendhistory
# Save additional info to $HISTFILE
setopt extended_history
# If the commandline starts with a whitespace, don't add it to history
setopt hist_ignore_space
# Append every single command to $HISTFILE immediately after hitting ENTER.
setopt inc_append_history
# Always import new commands from $HISTFILE (see "inc_append_history" above)
setopt share_history
# # Do not enter command lines into the history list if they are duplicates of
# # the previous event.
# setopt hist_ignore_dups
# If a new command line being added to the history list duplicates an older
# one, the older command is removed from the list (even if it is not the
# previous event).
setopt hist_ignore_all_dups
# When searching for history entries in the line editor, do not display dupli-
# cates of a line previously found, even if the duplicates are not contiguous.
setopt hist_find_no_dups
# Remove superfluous blanks from each command line being added to the history
# list.
setopt hist_reduce_blanks
# When writing out the history file, older commands that duplicate newer ones
# are omitted.
setopt hist_save_no_dups
# If the internal history needs to be trimmed to add the current command line,
# setting this option will cause the oldest history event that has a duplicate
# to be lost before losing a unique event from the list.
setopt hist_expire_dups_first
# Remove function definitions from the history list. Note that the function
# lingers in the internal history until the next command is entered before it
# vanishes, allowing you to briefly reuse or edit the definition.
setopt hist_no_functions
# Whenever the user enters a line with history expansion, don't execute the
# line directly; instead, perform history expansion and reload the line into
# the editing buffer.
setopt hist_verify
# (Do not) Beep in ZLE when a widget attempts to access a history entry which isn’t
# there.
setopt no_hist_beep

#
# CHANGING DIRECTORIES
#
# If a directoryname is entered like a command, and there is no command of that
# name; the "cd" command is executed for that directory
setopt auto_cd
# If cd would fail, because the arg is not a dir, try to expand the argument as
# if it was called the ~expression way
setopt cdable_vars
# Make cd push the old directory to the dirstack
setopt auto_pushd
# Don't push multiple copies of the same directory onto the directory stack.
setopt pushd_ignore_dups
# make "pushd" with no argument, act like pushd ${HOME}
setopt pushd_to_home
# Exchanges the meanings of `+" and `-" when used with a number to specify a
# directory in the stack.
setopt pushd_minus
# Do not print the directory stack after pushd or popd.
setopt pushd_silent
# Resolve symbolic links to their true values when changing directory.
setopt chase_links

#
# COMPLETION
#
# don't expand aliases _before_ completion has finished
setopt complete_aliases
# if unset the cursor is set to the end of the word if completion is started
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

# EXPANSION & GLOBBING
# If a pattern for filename generation is badly formed, print an error message.
setopt bad_pattern
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
setopt no_case_glob
# If a pattern for filename generation has no matches, print an error, instead
# of leaving it unchanged in the argument list. This also applies to file
# expansion of an initial ‘~’ or ‘=’.
setopt nomatch

#
# SCRIPTS AND FUNCTIONS
#
# enable multiple redirections: uptime > uptime0.txt > uptime1.txt
setopt multios

#
# I/O
#
# Allow ">" to truncate, and "»" to create files
setopt clobber
# Try to correct the spelling of commands.
setopt correct
# Allow short form loops: `for file in *.pdf; lp ${file}`
setopt short_loops
# If querying the user before executing `rm *" or `rm path/*", first wait ten
# seconds and ignore anything typed in that time. This avoids the problem of
# reflexively answering `yes" to the query when one didn"t really mean it.
setopt rm_star_wait
# Do query the user before executing ‘rm *’ or ‘rm path/*’.
setopt no_rm_star_silent

#
# JOB CONTROL
#
# if you"ve got a simple command suspened, say "mutt", and you forgot that you
# have already got a mutt running and try to start another mutt, the old
# running mutt is resumed, rather than starting a new process
setopt auto_resume
# run background jobs at lower priority
setopt bg_nice
# send SIGHUP to background processes on exit.
setopt hup
# report status of bg-jobs if exiting a shell with job control enabled
setopt check_jobs
# Report the status of background jobs immediately, rather than waiting until
# just before printing a prompt.
setopt notify

# (Do not) Beep on error in ZLE.
setopt no_beep

# Vi all the things!
bindkey -v
set -o vi

# Use C-x C-e to edit the current command line
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey "\C-x\C-e" edit-command-line

# Emacs style
zle -N edit-command-line
bindkey "^xe" edit-command-line
bindkey "^x^e" edit-command-line

# Vi style:
zle -N edit-command-line
zle -N beep
bindkey -M vicmd v edit-command-line

bindkey -M viins "^A" beginning-of-line
bindkey -M viins "^B" backward-char
bindkey -M viins "^D" delete-char-or-list
bindkey -M viins "^E" end-of-line
bindkey -M viins "^F" forward-char
bindkey -M viins "^K" kill-line
bindkey -M viins "^N" down-line-or-history
bindkey -M viins "^P" up-line-or-history
bindkey -M viins "^R" history-incremental-search-backward
bindkey -M viins "^S" history-incremental-search-forward
bindkey -M viins "^T" transpose-chars
bindkey -M viins "^Y" yank

# hash -d vim=$HOME/dotfiles/vim
# hash -d zsh=$HOME/dotfiles/zsh
hash -d api="$HOME/wmx/bp/v2"
hash -d assets="$HOME/wmx/bp/assets"
hash -d bp="$HOME/wmx/bp"
hash -d course_publisher="$HOME/wmx/bp/course-publisher"
hash -d dotfiles="$HOME/dotfiles"
hash -d instructor_dashboard="$HOME/wmx/bp/instructor-dashboard"
hash -d marketing_admin="$HOME/wmx/bp/marketing-admin"
hash -d marketing="$HOME/wmx/bp/marketing"
hash -d reporting_api="$HOME/wmx/bp/reporting-api"
hash -d s3="$HOME/wmx/s3"
hash -d src="$HOME/src"
hash -d sso="$HOME/wmx/bp/sso"
hash -d teachers="$HOME/wmx/bp/teachers"
hash -d tenant_dashboard="$HOME/wmx/bp/tenant-dashboard"
hash -d user_manager="$HOME/wmx/bp/user-manager"
hash -d web="$HOME/wmx/bp/webapp"
hash -d wikis="$HOME/wmx/wikis"
hash -d wmx="$HOME/wmx"
hash -d download="$HOME/Downloads"
hash -d pictures="$HOME/Pictures"
hash -d documents="$HOME/Documents"
hash -d dbx="$HOME/Dropbox/mike"
hash -d zdots="$ZDOTDIR"

fpath=(
  $ZDOTDIR/fns
  $ZDOTDIR/Completion
  /usr/local/share/zsh-completions
  /usr/local/share/zsh/site-functions

  $fpath
)

autoload -Uz compinit && compinit
autoload -Uz promptinit && promptinit
autoload -Uz regexp-replace

for fn in $ZDOTDIR/fns/*(x)
do
  autoload -Uz "$(basename $fn)"
done

source "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "/usr/local/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "/usr/local/share/zsh-navigation-tools/zsh-navigation-tools.plugin.zsh"
source "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

source $ZDOTDIR/.aliasesrc

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
