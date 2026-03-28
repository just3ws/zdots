# zsh-defer: Lazy-load heavy integrations to improve startup time.
if [[ -r "$ZDOTDIR/functions/enabled/zsh-defer.plugin.zsh" ]]; then
  source "$ZDOTDIR/functions/enabled/zsh-defer.plugin.zsh"
fi

# Define a helper for deferring when available, otherwise source immediately.
zdefer() {
  if (( $+functions[zsh-defer] )); then
    zsh-defer "$@"
  else
    "$@"
  fi
}

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v atuin >/dev/null 2>&1; then
  # Use --disable-up-arrow if you prefer zsh-history-substring-search for up-arrow
  zdefer eval "$(atuin init zsh --disable-up-arrow)"
fi

if command -v broot >/dev/null 2>&1; then
  source "$HOMEBREW_PREFIX/etc/bash_completion.d/broot" 2>/dev/null || true
  alias br='broot'
fi

# AI Pattern Pipe: Pipe any output into local AI for inference/parsing.
# Usage: cat log.txt | ai "Find all unique error codes"
ai() {
  if [[ -z "$1" ]]; then
    echo "Usage: <output> | ai <prompt>"
    return 1
  fi
  
  local input
  if [[ ! -t 0 ]]; then
    input=$(cat)
  fi

  # Instrument AI call with OTel span
  local span_name="ai.infer"
  local start_time=$(date +%s%N)
  
  if [[ -n "$(command -v zdots_ai_infer)" ]]; then
    local output
    if [[ -n "$input" ]]; then
      output=$(zdots_ai_infer "Data: $input\n\nTask: $1")
    else
      output=$(zdots_ai_infer "$1")
    fi
    local status=$?
    
    # Send span asynchronously
    if command -v otel-cli >/dev/null 2>&1; then
      (
        otel-cli span \
          --name "$span_name" \
          --attrs "model=${ZDOTS_AI_MODEL:-unknown},provider=${ZDOTS_SERVICE_AI:-none}" \
          --force-trace-id "$ZDOTS_TRACE_ID" \
          --force-span-id "$ZDOTS_SPAN_ID" \
          $( [[ $status -ne 0 ]] && echo "--status error" ) \
          >/dev/null 2>&1
      ) &!
    fi
    
    echo "$output"
    return $status
  else
    echo "ai: error: no AI inference provider configured or initialized" >&2
    return 1
  fi
}

if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  zdefer source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Zsh Vi Mode
if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]]; then
  zdefer source "$HOMEBREW_PREFIX/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
fi

# Zsh Autopair
if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-autopair/autopair.zsh" ]]; then
  zdefer source "$HOMEBREW_PREFIX/share/zsh-autopair/autopair.zsh"
fi

# You Should Use (Alias coach)
if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh" ]]; then
  zdefer source "$HOMEBREW_PREFIX/share/zsh-you-should-use/you-should-use.plugin.zsh"
fi

if [[ "$TERM_PROGRAM" == "iTerm.app" && -o interactive && -t 1 && -r "$ZDOTDIR/.iterm2_shell_integration.zsh" ]]; then
  source "$ZDOTDIR/.iterm2_shell_integration.zsh"
fi

if [[ -o interactive && "${ZDOTS_CHECK_SKIP_FZF:-0}" != "1" && -r "$ZDOTDIR/.fzf.zsh" ]]; then
  source "$ZDOTDIR/.fzf.zsh"
fi

if [[ -o interactive && "${ZDOTS_CHECK_SKIP_FZF:-0}" != "1" && -r "$ZDOTDIR/fzfrc" ]]; then
  source "$ZDOTDIR/fzfrc"
fi

# fzf-tab: replaces zsh completion menu with fzf
if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh" ]]; then
  source "$HOMEBREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"
fi

# Machine-local and private overrides.
[[ -r "$ZDOTDIR/.zshrc.local" ]] && source "$ZDOTDIR/.zshrc.local"

# Let fzf-tab (or standard completion) handle Tab.
# Remove the aggressive fzf-completion override to reduce "greediness".
if [[ -o interactive ]]; then
  if (( ${+widgets[fzf-completion]} )); then
    # Keep fzf-completion available but don't bind to raw Tab.
    # It can still be used via the trigger (e.g. **<Tab>)
    bindkey '^I' expand-or-complete
    bindkey -M main '^I' expand-or-complete
    bindkey -M emacs '^I' expand-or-complete
    bindkey -M viins '^I' expand-or-complete
  else
    bindkey '^I' expand-or-complete
    bindkey -M main '^I' expand-or-complete
    bindkey -M emacs '^I' expand-or-complete
    bindkey -M viins '^I' expand-or-complete
  fi
fi

# Keep ^R deterministic: prefer fzf history when available, otherwise use
# built-in incremental history search across keymaps.
if [[ -o interactive ]]; then
  if (( ${+widgets[fzf-history-widget]} )); then
    bindkey '^R' fzf-history-widget
    bindkey -M emacs '^R' fzf-history-widget
    bindkey -M viins '^R' fzf-history-widget
    bindkey -M vicmd '^R' fzf-history-widget
  else
    bindkey '^R' history-incremental-search-backward
    bindkey -M emacs '^R' history-incremental-search-backward
    bindkey -M viins '^R' history-incremental-search-backward
    bindkey -M vicmd '^R' history-incremental-search-backward
  fi
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# History Substring Search
if [[ -n "${HOMEBREW_PREFIX:-}" && -r "$HOMEBREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
  # Bind arrow keys
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  # Bind j/k for vi-mode (integrated with zsh-vi-mode)
  zvm_after_init_commands+=('bindkey -M vicmd "k" history-substring-search-up')
  zvm_after_init_commands+=('bindkey -M vicmd "j" history-substring-search-down')
fi
