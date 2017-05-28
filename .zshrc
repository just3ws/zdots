# vim:set filetype=zsh expandtab shiftwidth=2 textwidth=64:

autoload -Uz compinit && compinit
autoload -Uz colors && colors
autoload -Uz promptinit && promptinit
autoload -Uz regexp-replace
autoload -Uz edit-command-line

for fn in $ZDOTDIR/functions/*(x)
do
  func_def="$(basename $fn)"
  autoload -Uz "$func_def"
  func="${func_def%.*}"
  alias $func=$func_def
done

zstyle ":completion:*" cache-path "$ZSH_CACHE_DIR"
zstyle :compinstall filename "$ZDOTDIR/.zshrc"

for z in $ZDOTDIR/settings/*.zsh
do
  source "$z"
done

# Vi all the things!
bindkey -v
set -o vi

# Use C-x C-e to edit the current command line
zle -N edit-command-line
bindkey "\C-x\C-e" edit-command-line

# Emacs style
zle -N edit-command-line
bindkey "^xe" edit-command-line
bindkey "^x^e" edit-command-line

# Vi style:
zle -N edit-command-line
zle -N beep
bindkey -M vicmd v edit-command-line

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

fpath=(
  $ZDOTDIR/functions
  $ZDOTDIR/Completion
  /usr/local/share/zsh-completions
  /usr/local/share/zsh/site-functions
  $fpath
)

source "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "/usr/local/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "/usr/local/share/zsh-navigation-tools/zsh-navigation-tools.plugin.zsh"
source "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

source "$HOME/.rvm/scripts/rvm"

#     
PROMPT="%0~  "
source "$ZDOTDIR/plugins/iTerm2/shell_integration.zsh"

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
