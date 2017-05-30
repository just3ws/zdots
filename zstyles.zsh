zstyle ":completion:*" cache-path "$ZSH_CACHE_DIR"
zstyle :compinstall filename "$ZDOTDIR/.zshrc"

# Colorful autocompletion for `cd` command
zmodload -i zsh/complist

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Case-insensitive completion for `cd` etc *N*
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
