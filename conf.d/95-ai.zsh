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

# Aider sidecar — wires aider to the active llama.cpp endpoint.
# Provides the zaider() function; does not affect the ZDOTS_SERVICE_AI chain.
if [[ -r "$ZDOTDIR/providers/ai/aider.zsh" ]]; then
  source "$ZDOTDIR/providers/ai/aider.zsh"
fi

# Pi sidecar — wires pi coding agent to local llama.cpp.
# Provides the zpi() function; session history lands in XDG state dir.
if [[ -r "$ZDOTDIR/providers/ai/pi.zsh" ]]; then
  source "$ZDOTDIR/providers/ai/pi.zsh"
fi
