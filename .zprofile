# Unified Homebrew and Mise initialization with caching.
# Sourcing these from conf.d ensures they use the same robust caching logic
# regardless of whether the shell is login, interactive, or both.
: "${ZDOTDIR:=$HOME/.config/zsh}"
[[ -r "$ZDOTDIR/conf.d/10-homebrew.zsh" ]] && source "$ZDOTDIR/conf.d/10-homebrew.zsh"
[[ -r "$ZDOTDIR/conf.d/90-mise.zsh" ]] && source "$ZDOTDIR/conf.d/90-mise.zsh"

# Re-run path construction to override macOS path_helper (from /etc/zprofile)
# which reorders the PATH and breaks precedence for Mise shims.
if [[ -r "$ZDOTDIR/env.sh" ]]; then
  # We source env.sh again, but it's idempotent for vars.
  # The path construction part will re-prepend our preferred paths.
  source "$ZDOTDIR/env.sh"
fi
