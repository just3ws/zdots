# Kanagawa Lotus (Default) Theme for zsh-syntax-highlighting
# Values derived from rebelot/kanagawa.nvim wave palette.

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main cursor)
typeset -gA ZSH_HIGHLIGHT_STYLES

# Core Palette (Kanagawa Lotus)
# Foreground:  #545464 (fujiWhite)
# Background:  #F2ECBC (sumiInk3, platform-tuned bluer)
# Selection:   #B5CBD2 (waveBlue2)
# Comment:     #8A8980 (fujiGray)
# Aqua/Cyan:   #5E857A (waveAqua2)
# Green:       #6F894E (springGreen)
# Yellow:      #77713F (carpYellow)
# Orange:      #CC6D00 (surimiOrange)
# Pink:        #B35B79 (sakuraPink)
# Violet:      #624C83 (oniViolet)
# Blue:        #4D699B (crystalBlue)
# Red:         #D7474B (peachRed)

## Comments
ZSH_HIGHLIGHT_STYLES[comment]='fg=#8A8980'

## Functions/methods
ZSH_HIGHLIGHT_STYLES[alias]='fg=#6F894E'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#6F894E'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#6F894E'
ZSH_HIGHLIGHT_STYLES[function]='fg=#6F894E'
ZSH_HIGHLIGHT_STYLES[command]='fg=#6F894E'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#6F894E,italic'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#CC6D00,italic'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#CC6D00'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#CC6D00'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#624C83'

## Built ins
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#5E857A'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#5E857A'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#5E857A'

## Punctuation
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#B35B79'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#B35B79'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#B35B79'
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#B35B79'

## Strings
ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#77713F'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#77713F'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#77713F'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#D7474B'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#77713F'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#D7474B'
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#77713F'

## Variables
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#D7474B'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#545464'

## Miscellaneous
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#D7474B'
ZSH_HIGHLIGHT_STYLES[path]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#B35B79'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#B35B79'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#624C83'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#D7474B'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[default]='fg=#545464'
ZSH_HIGHLIGHT_STYLES[cursor]='standout'

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#A09CAC'
