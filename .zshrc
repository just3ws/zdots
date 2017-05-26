#!/usr/bin/env zsh

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR"
zstyle :compinstall filename "$ZDOTDIR/.zshrc"

# autoload -Uz compinit && compinit
autoload -U +X compinit && compinit

# http://zshwiki.org/home/config/prompt
autoload -U promptinit && promptinit

# http://zsh.sourceforge.net/Doc/Release/Options.html

# prompt
setopt prompt_subst # If  set, parameter expansion, command substitution and arithmetic expansion are performed in prompts.
setopt transient_rprompt # Remove  any  right prompt from display when accepting a command line.

# [ -d ./.git ] && git rev-parse --abbrev-ref HEAD

# history
setopt bang_hist # Enable '!' history expansion
setopt appendhistory # When exiting, append history entries to $HISTFILE, rather than replacing the old file; this is the default
setopt extended_history # Save additional info to $HISTFILE
setopt hist_ignore_space # If the commandline starts with a whitespace, don't add it to history
setopt inc_append_history # Append every single command to $HISTFILE immediately after hitting ENTER.
setopt share_history # Always import new commands from $HISTFILE (see 'inc_append_history' above)
# setopt hist_ignore_dups # Do not enter command lines into the history list if they are duplicates of the previous event.
setopt hist_ignore_all_dups # If a new command line being added to the history list duplicates an older one, the older command is removed from the list (even if it is not the previous event).
setopt hist_find_no_dups # When searching for history entries in the line editor, do not display dupli- cates of a line previously found, even if the duplicates are not contiguous.
setopt hist_reduce_blanks # Remove superfluous blanks from each command line being added to the history list.
setopt hist_save_no_dups # When writing out the history file, older commands that duplicate newer ones are omitted.
setopt hist_expire_dups_first # If the internal history needs to be trimmed to add the current command line, setting this option will cause the oldest history event that has a duplicate to be lost before losing a unique event from the list.
setopt hist_no_functions # Remove function definitions from the history list. Note that the function lingers in the internal history until the next command is entered before it vanishes, allowing you to briefly reuse or edit the definition.
setopt hist_verify # Whenever the user enters a line with history expansion, don't execute the line directly; instead, perform history expansion and reload the line into the editing buffer.
unsetopt hist_beep

# safety guards
setopt rm_star_wait # If querying the user before executing `rm *' or `rm  path/*',  first  wait  ten seconds  and  ignore  anything  typed in that time.  This avoids the problem of reflexively answering `yes' to the query when one didn't really mean  it.
unsetopt rm_star_silent # Query the user before executing `rm *` or `rm path/*`

# chdir
setopt autocd # if a directoryname is entered like a command, and there is no command of that name; the 'cd' command is executed for that directory
setopt cdable_vars # if cd would fail, because the arg is not a dir, try to expand the argument as if it was called the ~expression way
setopt auto_pushd # make cd push the old directory to the dirstack
setopt pushd_ignore_dups #  Don't push multiple copies of the same directory onto the directory stack.
setopt pushd_to_home # make 'pushd' with no argument, act like pushd ${HOME}
setopt pushd_minus # Exchanges  the  meanings  of  `+'  and `-' when used with a number to specify a directory in the stack.
setopt pushd_silent # Do not print the directory stack after pushd or popd.
setopt chase_links  # Resolve symbolic links to their true values when changing directory.

DIRSTACKSIZE=9
[ -f "$ZDOTDIR/.zdirs" ] || touch "$ZDOTDIR/.zdirs"
DIRSTACKFILE="$ZDOTDIR/.zdirs"

# completion
setopt complete_aliases # don't expand aliases _before_ completion has finished
setopt complete_in_word # if unset the cursor is set to the end of the word if completion is started
setopt glob_complete # cycle through globbing matches like menu_complete
setopt always_to_end # If a completion is performed with the cursor within a word, and a full completion is inserted, the cursor is moved to the end of the word. That is, the cursor is moved to the end of the word if either a single match is inserted or menu completion is performed.
setopt auto_menu # Automatically use menu completion after the second consecutive request for completion, for example by pressing the tab key repeatedly.

# expansion and globbing
setopt bad_pattern # if a pattern or glob is badly formed, print out an error
setopt extendedglob # globbing++
setopt glob_dots # don't require a leading dot for matching "hidden" files

# scripting
setopt multios # enable multiple redirections: uptime > uptime0.txt > uptime1.txt

# I/O
setopt clobber # allow '>' to truncate, and '»' to create files
setopt correct # try to correct the spelling of commands.
setopt short_loops # allow short form loops: `for file in *.pdf; lp ${file}`

# job control
setopt auto_resume # if you've got a simple command suspened, say 'mutt', and you forgot that you have already got a mutt running and try to start another mutt, the old running mutt is resumed, rather than starting a new process
setopt bg_nice # run background jobs at lower priority
setopt hup # send SIGHUP to background processes on exit.
setopt check_jobs # report status of bg-jobs if exiting a shell with job control enabled

setopt nomatch
setopt notify

unsetopt beep # Be quiet, seriously. I'm usually wearing headphones.

alias -g ...='../..'

bindkey -v
set -o vi

# Use C-x C-e to edit the current command line
autoload -U edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line

# # Emacs style
zle -N edit-command-line
bindkey '^xe' edit-command-line
bindkey '^x^e' edit-command-line
# Vi style:
zle -N edit-command-line
zle -N beep
bindkey -M vicmd v edit-command-line

bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^B' backward-char
bindkey -M viins '^D' delete-char-or-list
bindkey -M viins '^E' end-of-line
bindkey -M viins '^F' forward-char
bindkey -M viins '^K' kill-line
bindkey -M viins '^N' down-line-or-history
bindkey -M viins '^P' up-line-or-history
bindkey -M viins '^R' history-incremental-search-backward
bindkey -M viins '^S' history-incremental-search-forward
bindkey -M viins '^T' transpose-chars
bindkey -M viins '^Y' yank

fpath=(
  /usr/local/share/zsh-completions
  /usr/local/share/zsh/site-functions
  $fpath
)

source "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "/usr/local/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "/usr/local/share/zsh-navigation-tools/zsh-navigation-tools.plugin.zsh"
source "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# hash -d vim=~/dotfiles/vim
# hash -d zsh=~/dotfiles/zsh
hash -d api=~/wmx/bp/v2
hash -d assets=~/wmx/bp/assets
hash -d bp=~/wmx/bp
hash -d course-publisher=~/wmx/bp/course-publisher
hash -d dotfiles=~/dotfiles
hash -d instructor-dashboard=~/wmx/bp/instructor-dashboard
hash -d marketing-admin=~/wmx/bp/marketing-admin
hash -d marketing=~/wmx/bp/marketing
hash -d reporting-api=~/wmx/bp/reporting-api
hash -d s3=~/wmx/s3
hash -d src=~/src
hash -d sso=~/wmx/bp/sso
hash -d teachers=~/wmx/bp/teachers
hash -d tenant-dashboard=~/wmx/bp/tenant-dashboard
hash -d user-manager=~/wmx/bp/user-manager
hash -d web=~/wmx/bp/webapp
hash -d wikis=~/wmx/wikis
hash -d wmx=~/wmx
hash -d download=~/Downloads
hash -d pictures=~/Pictures
hash -d documents=~/Documents
hash -d dbx=~/Dropbox/mike

archive-wmx () rsync --archive --progress /Users/mike/wmx/ /Users/mike/Dropbox/.archives/wmx
archive-just3ws () rsync --archive --progress /Users/mike/just3ws/ /Users/mike/Dropbox/.archives/just3ws
archive-src () rsync --archive --progress /Users/mike/src/ /Users/mike/Dropbox/.archives/src
archive-dotfiles () rsync --archive --progress /Users/mike/dotfiles/ /Users/mike/Dropbox/.archives/dotfiles

if [[ "$PATH" != */opt/nginx/sbin* ]]
then
 export PATH="/opt/nginx/sbin:$PATH"
fi

fpath=($ZDOTDIR/Completion $fpath)

reload! ()
{
  local cache=$ZSH_CACHE_DIR
  autoload -U compinit zrecompile
  compinit -d "$cache/zcomp-$HOST"

  for f in "$ZDOTDIR/.zshrc" "$cache/zcomp-$HOST"
  do
    zrecompile -p $f && command rm -f $f.zwc.old
  done

  source "$ZDOTDIR/.zshrc"
}

clear! () { printf '\33c\e[3J' }

zman () {
 PAGER="less -g -s '+/^       "$1"'" man zshall
}

# function trace-vim () { rm -f ~/.vim-trace ; vim --startuptime ~/.vim-trace }

# alias -s js=vim
alias -s coffee=vim
alias -s css=vim
alias -s erb=vim
alias -s haml=vim
alias -s html=vim
alias -s markdown=vim
alias -s md=vim
# alias -s rb=vim
alias -s ru=vim
alias -s txt=mvim
alias -s vim=vim

alias be=" nocorrect bundle exec"
alias bundle=" bundle"
alias cd=" cd"
alias clear=" clear"
alias e="$EDITOR"

# git
alias g=" git"
# git pull
alias gpr="git pull --rebase --autostash"
# git commit
alias gc=" git commit --verbose"
alias gca=" git commit --verbose --amend"
# git add
alias ga=" git add"
alias gaa="  git add --all"
alias gapa=" git add --patch"
# git branch
alias gb=" git branch"
# --all List both remote-tracking branches and local branches.
alias gba=" git branch --all"
# git clone
alias gcl=" git clone"
# git fetch
alias gfa=" git fetch --all --prune"
# git status
alias gss=" git status --short"
# git diff
alias gwd=" git diff --word-diff"
# git checkout
alias gco=" git checkout"
# -b create and checkout a new branch
alias gcb=" git checkout -b"
alias branch\?="git rev-parse --abbrev-ref HEAD"

alias mkdir=" mkdir"
alias mv="nocorrect mv"
alias rm=" rm"
alias rspec="nocorrect rspec"
alias rvm=" rvm"
alias source=" source"
alias v="$EDITOR"
alias ved=" vim ~/.config/nvim/init.vim"
alias zed=" vim -O $ZDOTDIR/.zshrc $ZDOTDIR/.zshenv"
# exit
alias exit=" exit"
alias xxx=" exit"
alias ext="exit"

# ls
# ls
# -A List all entries except for . and ...
# -G Enable colorized output.  This option is equivalent to defining CLICOLOR in the environment.
# -p Write a slash (`/') after each filename if that file is a directory.
# -B Force printing of non-printable characters (as defined by ctype(3) and current locale settings) in file names as \xxx, where xxx is the numeric value of the character in octal.
alias ls=" ls -G -p"
alias l="ls"
# -C  Force multi-column output; this is the default when output is to a terminal.
alias la=" ls -A -C"
# -o List in long format, but omit the group id.
alias ll=" ls -A -o -h"

# dirs
# -v number the directories in the stack when printing.
# -l print directory names in full instead of using of using ~ expressions
alias dh='dirs -v -l'

alias bls=" brew services list"
alias bstart=" brew services start"
alias bstop=" brew services stop"
