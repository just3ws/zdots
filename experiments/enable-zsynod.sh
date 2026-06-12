#!/bin/bash
# experiments/enable-zsynod.sh — Enable zsynod in the current session
#
# Usage:
#   source experiments/enable-zsynod.sh              # From zdots root
#   source ~/.config/zsh/experiments/enable-zsynod.sh  # From anywhere
#
# What it does:
#   - Sets ZSYNOD_DIR to point to experiments/zsynod/
#   - Adds experiments/zsynod/bin/ to PATH (zsynod command)
#   - Sources zsynod completion and utilities
#   - Initializes zsynod if first-time setup is needed

set -euo pipefail

# Find ZDOTDIR (the zdots repository root)
if [[ -n "${ZDOTDIR:-}" ]]; then
  ZSYNOD_ROOT="$ZDOTDIR"
elif [[ -n "${ZSH_VERSION:-}" ]] && [[ -n "${ZSH_NAME:-}" ]]; then
  # Zsh: use the location of this script's parent
  ZSYNOD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
  # Fallback for non-Zsh shells
  ZSYNOD_ROOT="$HOME/.config/zsh"
fi

ZSYNOD_DIR="${ZSYNOD_ROOT}/experiments/zsynod"

# Validate zsynod exists
if [[ ! -d "$ZSYNOD_DIR" ]]; then
  printf 'error: zsynod not found at %s\n' "$ZSYNOD_DIR" >&2
  return 1 2>/dev/null || exit 1
fi

# Export ZSYNOD_DIR so zsynod commands can find their data
export ZSYNOD_DIR

# Add zsynod bin to PATH (prepend so `zsynod` resolves here)
if [[ ":$PATH:" != *":${ZSYNOD_DIR}/bin:"* ]]; then
  export PATH="${ZSYNOD_DIR}/bin:${PATH}"
fi

# Load zsynod completion and lazy functions if they exist
if [[ -f "${ZSYNOD_DIR}/functions/_zsynod" ]]; then
  # Source completion function (Zsh only)
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    source "${ZSYNOD_DIR}/functions/_zsynod"
  fi
fi

# Initialize zsynod on first run (create ledger, members, etc. if missing)
if [[ ! -f "${ZSYNOD_DIR}/ledger.jsonl" ]]; then
  printf 'Initializing zsynod (first time setup)...\n' >&2
  if command -v zsynod >/dev/null 2>&1; then
    zsynod init 2>/dev/null || printf 'note: zsynod init had warnings (harmless)\n' >&2
  fi
fi

printf 'zsynod enabled (ZSYNOD_DIR=%s)\n' "$ZSYNOD_DIR" >&2
printf 'Run: zsynod --help\n' >&2
