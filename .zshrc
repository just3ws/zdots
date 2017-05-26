zstyle ":completion:*" use-cache on
zstyle ":completion:*" cache-path "$ZSH_CACHE_DIR"
zstyle :compinstall filename "$ZDOTDIR/.zshrc"


# PROMPT
# If set, parameter expansion, command substitution and arithmetic expansion
# are performed in prompts.
setopt prompt_subst
# Remove any right prompt from display when accepting a command line.
setopt transient_rprompt

# [ -d ./.git ] && git rev-parse --abbrev-ref HEAD

# HISTORY
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
unsetopt hist_beep

# SAFETY GUARDS
# If querying the user before executing `rm *" or `rm path/*", first wait ten
# seconds and ignore anything typed in that time. This avoids the problem of
# reflexively answering `yes" to the query when one didn"t really mean it.
setopt rm_star_wait
# Query the user before executing `rm *` or `rm path/*`
unsetopt rm_star_silent

# CHDIR
# If a directoryname is entered like a command, and there is no command of that
# name; the "cd" command is executed for that directory
setopt autocd
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

# COMPLETION
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
# if a pattern or glob is badly formed, print out an error
setopt bad_pattern
# globbing++
setopt extendedglob
# don't require a leading dot for matching "hidden" files
setopt glob_dots

# scripting
# enable multiple redirections: uptime > uptime0.txt > uptime1.txt
setopt multios

# I/O
# allow ">" to truncate, and "»" to create files
setopt clobber
# try to correct the spelling of commands.
setopt correct
# allow short form loops: `for file in *.pdf; lp ${file}`
setopt short_loops

# JOB CONTROL
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

setopt nomatch
setopt notify

# Be quiet, seriously. I'm usually wearing headphones.
unsetopt beep

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

# hash -d vim=~/dotfiles/vim
# hash -d zsh=~/dotfiles/zsh
hash -d api="~/wmx/bp/v2"
hash -d assets="~/wmx/bp/assets"
hash -d bp="~/wmx/bp"
hash -d course_publisher="~/wmx/bp/course-publisher"
hash -d dotfiles="~/dotfiles"
hash -d instructor_dashboard="~/wmx/bp/instructor-dashboard"
hash -d marketing_admin="~/wmx/bp/marketing-admin"
hash -d marketing="~/wmx/bp/marketing"
hash -d reporting_api="~/wmx/bp/reporting-api"
hash -d s3="~/wmx/s3"
hash -d src="~/src"
hash -d sso="~/wmx/bp/sso"
hash -d teachers="~/wmx/bp/teachers"
hash -d tenant_dashboard="~/wmx/bp/tenant-dashboard"
hash -d user_manager="~/wmx/bp/user-manager"
hash -d web="~/wmx/bp/webapp"
hash -d wikis="~/wmx/wikis"
hash -d wmx="~/wmx"
hash -d download="~/Downloads"
hash -d pictures="~/Pictures"
hash -d documents="~/Documents"
hash -d dbx="~/Dropbox/mike"
hash -d zdots="$ZDOTDIR"

fpath=(
  /Users/mike/.config/zsh/fns
  /Users/mike/.config/zsh/Completion
  /usr/local/share/zsh-completions
  /usr/local/share/zsh/site-functions

  $fpath
)

autoload -Uz compinit && compinit
autoload -Uz promptinit && promptinit
autoload -Uz regexp-replace

for fn in /Users/mike/.config/zsh/fns/*(x)
do
  autoload -Uz "$(basename $fn)"
done

source "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "/usr/local/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "/usr/local/share/zsh-navigation-tools/zsh-navigation-tools.plugin.zsh"
source "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

source $ZDOTDIR/.aliasesrc

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
