# aliases.bash — Common Aliases and Functions (Bash & Zsh compatible)

# Ruby
alias be="bundle exec"

# Editors
# shellcheck disable=SC2139
alias vim="$EDITOR"
# shellcheck disable=SC2139
alias vi="$EDITOR"
alias vm='vim'

# Modern CLI Tools Fallbacks/Aliases
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -alh --icons --git --group-directories-first'
  alias la='eza -la --icons --git --group-directories-first'
  alias tree='eza --tree --icons'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  alias preview='bat'
fi

if command -v tldr >/dev/null 2>&1; then
  alias tldr='tldr --color always'
fi

if command -v lazygit >/dev/null 2>&1; then alias lg='lazygit'; fi
if command -v btm >/dev/null 2>&1; then alias top='btm'; alias htop='btm'; fi
# `bench` intentionally unaliased — bin/bench owns the Zdots Startup Benchmark.

# Navigation & UI
# k reassigned to kubectl (k8s native ergonomics, conf.d/71-shell-tools.zsh); use Ctrl-L / `clear` to clear.
# alias k='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git Shorthands
# `gs` intentionally unaliased — ghostscript (Brewfile) owns the `gs` binary.
# Use `gss` for `git status --short`.
alias gss='git status --short'
alias gba='git branch --all'
alias gco='git checkout'
alias gfa='git fetch --all --prune'
alias gwd='git diff --word-diff'
alias gup='git pull --rebase'
alias gpfl='git push --force-with-lease'
alias gra='git remote add'
alias grv='git remote -v'
alias gcam='git commit -am'
alias gcm='git commit -m'
alias wip='git commit -am "WIP"'

# Service & App Shorthands
if command -v brew >/dev/null 2>&1; then
  alias bsl='brew services list'
  alias bso='brew services stop'
  alias bsr='brew services restart'
  alias bss='brew services start'
  alias brew-nuke='brew uninstall --cask --zap --force'
fi

if command -v pnpm >/dev/null 2>&1; then
  alias p='pnpm'
  alias px='pnpm dlx'
  # `pr`, `ps`, `pv` intentionally unaliased — system/Homebrew own `pr`, `ps`, `pv`.
  alias prun='pnpm run'
  alias pinstall='pnpm install'
  alias pstart='pnpm start'
  alias pt='pnpm test'
  alias pverify='pnpm verify:all'
fi

if command -v docker >/dev/null 2>&1; then
  alias dps='docker ps'
  alias dpa='docker ps -a'
  alias di='docker images'
  alias dlf='docker logs -f'
  alias dcup='docker compose up --force-recreate --remove-orphans --detach'
  alias dcdown='docker compose down'
fi

if command -v fly >/dev/null 2>&1; then
  alias fl='fly logs'
  # `fd` intentionally unaliased — fd (fd-find) owns the `fd` binary.
  alias flyd='fly deploy'
  alias fs='fly status'
  # Project-specific shorthands (active only in phalanxduel)
  if [ -f fly.staging.toml ]; then
    alias fds='fly deploy --app phalanxduel-staging --config fly.staging.toml'
  fi
  if [ -f fly.production.toml ]; then
    alias fdp='fly deploy --app phalanxduel-production --config fly.production.toml'
  fi
fi

# AI Workflow
if command -v gemini >/dev/null 2>&1; then alias gm='gemini-invoke gemini'; fi

# Colima / Docker storage hygiene (256GB primary — prune aggressively)
if command -v colima >/dev/null 2>&1; then
  # `colima-status` and `docker-reclaim` are provided by bin/ on PATH — do not shadow them.
  # Disk summary: show what Docker is consuming inside the Colima VM
  alias docker-df='docker system df'
fi

# Modern DSL Patterns
alias path='echo $PATH | tr ":" "\n"'

# Imperial calendar — the Astronomicon date converter (bin/imperial-date).
#   idate              today's Imperial date (e.g. 0452026.M3)
#   idate 2026-06-14   convert a Gregorian date
#   idate --decode 0452026.M3   decode back to Gregorian (±1d)
alias idate='imperial-date'

# Recipes (bin/ztranscribe is on PATH as a symlink to recipes/yt-transcribe).
#   ztranscribe <url> | --from-wav <wav> --output-base <base>   (man yt-transcribe)

# Utility Functions
ff() { find "${2:-.}" -type f -iname "*$1*"; }

unquarantine() { xattr -dr com.apple.quarantine "$@"; }

screenshots() {
  local dest="$HOME/Pictures/Screenshots"
  mkdir -p "$dest"
  mv "$HOME/Desktop"/Screenshot* "$dest/" 2>/dev/null
  mv "$HOME/Desktop"/Screen\ Shot* "$dest/" 2>/dev/null
  echo "Screenshots moved to $dest"
}
