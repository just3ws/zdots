# Initialize full mise shell integration for interactive shells.
# Login-only, non-interactive shells get the same activation in `.zprofile`;
# this block still runs late so interactive sessions keep hooks and runtime
# precedence after other PATH edits.
if [[ -x /opt/homebrew/bin/mise ]]; then
  eval "$(/opt/homebrew/bin/mise activate zsh)"
  export MISE_NODE_COREPACK=1
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
  export MISE_NODE_COREPACK=1
fi
