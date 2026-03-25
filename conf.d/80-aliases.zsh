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

# Navigation & UI
alias k='klear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# pnpm
if command -v pnpm >/dev/null 2>&1; then
  alias p='pnpm'
  alias px='pnpm dlx'
  alias pr='pnpm run'
  alias pi='pnpm install'
  alias ps='pnpm start'
  alias pt='pnpm test'
  alias pv='pnpm verify:all'
fi

# Fly.io
if command -v fly >/dev/null 2>&1; then
  alias fl='fly logs'
  alias fd='fly deploy'
  alias fs='fly status'
  # Project-specific shorthands (active only in phalanxduel)
  [[ -f fly.staging.toml ]] && alias fds='fly deploy --app phalanxduel-staging --config fly.staging.toml'
  [[ -f fly.production.toml ]] && alias fdp='fly deploy --app phalanxduel-production --config fly.production.toml'
fi

# Git Workflow
alias gup='git pull --rebase'
alias gpfl='git push --force-with-lease'
alias gra='git remote add'
alias grv='git remote -v'

# AI Workflow
command -v claude >/dev/null 2>&1 && alias cl='claude'
command -v gemini >/dev/null 2>&1 && alias gm='gemini'

# Modern CLI Tools
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'
command -v btm >/dev/null 2>&1 && alias top='btm' && alias htop='btm'
command -v hyperfine >/dev/null 2>&1 && alias bench='hyperfine'
