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

# Modern DSL Patterns
alias path='echo $PATH | tr ":" "\n"'
alias fpath='echo $fpath | tr " " "\n"'

# Zsh-only CLI tools
alias he='history_enquire'
alias bounce='reload'

# Project-specific shorthands (active only in phalanxduel)
if [[ -f fly.staging.toml ]]; then
  alias fds='fly deploy --app phalanxduel-staging --config fly.staging.toml'
fi
if [[ -f fly.production.toml ]]; then
  alias fdp='fly deploy --app phalanxduel-production --config fly.production.toml'
fi

# Zsh Globbing shorthands
alias prunedirs='rm -d **/*(/^F)'
