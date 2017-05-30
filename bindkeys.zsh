# Use Vi
bindkey -v

# ZLE Emacs style
bindkey "\C-x\C-e" edit-command-line

# ZLE Vi style
bindkey -M vicmd v edit-command-line

# Emacs key chords in Vi style
bindkey -M viins "^A" beginning-of-line
bindkey -M viins "^B" backward-char
bindkey -M viins "^D" delete-char-or-list
bindkey -M viins "^E" end-of-line
bindkey -M viins "^F" forward-char
bindkey -M viins "^K" kill-line
bindkey -M viins "^N" down-line-or-history
bindkey -M viins "^P" up-line-or-history
bindkey -M viins "^R" history-incremental-search-backward
bindkey -M viins "^S" history-incremental-search-forward
bindkey -M viins "^T" transpose-chars
bindkey -M viins "^Y" yank
