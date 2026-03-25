# .bashrc — AI-Friendly Bash Bridge for Zdots
# Provides consistent environment and agent-API for Bash sessions.

# 1. Source POSIX-compatible core environment
if [[ -f "$HOME/.config/zsh/env.sh" ]]; then
  source "$HOME/.config/zsh/env.sh"
fi

# 2. RTK Priming (Bash compatibility)
if command -v rtk >/dev/null 2>&1; then
  alias git='rtk git'
  alias pnpm='rtk pnpm'
fi

# 3. Source Unified Aliases
if [[ -f "$HOME/.config/zsh/.aliasrc" ]]; then
  source "$HOME/.config/zsh/.aliasrc"
fi

# 4. Prompt (High-signal, minimal)
PS1='\[\e[32m\]\u@\h\[\e[m\]:\[\e[34m\]\w\[\e[m\]\$ '

# 5. Capabilities discovery
alias capabilities='capabilities --json'
