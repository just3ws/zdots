# assets/kanagawa-lotus/p10k-overrides.zsh
# User-owned Powerlevel10k color overrides, loaded AFTER the base .p10k.zsh.
# Segment fills are ANSI palette indices, so they follow the terminal's Kanagawa
# Lotus palette. Lotus fills are mid-dark, so the text on them is the ground
# colour (lotusWhite3), where Wave uses ANSI 0.
() {
  local on_fill='#F2ECBC'

  # OS Icon
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=$on_fill

  # Prompt Character (Success/Error colors)
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=2
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=1

  # Vi mode
  typeset -g POWERLEVEL9K_VI_MODE_FOREGROUND=$on_fill

  # Directory Colors
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=$on_fill
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=$on_fill
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=$on_fill

  # Git status
  typeset -g POWERLEVEL9K_VCS_FOREGROUND=$on_fill

  # Status Colors
  typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND=10
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND=10
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=$on_fill
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=$on_fill
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=$on_fill

  # Kubecontext Colors
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_FOREGROUND=$on_fill
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_BACKGROUND=5

  # Command Execution Time
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=$on_fill

  # AI/Runtime Environments (Mise/ASDF)
  typeset -g POWERLEVEL9K_ASDF_FOREGROUND=$on_fill
  typeset -g POWERLEVEL9K_DIRENV_FOREGROUND=11
}
