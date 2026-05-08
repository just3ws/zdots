#!/usr/bin/env bash
# lib/model-store.bash — Unified AI Model Management
#
# RATIONALE:
# Centralizes the downloading, verification, and caching of AI model assets
# (GGUF, bin, etc.) from HuggingFace.

_model_log() { printf 'model-store: %s\n' "$*" >&2; }
_model_err() { printf 'model-store: error: %s\n' "$*" >&2; }

# zdots_model_download <repo> <file> <dest_dir> [url_path_prefix]
zdots_model_download() {
  local repo="$1"
  local file="$2"
  local dest_dir="$3"
  local path_prefix="${4:-}" # e.g. "models/" for whisper

  local dest="$dest_dir/$file"
  if [[ -f "$dest" ]]; then
    local size; size=$(du -sh "$dest" | cut -f1)
    _model_log "$file already downloaded ($size). Skipping."
    return 0
  fi

  local url="https://huggingface.co/${repo}/resolve/main/${path_prefix}${file}"
  mkdir -p "$dest_dir"
  
  _model_log "downloading ${file}..."
  _model_log "source: ${url}"
  _model_log "dest:   ${dest}"

  # Support authenticated downloads
  local -a auth_header=()
  local token="${HUGGINGFACE_TOKEN:-${HF_TOKEN:-}}"
  [[ -n "$token" ]] && auth_header=(-H "Authorization: Bearer $token")

  if curl -L --progress-bar "${auth_header[@]}" --continue-at - -o "$dest" "$url"; then
    local actual; actual=$(du -sh "$dest" | cut -f1)
    _model_log "downloaded $file ($actual)"
  else
    _model_err "failed to download $file"
    return 1
  fi
}

# zdots_model_prune <dir> <active_file> <glob_pattern>
zdots_model_prune() {
  local dir="$1"
  local active="$2"
  local pattern="${3:-*}"

  if [[ ! -d "$dir" ]]; then
    _model_log "no directory to prune: $dir"
    return 0
  fi

  local pruned=0
  while IFS= read -r -d '' f; do
    local name; name=$(basename "$f")
    [[ "$name" == "$active" ]] && continue
    _model_log "removing $name"
    rm -f "$f"
    pruned=$((pruned + 1))
  done < <(find "$dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)

  _model_log "pruned $pruned model(s) from $dir"
}
