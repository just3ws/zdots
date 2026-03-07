# Initialize mise when available.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
  export MISE_NODE_COREPACK=1
fi
