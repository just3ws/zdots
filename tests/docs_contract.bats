#!/usr/bin/env bats
# tests/docs_contract.bats — documentation and interface drift checks

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
}

_known_gap() {
  local name="$1"
  grep -q "^${name}:" "$REPO_ROOT/docs/generated/docs-contract-known-gaps.txt"
}

@test "docs: generated inventory exists" {
  [ -s "$REPO_ROOT/docs/generated/interface-inventory.json" ]
  [ -s "$REPO_ROOT/docs/generated/interface-inventory.md" ]
  jq -e '.schema == "zdots.interface-inventory.v1"' "$REPO_ROOT/docs/generated/interface-inventory.json" >/dev/null
}

@test "docs: wiki source exists" {
  [ -s "$REPO_ROOT/docs/wiki/Home.md" ]
  [ -s "$REPO_ROOT/docs/wiki/Command-Reference.md" ]
  [ -s "$REPO_ROOT/docs/wiki/System-Map.md" ]
}

@test "docs: documented commands have working --help or known gap" {
  commands="
    agent-guide
    ai-query
    alias-suggest
    bootstrap
    capabilities
    cc-doctor
    commit-msg
    diff-review
    docker-reclaim
    history-analyze
    history-import
    idiot-test
    llama-caps
    llama-ctl
    local-ci
    nginx-ctl
    nginx-repair
    openobserve-ctl
    otel-collector
    otel-smoke
    ruby-audit
    ruby-audit-batch
    ruby-audit-diff
    whisper-ctl
    zdash
    zdots-ask
    zdots-ctx
    zdots-doctor
    zdots-endpoints
    zdots-gh
    zdots-graph-audit
    zdots-keychain
    zdots-log-analyze
    zdots-o2-query
    zdots-otel-phi-compile
    zdots-quiz
    zdots-status
    zdots-ctl
    zdots-ruby-bump
    zdots-ruby-clone
    zdots-update-local
    zdots-my-sync
    zdots-worker
    zmetrics
    zmorning
    zsvc
    zsynod
    ztask
  "
  for command in $commands; do
    [[ -z "$command" ]] && continue
    if _known_gap "$command"; then
      continue
    fi
    run "$BIN/$command" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* || "$output" == *"Commands:"* || "$output" == *"Options:"* || "$output" == *"usage:"* ]]
  done
}

@test "docs: known gaps reference backlog issue ids" {
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" =~ z-[0-9]+ ]]
  done < "$REPO_ROOT/docs/generated/docs-contract-known-gaps.txt"
}

@test "docs: manpages exist for core commands and concepts" {
  pages="
    man/man1/capabilities.1
    man/man1/zdots-ctx.1
    man/man1/zdots-gh.1
    man/man1/zmorning.1
    man/man1/agent-guide.1
    man/man1/ai-query.1
    man/man1/zdots-ask.1
    man/man1/ztask.1
    man/man1/zdash.1
    man/man1/zdots-log-analyze.1
    man/man8/zdots-ctl.8
    man/man8/llama-ctl.8
    man/man8/otel-collector.8
    man/man8/local-ci.8
    man/man8/whisper-ctl.8
    man/man8/zsvc.8
    man/man5/zdots-env.5
    man/man5/ai-models.yaml.5
    man/man5/phi-patterns.yaml.5
    man/man7/zdots.7
    man/man7/zdots-observability.7
    man/man7/zdots-phi-safety.7
    man/man7/zdots-ai-stack.7
  "
  for page in $pages; do
    [ -s "$REPO_ROOT/$page" ]
  done
}

@test "docs: manpages render with mandoc" {
  command -v mandoc >/dev/null 2>&1 || skip "mandoc not installed"
  while IFS= read -r page; do
    run mandoc -Tutf8 "$page"
    [ "$status" -eq 0 ]
  done < <(find "$REPO_ROOT/man" -type f | sort)
}

@test "docs: live JSON surfaces are parseable when available" {
  run "$BIN/capabilities" --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.session_id and .ai' >/dev/null

  run "$BIN/agent-guide" --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.services and .ai' >/dev/null

  run "$BIN/zdots-ctl" status --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e 'has("ai_server") and has("intelligence_suite")' >/dev/null
}

@test "docs: capabilities disk_available reports df Avail column, not inode ifree" {
  expected=$(df -h / | awk 'NR==2 {print $4}')

  run "$BIN/capabilities" --json
  [ "$status" -eq 0 ]

  actual=$(printf '%s\n' "$output" | jq -r '.disk_available')
  [ "$actual" = "$expected" ]
}

@test "docs: llama-caps --json emits parseable JSON with expected top-level keys" {
  run "$BIN/llama-caps" --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.server and .capabilities and .config' >/dev/null
}

@test "docs: llama-caps --md emits markdown content" {
  run "$BIN/llama-caps" --md
  [ "$status" -eq 0 ]
  [[ "$output" == *"#"* ]]
}

@test "docs: secret-scan exits 0 on the clean repository" {
  run "$BIN/secret-scan"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "docs: every bin executable is --help-tested or in the known-gaps file" {
  # Canonical set of explicitly tested commands (mirrors the --help test above).
  local -a tested=(
    agent-guide ai-query alias-suggest bootstrap capabilities cc-doctor commit-msg
    diff-review docker-reclaim gemini-mcp-register history-analyze history-import
    idiot-test llama-caps llama-ctl local-ci nginx-ctl nginx-repair openobserve-ctl otel-collector otel-smoke ruby-audit ruby-audit-batch ruby-audit-diff pi-ctx-brief pi-ctx-hydrate
    pi-ctx-query pi-ctx-status whisper-ctl zdash zdots-ask zdots-ctx zdots-doctor
    zdots-endpoints zdots-gh zdots-github-keys zdots-graph-audit zdots-keychain zdots-log-analyze zdots-o2-query zdots-otel-phi-compile zdots-quiz zdots-status zdots-ctl zdots-ruby-bump zdots-ruby-clone zdots-update-local zdots-my-sync zdots-ingest-prepare
    zdots-worker zsynod
    zmetrics zmorning zsvc ztask
  )

  local missing=()
  for script in "$BIN"/*; do
    name="$(basename "$script")"
    [[ -x "$script" ]] || continue
    # Must be in the tested list OR explicitly gaped.
    if _known_gap "$name"; then
      continue
    fi
    local found=0
    for t in "${tested[@]}"; do
      [[ "$t" == "$name" ]] && found=1 && break
    done
    [[ "$found" -eq 1 ]] || missing+=("$name")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'Unaccounted scripts (add to --help test or known-gaps): %s\n' "${missing[*]}" >&2
    return 1
  fi
}
