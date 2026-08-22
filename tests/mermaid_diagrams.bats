#!/usr/bin/env bats
# tests/mermaid_diagrams.bats — machine-validate all Mermaid diagrams in the repo.
#
# Runs mmdc against every *.md file that contains a ```mermaid block.
# Skips gracefully when mmdc is absent so CI without Chrome does not hard-fail.
# Add this target to make: `make docs-diagrams`

setup() {
  load "setup.bash"
  setup_environment
}

# A binary on PATH is not a working renderer. mermaid-cli shells out to a
# puppeteer chromium that goes missing on every mermaid-cli upgrade, and the
# old `command -v mmdc` guard passed anyway — so a dead toolchain reported as
# seven broken documents instead of a skip (Z-307). Prove it can render.
# ponytail: one probe render per test (~1s). Cache it if the suite drags.
_require_mmdc() {
  command -v mmdc >/dev/null 2>&1 || skip "mmdc not found — install mermaid-cli to validate diagrams"
  local probe="${BATS_TEST_TMPDIR:-/tmp}/mmdc_probe"
  printf 'graph TD\n  A-->B\n' > "$probe.mmd"
  mmdc -i "$probe.mmd" -o "$probe.svg" >/dev/null 2>&1 || \
    skip "mmdc present but cannot render — chromium missing. Fix: npx puppeteer browsers install chrome-headless-shell"
}

# Collect all *.md files that contain at least one mermaid code block.
_mermaid_files() {
  grep -rl '```mermaid' "$REPO_ROOT" \
    --include='*.md' \
    --exclude-dir='.git' \
    --exclude-dir='node_modules' \
    --exclude-dir='backlog'
}

@test "mmdc is available (skip entire suite if not)" {
  _require_mmdc
}

@test "docs/architecture.md — all Mermaid diagrams parse" {
  _require_mmdc
  local out
  out=$(mmdc -i "$REPO_ROOT/docs/architecture.md" -o /tmp/mermaid_arch_test.svg 2>&1)
  local rc=$?
  [ $rc -eq 0 ] || { echo "mmdc error: $out"; return 1; }
}

@test "docs/local-ai.md — all Mermaid diagrams parse" {
  _require_mmdc
  local out
  out=$(mmdc -i "$REPO_ROOT/docs/local-ai.md" -o /tmp/mermaid_local_ai_test.svg 2>&1)
  local rc=$?
  [ $rc -eq 0 ] || { echo "mmdc error: $out"; return 1; }
}

@test "docs/repository-evolution.md — all Mermaid diagrams parse" {
  _require_mmdc
  local out
  out=$(mmdc -i "$REPO_ROOT/docs/repository-evolution.md" -o /tmp/mermaid_repo_evo_test.svg 2>&1)
  local rc=$?
  [ $rc -eq 0 ] || { echo "mmdc error: $out"; return 1; }
}

@test "README.md — all Mermaid diagrams parse" {
  _require_mmdc
  local out
  out=$(mmdc -i "$REPO_ROOT/README.md" -o /tmp/mermaid_readme_test.svg 2>&1)
  local rc=$?
  [ $rc -eq 0 ] || { echo "mmdc error: $out"; return 1; }
}

@test "docs/lifecycle.md — all Mermaid diagrams parse" {
  _require_mmdc
  local out
  out=$(mmdc -i "$REPO_ROOT/docs/lifecycle.md" -o /tmp/mermaid_lifecycle_test.svg 2>&1)
  local rc=$?
  [ $rc -eq 0 ] || { echo "mmdc error: $out"; return 1; }
}

@test "docs/platform-dependency-graph.md — all Mermaid diagrams parse" {
  _require_mmdc
  local out
  out=$(mmdc -i "$REPO_ROOT/docs/platform-dependency-graph.md" -o /tmp/mermaid_dep_graph_test.svg 2>&1)
  local rc=$?
  [ $rc -eq 0 ] || { echo "mmdc error: $out"; return 1; }
}

# Catch-all: every other *.md in the repo that contains a mermaid block.
# New diagram-bearing docs are picked up automatically — no test change needed.
@test "all other repo Mermaid diagrams parse" {
  _require_mmdc

  # Already covered individually above — exclude them from the sweep.
  local covered=(
    "$REPO_ROOT/docs/architecture.md"
    "$REPO_ROOT/docs/local-ai.md"
    "$REPO_ROOT/docs/repository-evolution.md"
    "$REPO_ROOT/README.md"
    "$REPO_ROOT/docs/lifecycle.md"
    "$REPO_ROOT/docs/platform-dependency-graph.md"
  )

  local failed=0
  local errors=""

  while IFS= read -r file; do
    local skip=0
    for c in "${covered[@]}"; do
      [ "$file" = "$c" ] && skip=1 && break
    done
    [ $skip -eq 1 ] && continue

    local out
    out=$(mmdc -i "$file" -o /tmp/mermaid_sweep_test.svg 2>&1)
    if [ $? -ne 0 ]; then
      failed=$((failed + 1))
      errors="${errors}\n  FAIL: ${file}\n  ${out}\n"
    fi
  done < <(_mermaid_files)

  if [ $failed -gt 0 ]; then
    echo -e "Mermaid parse failures:${errors}"
    return 1
  fi
}
