# Nord Styles for zsh-syntax-highlighting
# Based on Nord color palette
typeset -gA ZSH_HIGHLIGHT_STYLES

# Main highlighter styles
ZSH_HIGHLIGHT_STYLES[command]='fg=#88C0D0'              # nord8
ZSH_HIGHLIGHT_STYLES[alias]='fg=#88C0D0'                # nord8
ZSH_HIGHLIGHT_STYLES[function]='fg=#88C0D0'             # nord8
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#88C0D0'              # nord8
ZSH_HIGHLIGHT_STYLES[keyword]='fg=#81A1C1'              # nord9
ZSH_HIGHLIGHT_STYLES[string]='fg=#EBCB8B'               # nord13
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#A3BE8C' # nord14
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#A3BE8C' # nord14
ZSH_HIGHLIGHT_STYLES[path]='fg=#D8DEE9'                # nord4
ZSH_HIGHLIGHT_STYLES[comment]='fg=#4C566A,bold'        # nord3
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#BF616A'         # nord11

# Brackets
ZSH_HIGHLIGHT_STYLES[bracket-level-1]='fg=#81A1C1'
ZSH_HIGHLIGHT_STYLES[bracket-level-2]='fg=#88C0D0'
ZSH_HIGHLIGHT_STYLES[bracket-level-3]='fg=#B48EAD'

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#4C566A'
