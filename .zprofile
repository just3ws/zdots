# Unified Homebrew and Mise initialization with caching.
# Sourcing these from conf.d ensures they use the same robust caching logic
# regardless of whether the shell is login, interactive, or both.
source "$ZDOTDIR/conf.d/10-homebrew.zsh"
source "$ZDOTDIR/conf.d/90-mise.zsh"
