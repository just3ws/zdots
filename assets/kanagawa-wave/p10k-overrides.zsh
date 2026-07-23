# assets/kanagawa-wave/p10k-overrides.zsh
# User-owned Powerlevel10k color overrides, loaded AFTER the base .p10k.zsh.
# Colors are ANSI palette indices (0-15) so they follow the terminal's Kanagawa
# Wave palette — same source of truth as the iTerm preset and CC's dark-ansi.
# (Ported from the retired Dracula overrides; the three 256-cube values there —
# 255/84/196 — are swapped to ANSI 15/10/9 so they too track the palette.)

# OS Icon
typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=15

# Prompt Character (Success/Error colors)
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=10
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=9

# Directory Colors
typeset -g POWERLEVEL9K_DIR_FOREGROUND=0
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=0
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=0

# Status Colors
typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND=2
typeset -g POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND=2
typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=3
typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=3
typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=3

# Kubecontext Colors
typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_FOREGROUND=7
typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_BACKGROUND=5

# Command Execution Time
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=0

# AI/Runtime Environments (Mise/ASDF)
typeset -g POWERLEVEL9K_ASDF_FOREGROUND=0
typeset -g POWERLEVEL9K_DIRENV_FOREGROUND=3
