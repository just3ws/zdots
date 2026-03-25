# Global Aliases (expand anywhere in the command line)
# Allows for patterns like: cat file.txt G pattern
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

# Service & App Aliases
if command -v brew >/dev/null 2>&1; then
  alias bsl='brew services list'
  alias bso='brew services stop'
  alias bsr='brew services restart'
  alias bss='brew services start'
fi

if command -v docker >/dev/null 2>&1; then
  alias dps='docker ps'
  alias dpa='docker ps -a'
  alias di='docker images'
  alias dlf='docker logs -f'
fi

# Modern DSL-like patterns
alias help='tldr'
alias path='echo $PATH | tr ":" "\n"'
alias fpath='echo $fpath | tr " " "\n"'
