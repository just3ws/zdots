# aliases.zsh — Zsh-Specific Aliases and Functions

# Global Aliases (expand anywhere in the command line)
alias -g G='| grep'
alias -g GI='| grep -i'
alias -g L='| less'
alias -g H='| head'
alias -g T='| tail'
alias -g W='| wc -l'
alias -g S='| sort'
alias -g U='| uniq'
alias -g Y='| pbcopy'
alias -g X='| xargs'
alias -g J='| jq'

# Named Directories (Hash)
hash -d desk="$HOME/Desktop"
hash -d xdots="$HOME/.config"
hash -d zdots="$ZDOTDIR"
hash -d projects="$HOME/projects"

# Directory Aliases (Zsh-friendly)
alias projects='nocorrect ~projects'
alias desk='nocorrect ~desk'
alias xdots='nocorrect ~xdots'
alias zdots='nocorrect ~zdots'

# Modern DSL Patterns (Zsh-specific fpath)
alias fpath='echo $fpath | tr " " "\n"'

# Zsh-only CLI tools
alias he='history_enquire'
alias bounce='reload'

# Zsh Globbing shorthands
alias prunedirs='rm -d **/*(/^F)'
