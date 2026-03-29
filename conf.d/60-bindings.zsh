if [[ -o interactive && -o zle ]]; then
  bindkey '^P' up-line-or-history
  bindkey '^N' down-line-or-history

  # Enable Ctrl-x-e to edit command line
  autoload -Uz edit-command-line
  zle -N edit-command-line

  bindkey '^xe' edit-command-line
  bindkey '^x^e' edit-command-line
  bindkey -M vicmd v edit-command-line
fi
