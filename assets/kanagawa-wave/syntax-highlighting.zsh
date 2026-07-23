# Kanagawa Wave (Default) Theme for zsh-syntax-highlighting
# Values derived from rebelot/kanagawa.nvim wave palette.

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main cursor)
typeset -gA ZSH_HIGHLIGHT_STYLES

# Core Palette (Kanagawa Wave)
# Foreground:  #DCD7BA (fujiWhite)
# Background:  #1A1B2F (sumiInk3, platform-tuned bluer)
# Selection:   #2D4F67 (waveBlue2)
# Comment:     #727169 (fujiGray)
# Aqua/Cyan:   #7AA89F (waveAqua2)
# Green:       #98BB6C (springGreen)
# Yellow:      #E6C384 (carpYellow)
# Orange:      #FFA066 (surimiOrange)
# Pink:        #D27E99 (sakuraPink)
# Violet:      #957FB8 (oniViolet)
# Blue:        #7E9CD8 (crystalBlue)
# Red:         #FF5D62 (peachRed)

## Comments
ZSH_HIGHLIGHT_STYLES[comment]='fg=#727169'

## Functions/methods
ZSH_HIGHLIGHT_STYLES[alias]='fg=#98BB6C'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#98BB6C'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#98BB6C'
ZSH_HIGHLIGHT_STYLES[function]='fg=#98BB6C'
ZSH_HIGHLIGHT_STYLES[command]='fg=#98BB6C'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#98BB6C,italic'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#FFA066,italic'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#FFA066'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#FFA066'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#957FB8'

## Built ins
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#7AA89F'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#7AA89F'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#7AA89F'

## Punctuation
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#D27E99'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#D27E99'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#D27E99'
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#D27E99'

## Strings
ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#E6C384'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#E6C384'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#E6C384'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#FF5D62'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#E6C384'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#FF5D62'
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#E6C384'

## Variables
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#FF5D62'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#DCD7BA'

## Miscellaneous
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#FF5D62'
ZSH_HIGHLIGHT_STYLES[path]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#D27E99'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#D27E99'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#957FB8'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#FF5D62'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[default]='fg=#DCD7BA'
ZSH_HIGHLIGHT_STYLES[cursor]='standout'

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#54546D'
