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

  zdots_model_verify "$dest" "$file"
}

# zdots_model_verify <path> [filename_for_manifest_lookup]
# Verify a model file against lib/llama-models.sha256.
# Exits 1 on mismatch; exits 0 if file passes or has no entry in manifest.
zdots_model_verify() {
  local path="$1"
  local name="${2:-$(basename "$1")}"
  local manifest="${ZDOTDIR:-$HOME/.config/zsh}/lib/llama-models.sha256"

  [[ -f "$path" ]] || { _model_err "verify: file not found: $path"; return 1; }
  [[ -f "$manifest" ]] || { _model_log "verify: no manifest at $manifest — skipping"; return 0; }

  local expected
  expected=$(grep -E "^[0-9a-f]{64}[[:space:]]+${name}$" "$manifest" 2>/dev/null | awk '{print $1}')

  if [[ -z "$expected" ]]; then
    _model_log "verify: $name not in manifest — run: shasum -a 256 \"$path\" then add to lib/llama-models.sha256"
    return 0
  fi

  _model_log "verifying $name (sha256)..."
  local actual; actual=$(shasum -a 256 "$path" | awk '{print $1}')

  if [[ "$actual" == "$expected" ]]; then
    _model_log "verified: $name OK"
  else
    _model_err "SHA256 MISMATCH for $name"
    _model_err "  expected: $expected"
    _model_err "  actual:   $actual"
    _model_err "The model file may be corrupt or tampered. Remove it and re-download."
    _model_err "  rm \"$path\" && llama-ctl model-download"
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
