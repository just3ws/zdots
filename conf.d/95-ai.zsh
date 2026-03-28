# Interface: AI Inference Service
# Depends on zdots_ai_init provided by the active AI provider.

if [[ -n "$(command -v zdots_ai_init)" ]]; then
  if [[ -z "${_ZDOTS_AI_INITIALIZED:-}" ]]; then
    zdots_ai_init
  fi
fi
