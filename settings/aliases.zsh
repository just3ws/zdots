# vim:set filetype=zsh expandtab shiftwidth=2:

alias vvv=" vim ~/.config/nvim/init.vim"
alias zzz=" vim -O $ZDOTDIR/.zshrc $ZDOTDIR/.zshenv"
alias mvim=gvim

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
# alias clear=" clear"

# git
alias g=" git"
# git pull
alias gpr="git pull --rebase --autostash"
# git commit
alias gc=" git commit --verbose"
alias gca=" git commit --verbose --amend"
# git add
alias ga=" git add"
alias gaa=" git add --all"
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
# exit
alias exit=" exit"
alias xxx=" exit"
alias ext="exit"

# ls
# -A List all entries except for . and ...
# -G Enable colorized output. This option is equivalent to defining CLICOLOR in the environment.
# -p Write a slash (`/') after each filename if that file is a directory.
# -B Force printing of non-printable characters (as defined by ctype(3) and current locale settings) in file names as \xxx, where xxx is the numeric value of the character in octal.
alias ls=" ls -G -p"
alias l="ls"
# -C Force multi-column output; this is the default when output is to a terminal.
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

alias -g ...='../..'
