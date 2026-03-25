# .bashrc — AI-Friendly Bash Bridge for Zdots
# Provides consistent environment and agent-API for Bash sessions.

# 1. Environment & Paths (Mirror Zsh setup)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Ensure zdots bin is available
case ":$PATH:" in
  *":$ZDOTDIR/bin:"*) ;;
  *) export PATH="$ZDOTDIR/bin:$PATH" ;;
esac

# 2. RTK Priming (Bash compatibility)
if command -v rtk >/dev/null 2>&1; then
  # Basic RTK bash integration
  alias git='rtk git'
  alias pnpm='rtk pnpm'
fi

# 3. Source Unified Aliases
if [[ -f "$ZDOTDIR/.aliasrc" ]]; then
  source "$ZDOTDIR/.aliasrc"
fi

# 4. Prompt (High-signal, minimal)
PS1='\[\e[32m\]\u@\h\[\e[m\]:\[\e[34m\]\w\[\e[m\]\$ '

# 5. Capabilities discovery
alias capabilities='capabilities --json'
