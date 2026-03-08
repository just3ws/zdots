# Initialize mise when available.
# This should be loaded late (after Homebrew/pnpm) to ensure mise-managed tools
# take precedence over system versions.
if [[ -x /opt/homebrew/bin/mise ]]; then
  eval "$(/opt/homebrew/bin/mise activate zsh)"
  export MISE_NODE_COREPACK=1
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
  export MISE_NODE_COREPACK=1
fi
