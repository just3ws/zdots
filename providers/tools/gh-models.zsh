# providers/tools/gh-models.zsh — GitHub Models from the command line.
#
# zgh sends one-shot prompts to GitHub Models (https://models.github.ai),
# authorized by the existing `gh` OAuth token — no PAT, no new key to manage.
# The catalog spans OpenAI (gpt-4o-mini … gpt-5), DeepSeek, Llama, Mistral,
# and Cohere behind one endpoint. Seated in the zsynod as @gh via the
# `openai` backend (zsynod/members.json: key_cmd "gh auth token").
#
# ⚠ CLOUD TOOL on a PHI-adjacent machine: every prompt leaves the box.
# Prompt and piped stdin are passed through phi_scrub before sending —
# the scrubber is the FIRST gate, not the last. Do not feed it raw records.
#
# Usage:
#   zgh "prompt"                  # one-shot (model: $ZGH_MODEL, default gpt-4o-mini)
#   cmd | zgh "task"              # piped context, scrubbed, same as ai-query
#   zgh -m openai/gpt-5-mini "…"  # any catalog model
#   zgh --models                  # list the catalog

zdots_gh_models_init() {
  if ! command -v gh >/dev/null 2>&1; then
    print -u2 'zgh: gh not installed — `brew install gh`.'
    return 127
  fi
  if [[ -z "${GH_MODELS_TOKEN:-}" ]]; then
    export GH_MODELS_TOKEN="$(gh auth token 2>/dev/null)"
  fi
  if [[ -z "${GH_MODELS_TOKEN:-}" ]]; then
    print -u2 'zgh: no token — `gh auth login` first.'
    return 1
  fi
  # PHI gate: cloud egress requires the scrubber to be loadable.
  if ! typeset -f phi_scrub >/dev/null 2>&1; then
    # shellcheck source=lib/phi_scrubber.bash
    [[ -r "${ZDOTDIR}/lib/phi_scrubber.bash" ]] && source "${ZDOTDIR}/lib/phi_scrubber.bash"
  fi
  if ! typeset -f phi_scrub >/dev/null 2>&1; then
    print -u2 'zgh: phi_scrub unavailable — refusing cloud egress without the scrubber.'
    return 1
  fi
}

# zgh — GitHub Models one-shot, scrubbed and traced.
zgh() {
  zdots_gh_models_init || return $?

  local model="${ZGH_MODEL:-openai/gpt-4o-mini}"
  if [[ "$1" == "--models" ]]; then
    curl -s https://models.github.ai/catalog/models \
      -H "Authorization: Bearer ${GH_MODELS_TOKEN}" \
      | python3 -c 'import json,sys; [print(m["id"]) for m in json.load(sys.stdin)]'
    return $?
  fi
  if [[ "$1" == "-m" || "$1" == "--model" ]]; then
    model="$2"; shift 2
  fi
  if [[ -z "$1" ]]; then
    print -u2 'usage: zgh [-m <model>] "prompt"  |  zgh --models'
    return 2
  fi

  # Scrub everything that leaves the box: the prompt, and stdin if piped.
  local prompt
  prompt="$(print -r -- "$1" | phi_scrub)"
  if [[ ! -t 0 ]]; then
    prompt="${prompt}"$'\n\n'"$(phi_scrub)"
  fi

  typeset -f zdots_trace_log >/dev/null 2>&1 \
    && zdots_trace_log "ai_query" "tool=zgh,model=${model},prompt=${prompt[1,128]}"

  python3 - "$model" "$prompt" <<'PYEOF'
import json, os, sys, urllib.request
model, prompt = sys.argv[1], sys.argv[2]
req = urllib.request.Request(
    "https://models.github.ai/inference/chat/completions",
    data=json.dumps({"model": model,
                     "messages": [{"role": "user", "content": prompt}]}).encode(),
    headers={"Content-Type": "application/json",
             "Authorization": f"Bearer {os.environ['GH_MODELS_TOKEN']}"},
    method="POST")
with urllib.request.urlopen(req, timeout=60) as resp:
    print(json.load(resp)["choices"][0]["message"]["content"].strip())
PYEOF
}
