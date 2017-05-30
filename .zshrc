# vim:set filetype=zsh expandtab shiftwidth=2 textwidth=64:

autoload -Uz compinit ; compinit
autoload -Uz colors && colors
autoload -Uz promptinit && promptinit
autoload -Uz regexp-replace
autoload -Uz edit-command-line

# Vi all the things!
set -o vi

for z in $ZDOTDIR/*.zsh ; source "$z"

fpath=(
  $ZDOTDIR/functions
  $ZDOTDIR/Completion
  /usr/local/share/zsh-completions
  /usr/local/share/zsh/site-functions
  $fpath
)

for fn in $ZDOTDIR/functions/*(x) ; autoload -Uz "$( basename $fn )"

source "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "/usr/local/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
source "/usr/local/share/zsh-navigation-tools/zsh-navigation-tools.plugin.zsh"
source "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

source "$HOME/.rvm/scripts/rvm"

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
