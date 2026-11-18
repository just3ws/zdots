#!/usr/bin/env bats
# tests/adots_fetch_rule.bats — lib/adots.bash: a bare adots clone gets the
# standard fetch rule, so origin/main follows GitHub instead of freezing at
# clone time. Uses a throwaway upstream repo; nothing touches ~/.homegit.

setup() {
  load "setup.bash"
  setup_environment
  . "$REPO_ROOT/lib/adots.bash"
  UP="$BATS_TEST_TMPDIR/upstream"
  BARE="$BATS_TEST_TMPDIR/homegit"
  git init -q -b main "$UP"
  git -C "$UP" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m one
  git clone -q --bare "$UP" "$BARE"
}

advance_upstream() {
  git -C "$UP" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m two
}

@test "a plain bare clone has no fetch rule (the gap this fixes)" {
  run git --git-dir="$BARE" config --get remote.origin.fetch
  [ "$status" -ne 0 ]
}

@test "adots_ensure_fetch_rule adds the rule and main tracks origin/main" {
  run adots_ensure_fetch_rule "$BARE"
  [ "$status" -eq 0 ]
  [ "$(git --git-dir="$BARE" config --get remote.origin.fetch)" = '+refs/heads/*:refs/remotes/origin/*' ]
  [ "$(git --git-dir="$BARE" rev-parse --abbrev-ref main@{upstream})" = "origin/main" ]
}

@test "after the rule, a fetch moves origin/main to the upstream's main" {
  adots_ensure_fetch_rule "$BARE"
  advance_upstream
  git --git-dir="$BARE" fetch -q origin
  [ "$(git --git-dir="$BARE" rev-parse origin/main)" = "$(git -C "$UP" rev-parse main)" ]
  # The local branch is untouched: landing stays a deliberate step.
  [ "$(git --git-dir="$BARE" rev-parse main)" != "$(git -C "$UP" rev-parse main)" ]
}

@test "adots_ensure_fetch_rule is idempotent and keeps an existing rule" {
  git --git-dir="$BARE" config remote.origin.fetch '+refs/heads/main:refs/remotes/origin/main'
  adots_ensure_fetch_rule "$BARE"
  adots_ensure_fetch_rule "$BARE"
  run git --git-dir="$BARE" config --get-all remote.origin.fetch
  [ "$output" = '+refs/heads/main:refs/remotes/origin/main' ]
}
