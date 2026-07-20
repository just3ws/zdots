# conf.d/71-shell-tools.zsh - command-line navigation and directory tools

if ! typeset -f zdefer >/dev/null 2>&1; then
  [[ -r "$ZDOTDIR/conf.d/70-shell-helpers.zsh" ]] && source "$ZDOTDIR/conf.d/70-shell-helpers.zsh"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v atuin >/dev/null 2>&1; then
  # Use --disable-up-arrow because history-substring-search owns arrows.
  zdefer eval "$(atuin init zsh --disable-up-arrow)"
fi

if command -v broot >/dev/null 2>&1; then
  source "$HOMEBREW_PREFIX/etc/bash_completion.d/broot" 2>/dev/null || true
  alias br='broot'
fi

# k8s native ergonomics (work-dev is the local app namespace)
if command -v kubectl >/dev/null 2>&1; then
  alias k=kubectl
  alias kgp='kubectl get pods'
  alias kdp='kubectl describe pod'
  alias kgs='kubectl get svc'
  source <(kubectl completion zsh) 2>/dev/null
fi
# default namespace for the session (no-op if kubens/ctx absent)
command -v kubens >/dev/null 2>&1 && kubens work-dev >/dev/null 2>&1 || true

return 0
