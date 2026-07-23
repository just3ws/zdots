# vim:ft=zsh
# .zshenv — Zsh-specific environment entry point

# 0. Bootstrap Zdots — establish ZDOTDIR as the source-of-truth before anything
# reads it, so zsh resolves $ZDOTDIR/.zshrc rather than falling back to ~/.zshrc
# on a fresh login with no inherited ZDOTDIR. The :- default respects an
# intentional external override.
export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"

# 1. Source POSIX-compatible core environment
if [[ -r "${ZDOTDIR:-$HOME/.config/zsh}/env.sh" ]]; then
  source "${ZDOTDIR:-$HOME/.config/zsh}/env.sh"
fi

# 2. Zsh-specific Refinements (Arrays & Deduplication)
# Re-normalize path from POSIX string into Zsh array for manipulation
typeset -gU path fpath manpath
path=(
  ${path[@]}
)

fpath=(
  $ZDOTDIR/bin
  $ZDOTDIR/functions/enabled
  $fpath
)

# Zdots man pages (share/man/man1, maintained by /command-qc). The trailing
# empty element keeps the system's default man search path intact.
manpath=(
  $ZDOTDIR/share/man
  ${manpath[@]}
  ''
)

# 3. Zsh-specific overrides
export ALTERNATE_EDITOR="$EDITOR"
export BUNDLER_EDITOR="$EDITOR"
export GEM_EDITOR="$EDITOR"
export GIT_EDITOR="$EDITOR"
export PSQL_EDITOR="$EDITOR"
export SUDO_EDITOR="$EDITOR"

# Prefer 1Password SSH agent when available.
_1p_agent_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [[ -S "$_1p_agent_sock" ]]; then
  export SSH_AUTH_SOCK="$_1p_agent_sock"
fi
unset _1p_agent_sock

# Codex sandbox sessions cannot write under ~/.cache
if [[ -n "${CODEX_SANDBOX:-}" ]]; then
  export MISE_CACHE_DIR="${${TMPDIR:-/tmp}%/}/mise-cache"
fi

# Git identity configuration (XDG compliant)
: "${GIT_CONFIG_GLOBAL:=$XDG_CONFIG_HOME/git/config}"
export GIT_CONFIG_GLOBAL

# Machine-specific overrides (gitignored). Sourced last, at .zshenv time —
# before conf.d/compinit — so local fpath/completion additions take effect.
# Tools that self-install completions (e.g. sentry-cli) write here, not here-above.
[[ -r "${ZDOTDIR:-$HOME/.config/zsh}/.zshenv.local" ]] && source "${ZDOTDIR:-$HOME/.config/zsh}/.zshenv.local"
