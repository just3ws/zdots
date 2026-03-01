# Setup fzf
# ---------
if [[ ! "$PATH" == *$HOMEBREW_PREFIX/opt/fzf/bin* && -d "$HOMEBREW_PREFIX/opt/fzf/bin" ]]; then
  export PATH="${PATH:+${PATH}:}$HOMEBREW_PREFIX/opt/fzf/bin"
fi

# Auto-completion
# ---------------
if [[ $- == *i* && -r "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
  source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" 2> /dev/null
fi

# Key bindings
# ------------
if [[ -r "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]]; then
  source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
fi

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git .'
elif command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden -g "!.git"'
else
  export FZF_DEFAULT_COMMAND='find . -type f'
fi

if command -v tree >/dev/null 2>&1; then
  export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
else
  export FZF_ALT_C_OPTS="--preview 'ls -la {}'"
fi
