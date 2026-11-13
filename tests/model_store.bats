#!/usr/bin/env bats
# tests/model_store.bats — model verification fails closed (Z-363).
# A fake curl stands in for Hugging Face's HEAD response; no network.

setup() {
  load "setup.bash"
  setup_environment
  export ZDOTDIR="$BATS_TEST_TMPDIR/zdotdir"
  mkdir -p "$ZDOTDIR/lib" "$BATS_TEST_TMPDIR/bin"
  MODEL="$BATS_TEST_TMPDIR/model.gguf"
  printf 'weights' > "$MODEL"
  GOOD="$(shasum -a 256 "$MODEL" | awk '{print $1}')"
  BAD="$(printf '%064d' 0)"
  printf '# manifest\n' > "$ZDOTDIR/lib/llama-models.sha256"
  export HF_ETAG=""
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'SH'
#!/bin/sh
printf 'HTTP/2 302\r\n'
[ -n "$HF_ETAG" ] && printf 'x-linked-etag: "%s"\r\n' "$HF_ETAG"
printf '\r\n'
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

verify() {
  run bash -c "source '$REPO_ROOT/lib/model-store.bash'; zdots_model_verify '$MODEL' model.gguf owner/repo $*"
}

@test "manifest hash match passes" {
  printf '%s  model.gguf\n' "$GOOD" >> "$ZDOTDIR/lib/llama-models.sha256"
  verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"verified"* ]]
}

@test "manifest hash mismatch fails" {
  printf '%s  model.gguf\n' "$BAD" >> "$ZDOTDIR/lib/llama-models.sha256"
  verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISMATCH"* ]]
}

@test "no manifest entry: Hugging Face's published sha256 is used" {
  HF_ETAG="$GOOD"
  verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hugging Face"* ]]
  [[ "$output" == *"verified"* ]]
}

@test "no manifest entry: a Hugging Face sha256 mismatch fails" {
  HF_ETAG="$BAD"
  verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISMATCH"* ]]
}

@test "no hash from either source fails closed" {
  verify
  [ "$status" -eq 1 ]
  [[ "$output" == *"unverified"* ]]
}

@test "ZDOTS_MODEL_ALLOW_UNVERIFIED=1 lets an unverifiable file through, loudly" {
  ZDOTS_MODEL_ALLOW_UNVERIFIED=1 verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"unverified"* ]]
}

@test "the manifest pins the work-light Instruct model" {
  grep -qE '^[0-9a-f]{64}  Qwen_Qwen3-4B-Instruct-2507-Q4_K_M\.gguf$' "$REPO_ROOT/lib/llama-models.sha256"
}
