# Interface: AI Inference Service
# Depends on zdots_ai_init provided by the active AI provider.

if [[ -n "$(command -v zdots_ai_init)" ]]; then
  if [[ -z "${_ZDOTS_AI_INITIALIZED:-}" ]]; then
    zdots_ai_init
  fi
fi

if [[ -n "$(command -v zdots_whisper_init)" ]]; then
  zdots_whisper_init
fi

_zdots_lazy_tool_provider() {
  local provider_file="$1"
  local function_name="$2"
  shift 2

  if [[ -r "$provider_file" ]]; then
    source "$provider_file"
  fi

  if typeset -f "$function_name" >/dev/null 2>&1; then
    "$function_name" "$@"
  else
    print -u2 "zdots: tool provider failed to define $function_name"
    return 1
  fi
}

# Agent sidecars are optional and can stay out of shell startup. Expose stable
# functions, then source the heavier provider files only on first use.
if [[ -r "$ZDOTDIR/providers/tools/pi.zsh" ]] && ! typeset -f zpi >/dev/null 2>&1; then
  zpi() {
    unfunction zpi 2>/dev/null || true
    _zdots_lazy_tool_provider "$ZDOTDIR/providers/tools/pi.zsh" zpi "$@"
  }
fi

if [[ -r "$ZDOTDIR/providers/tools/aider.zsh" ]] && ! typeset -f zaider >/dev/null 2>&1; then
  zaider() {
    unfunction zaider 2>/dev/null || true
    _zdots_lazy_tool_provider "$ZDOTDIR/providers/tools/aider.zsh" zaider "$@"
  }
fi

if [[ -r "$ZDOTDIR/providers/tools/aider.zsh" ]] && ! typeset -f laid >/dev/null 2>&1; then
  laid() {
    unfunction laid 2>/dev/null || true
    _zdots_lazy_tool_provider "$ZDOTDIR/providers/tools/aider.zsh" laid "$@"
  }
fi

if [[ -r "$ZDOTDIR/providers/tools/opencode.zsh" ]] && ! typeset -f zopencode >/dev/null 2>&1; then
  zopencode() {
    unfunction zopencode 2>/dev/null || true
    _zdots_lazy_tool_provider "$ZDOTDIR/providers/tools/opencode.zsh" zopencode "$@"
  }
fi

if [[ -r "$ZDOTDIR/providers/tools/apfel.zsh" ]] && ! typeset -f zapfel >/dev/null 2>&1; then
  zapfel() {
    unfunction zapfel 2>/dev/null || true
    _zdots_lazy_tool_provider "$ZDOTDIR/providers/tools/apfel.zsh" zapfel "$@"
  }
fi

if [[ -r "$ZDOTDIR/providers/tools/gh-models.zsh" ]] && ! typeset -f zgh >/dev/null 2>&1; then
  zgh() {
    unfunction zgh 2>/dev/null || true
    _zdots_lazy_tool_provider "$ZDOTDIR/providers/tools/gh-models.zsh" zgh "$@"
  }
fi

if [[ -r "$ZDOTDIR/providers/tools/router.zsh" ]] && ! typeset -f zai >/dev/null 2>&1; then
  zai() {
    unfunction zai 2>/dev/null || true
    _zdots_lazy_tool_provider "$ZDOTDIR/providers/tools/router.zsh" zai "$@"
  }
fi
