if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export _ZDOTS_BREW_SHELLENV=1
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
  export _ZDOTS_BREW_SHELLENV=1
fi

# Login-only, non-interactive shells skip .zshrc, so activate mise here to keep
# Codex and similar `zsh -lc` callers on the expected runtime. Use full
# activation instead of `hook-env` so child login shells also re-normalize PATH
# correctly when they inherit an already-activated environment.
if [[ ! -o interactive ]]; then
  if [[ -x /opt/homebrew/bin/mise ]]; then
    eval "$(/opt/homebrew/bin/mise activate zsh)"
    export MISE_NODE_COREPACK=1
  elif command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
    export MISE_NODE_COREPACK=1
  fi
fi
