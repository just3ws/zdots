# vim:set filetype=zsh expandtab shiftwidth=2 textwidth=64:

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

source "$HOME/.rvm/scripts/rvm"

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

if [[ "$PROFILE_STARTUP" == true ]]; then
  unsetopt xtrace
  exec 2>&3 3>&-
fi
