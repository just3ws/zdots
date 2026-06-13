#!/usr/bin/env bats
# zsynod queue risk / review / auto — risk-gated auto-delegation. Stubbed dispatch.

setup() {
  ZSYNOD="${BATS_TEST_DIRNAME}/../bin/zsynod"
  REPO="$(mktemp -d)"; cd "$REPO" || return 1
  git init -q; git config user.email t@t; git config user.name t
  printf 'one\n' > doc.md; mkdir -p bin; printf 'echo hi\n' > bin/tool; git add -A; git commit -q -m init
  export ZSYNOD_DIR="$REPO/zsynod" ZSYNOD_MEMBER=claude ZSYNOD_DISPATCH=0
  run "$ZSYNOD" init; [ "$status" -eq 0 ]
  "$ZSYNOD" propose T --body b >/dev/null
}
teardown() { rm -rf "$REPO"; }

_qadd() { printf -- "$1" | "$ZSYNOD" queue add --summary "$2" --ref P1 >/dev/null; }

@test "risk: docs-only change is low" {
  _qadd '--- a/doc.md\n+++ b/doc.md\n@@ -1 +1 @@\n-one\n+two\n' "doc"
  run "$ZSYNOD" queue risk Q1
  [[ "$output" == low* ]]
}

@test "risk: a code-path change is not low" {
  _qadd '--- a/bin/tool\n+++ b/bin/tool\n@@ -1 +1 @@\n-echo hi\n+echo bye\n' "code"
  run "$ZSYNOD" queue risk Q1
  [[ "$output" != low* ]]
}

@test "risk: security/PHI surface is high" {
  _qadd '--- a/etc/phi-patterns.yaml\n+++ b/etc/phi-patterns.yaml\n@@ -1 +1 @@\n-a\n+b\n' "phi"
  run "$ZSYNOD" queue risk Q1
  [[ "$output" == high* ]]
}

@test "peer review records a verdict" {
  _qadd '--- a/doc.md\n+++ b/doc.md\n@@ -1 +1 @@\n-one\n+two\n' "doc"
  run "$ZSYNOD" queue review Q1
  [ "$status" -eq 0 ]
  grep -q '"type":"queue_review"' "$ZSYNOD_DIR/ledger.jsonl"
}

@test "auto applies a low-risk, peer-approved, ready item" {
  _qadd '--- a/doc.md\n+++ b/doc.md\n@@ -1 +1 @@\n-one\n+two\n' "doc"
  "$ZSYNOD" queue review Q1 >/dev/null
  run "$ZSYNOD" queue auto
  [ "$status" -eq 0 ]
  [[ "$output" == *"auto-applied Q1"* ]]
  run cat doc.md; [[ "$output" == "two" ]]
}

@test "auto gates an unreviewed item to the principal" {
  _qadd '--- a/doc.md\n+++ b/doc.md\n@@ -1 +1 @@\n-one\n+two\n' "doc"
  run "$ZSYNOD" queue auto
  [[ "$output" == *"gate Q1"* ]]
  run cat doc.md; [[ "$output" == "one" ]]   # not applied
}

@test "auto gates a high-risk item even if approved" {
  _qadd '--- a/bin/tool\n+++ b/bin/tool\n@@ -1 +1 @@\n-echo hi\n+echo bye and more and more and more\n' "code"
  "$ZSYNOD" queue review Q1 >/dev/null
  run "$ZSYNOD" queue auto
  [[ "$output" == *"gate Q1"* ]]
}
