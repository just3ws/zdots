# Dracula Pro (Default) Theme for zsh-syntax-highlighting
# Values derived from Dracula Pro palette.md

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main cursor)
typeset -gA ZSH_HIGHLIGHT_STYLES

# Core Palette
# Foreground: #F8F8F2
# Background: #22212C
# Selection:  #454158
# Comment:    #7970A9
# Cyan:       #80FFEA
# Green:      #8AFF80
# Orange:     #FFCA80
# Pink:       #FF80BF
# Purple:     #9580FF
# Red:        #FF9580
# Yellow:     #FFFF80

## Comments
ZSH_HIGHLIGHT_STYLES[comment]='fg=#7970A9'

## Functions/methods
ZSH_HIGHLIGHT_STYLES[alias]='fg=#8AFF80'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#8AFF80'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#8AFF80'
ZSH_HIGHLIGHT_STYLES[function]='fg=#8AFF80'
ZSH_HIGHLIGHT_STYLES[command]='fg=#8AFF80'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#8AFF80,italic'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#FFCA80,italic'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#FFCA80'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#FFCA80'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#9580FF'

## Built ins
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#80FFEA'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#80FFEA'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#80FFEA'

## Punctuation
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#FF80BF'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#FF80BF'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#FF80BF'
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#FF80BF'

## Strings
ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#FFFF80'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#FFFF80'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#FFFF80'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#FF9580'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#FFFF80'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#FF9580'
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#FFFF80'

## Variables
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#FF9580'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#F8F8F2'

## Miscellaneous
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#FF9580'
ZSH_HIGHLIGHT_STYLES[path]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#FF80BF'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#FF80BF'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#9580FF'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#FF9580'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[default]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[cursor]='standout'

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#7970A9'
