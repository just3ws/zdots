# Interface: Node Runtime / Mise
# Depends on zdots_node_runtime_init provided by the active node-runtime service.

if [[ -n "$(command -v zdots_node_runtime_init)" ]]; then
  if [[ -z "${_ZDOTS_MISE_INITIALIZED:-}" ]]; then
    zdots_node_runtime_init
  fi
fi
