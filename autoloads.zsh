# vim:set filetype=zsh expandtab shiftwidth=2 textwidth=64:

autoload -Uz compinit ; compinit
autoload -Uz colors && colors
autoload -Uz promptinit && promptinit
autoload -Uz regexp-replace
autoload -Uz edit-command-line

for fn in $ZDOTDIR/functions/*(x) ; autoload -Uz "$( basename $fn )"

# zmv "programmable rename"
autoload -Uz zmv
