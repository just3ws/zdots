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
    zdots-eval
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
    cc-home
    log-rotate
    zdots-phi-scrub
    zdots-schema
    history-intelligence
    session-debrief
    zdots-pages
    bench
    zdots-pattern
    zdots-issue
    imperial-date
    zdots-search
    zdots-draft
    zdots-publish
  "
  for command in $commands; do
    [[ -z "$command" ]] && continue
    if _known_gap "$command"; then
      continue
    fi
    run "$BIN/$command" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* || "$output" == *"Commands:"* || "$output" == *"Options:"* || "$output" == *"usage:"* || "$output" == *"Usage of"* ]]
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
    agent-guide ai-query alias-suggest bootstrap capabilities cc-burn cc-burn-watch cc-doctor colima-status commit-msg
    diff-review docker-reclaim gemini-mcp-register history-analyze history-import
    idiot-test llama-caps llama-ctl local-ci nginx-ctl nginx-repair openobserve-ctl otel-collector otel-smoke ruby-audit ruby-audit-batch ruby-audit-diff pi-ctx-brief pi-ctx-hydrate
    pi-ctx-query pi-ctx-status whisper-ctl zdash zdots-ask zdots-ctx zdots-doctor
    zdots-endpoints zdots-gh zdots-github-keys zdots-graph-audit zdots-index-tools zdots-keychain zdots-log-analyze zdots-logs zdots-o2-query zdots-otel-phi-compile zdots-patch-export zdots-pulse zdots-quiz zdots-ruby-default-gems zdots-server-keys zdots-status zdots-ctl zdots-ruby-bump zdots-ruby-clone zdots-update-local zdots-my-sync zdots-ingest-prepare zdots-ingest-media zdots-backfill-boundaries
    nginx-regen-certs zclaude zdots-statusd zdots-statusd-ctl
    zdots-worker zdots-eval zsynod zsynod-migrate
    zmetrics zmorning zsvc ztask
    cc-home log-rotate gemstash-ctl gemstash-metadata zdots-buffer-drain zdots-phi-scrub zdots-schema history-intelligence session-debrief zdots-pages
    bench zdots-pattern zdots-issue imperial-date zdots-man-gen zdots-platform
    embed-model-tripwire zdots-theme-gen
    zdots zdots-artifact zdots-debrief zdots-snapshot zdots-search zdots-draft zdots-publish
    zdots-help zdots-watch zdots-usage
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

@test "docs: Z-249 sweep — every bin executable answers --help fast, rc=0, with usage text" {
  # Non-interactive safety (Z-249): every executable in bin/ not in the
  # known-gaps ledger must answer --help within 5s, exit 0, and print
  # usage-ish text — WITHOUT executing its action. `timeout 5` catches hangs
  # and real launches (rc=124); `</dev/null` catches TTY prompts.
  local -a failed=()
  local script name out rc
  for script in "$BIN"/*; do
    name="$(basename "$script")"
    [[ -f "$script" && -x "$script" ]] || continue
    if _known_gap "$name"; then
      continue
    fi
    rc=0
    out="$(timeout 5 "$script" --help </dev/null 2>&1)" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
      failed+=("$name (rc=$rc)")
      continue
    fi
    case "$out" in
      *"Usage:"*|*"Commands:"*|*"Options:"*|*"usage:"*|*"Usage of"*) ;;
      *) failed+=("$name (rc=0, no usage text)") ;;
    esac
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    printf -- '--help contract violations (fix the command or ledger it in docs-contract-known-gaps.txt):\n' >&2
    printf '  %s\n' "${failed[@]}" >&2
    return 1
  fi
}

@test "docs: fictional-reference linting — backtick commands in tracked docs exist in bin/ or allowlist" {
  # R2 invariant (Z-153 AC#2+AC#3): docs must not cite zdots-* commands that don't exist.
  # Tier file list comes from etc/docs-sync-manifest.yaml (AC#3 single source of truth).
  # Falls back to AGENTS.md + CLAUDE.md if yq/manifest unavailable.
  #
  # Non-binary tokens (labels, aliases, external tools, schema terms) are allowlisted below.
  local -a allowlist=(
    # backlog labels / triage tags
    agent-ready agent-reported needs-info
    # shell aliases (not bin/ scripts)
    cl laid zpi zaider
    # external tools / well-known binaries
    git curl brew jq yq psql pgcli sqlite3
    # concept/schema terms used in backticks
    scram-sha-256 cloud none local
    # platform concepts that aren't commands
    context-engine my zdots-brain
  )

  local -a docs=()
  local manifest="$REPO_ROOT/etc/docs-sync-manifest.yaml"
  if command -v yq >/dev/null 2>&1 && [[ -f "$manifest" ]]; then
    # Read tier files from the manifest
    while IFS= read -r f; do
      [[ -f "$REPO_ROOT/$f" ]] && docs+=("$REPO_ROOT/$f")
    done < <(yq '.tiers[].file // ""' "$manifest" 2>/dev/null | grep -v '^$\|^null$')
  fi
  # Always include the core initializers (fallback if manifest unreadable)
  for core in AGENTS.md CLAUDE.md; do
    local already=0
    for d in "${docs[@]}"; do [[ "$d" == "$REPO_ROOT/$core" ]] && already=1 && break; done
    [[ $already -eq 0 && -f "$REPO_ROOT/$core" ]] && docs+=("$REPO_ROOT/$core")
  done
  # add wiki docs if present
  for w in "$REPO_ROOT"/docs/wiki/*.md; do
    [[ -f "$w" ]] && docs+=("$w")
  done

  local -a phantom=()

  for doc in "${docs[@]}"; do
    # extract all `zdots-*` backtick references
    while IFS= read -r token; do
      # check allowlist
      local allowed=0
      for a in "${allowlist[@]}"; do
        [[ "$token" == "$a" ]] && allowed=1 && break
      done
      (( allowed )) && continue
      # must exist in bin/
      if [[ ! -x "$REPO_ROOT/bin/$token" ]]; then
        phantom+=("${token} (in $(basename "$doc"))")
      fi
    done < <(grep -ohE '`zdots-[a-z][a-z0-9-]+`' "$doc" 2>/dev/null | sed "s/\`//g" | sort -u)
  done

  if [[ ${#phantom[@]} -gt 0 ]]; then
    printf 'Phantom zdots-* references (cited in docs but not in bin/):\n' >&2
    printf '  %s\n' "${phantom[@]}" >&2
    printf 'Either add the script to bin/ or add an entry to docs-contract-known-gaps.txt\n' >&2
    return 1
  fi
}

@test "docs: every bin command has a man page (zdots-man-gen --check)" {
  run "$REPO_ROOT/bin/zdots-man-gen" --check
  if [[ "$status" -ne 0 ]]; then
    printf 'Commands without man pages (run: zdots-man-gen):\n%s\n' "$output" >&2
    return 1
  fi
}
