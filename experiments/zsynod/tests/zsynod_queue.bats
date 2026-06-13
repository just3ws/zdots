#!/usr/bin/env bats
# zsynod queue — priority + dependency aware review of proposed diffs.
# Runs inside a throwaway git repo so `queue apply` (git apply) is real but contained.

setup() {
  ZSYNOD="${BATS_TEST_DIRNAME}/../bin/zsynod"
  REPO="$(mktemp -d)"
  cd "$REPO" || return 1
  git init -q
  git config user.email t@t; git config user.name t
  printf 'one\n' > file.txt
  git add file.txt; git commit -q -m init
  export ZSYNOD_DIR="$REPO/zsynod"
  export ZSYNOD_MEMBER=claude
  run "$ZSYNOD" init; [ "$status" -eq 0 ]
}

teardown() { rm -rf "$REPO"; }

# a valid patch that changes file.txt one -> two
_mkpatch() {
  cat <<'EOF'
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-one
+two
EOF
}

@test "queue add records a queued ledger entry and writes the patch file" {
  _mkpatch | "$ZSYNOD" queue add --summary "one->two" --ref Z-100 --priority HIGH
  grep -q '"type":"queued"' "$ZSYNOD_DIR/ledger.jsonl"
  [ -f "$ZSYNOD_DIR/queue/Q1.patch" ]
  run "$ZSYNOD" verify; [ "$status" -eq 0 ]
}

@test "queue list shows the item with its priority" {
  _mkpatch | "$ZSYNOD" queue add --summary "one->two" --priority HIGH
  run "$ZSYNOD" queue list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Q1"* ]]
  [[ "$output" == *"HIGH"* ]]
}

@test "apply is refused while a declared dependency is unapplied (covenant: do not force)" {
  _mkpatch | "$ZSYNOD" queue add --summary base                       # Q1
  _mkpatch | "$ZSYNOD" queue add --summary dependent --after Q1       # Q2
  run "$ZSYNOD" queue apply Q2
  [ "$status" -ne 0 ]
  [[ "$output" == *"blocked"* ]]
  run grep -c '"status":"applied"' "$ZSYNOD_DIR/ledger.jsonl"
  [ "$output" -eq 0 ]
}

@test "apply lands the diff on the working tree and records applied" {
  _mkpatch | "$ZSYNOD" queue add --summary "one->two"                 # Q1
  run "$ZSYNOD" queue apply Q1
  [ "$status" -eq 0 ]
  run cat file.txt
  [[ "$output" == "two" ]]
  grep -q '"status":"applied"' "$ZSYNOD_DIR/ledger.jsonl"
}

@test "apply refuses a patch that does not apply cleanly" {
  cat <<'EOF' | "$ZSYNOD" queue add --summary "bad context"
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-NOPE
+three
EOF
  run "$ZSYNOD" queue apply Q1
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not apply cleanly"* ]]
}

@test "reject hides the item from the main list" {
  _mkpatch | "$ZSYNOD" queue add --summary "one->two"
  "$ZSYNOD" queue reject Q1 "not now"
  run "$ZSYNOD" queue list
  [[ "$output" != *"Q1"* ]]
}

@test "priority orders READY items HIGH before LOW" {
  _mkpatch | "$ZSYNOD" queue add --summary low  --priority LOW         # Q1
  _mkpatch | "$ZSYNOD" queue add --summary high --priority HIGH        # Q2
  run "$ZSYNOD" queue list
  [ "$status" -eq 0 ]
  # Q2 (HIGH) should appear before Q1 (LOW)
  q2_line=$(echo "$output" | grep -n Q2 | cut -d: -f1)
  q1_line=$(echo "$output" | grep -n Q1 | cut -d: -f1)
  [ "$q2_line" -lt "$q1_line" ]
}
