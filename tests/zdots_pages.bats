#!/usr/bin/env bats
# tests/zdots_pages.bats — reusable GitHub Pages + Wiki publisher.
#
# Exercises the local, reversible paths (status/init/build) and the fail-closed
# visibility guard. `gh` and the network are stubbed; no outward push occurs.

setup() {
  load "setup.bash"
  setup_environment            # sets ZDOTDIR=REPO_ROOT so the real template resolves
  BIN="$REPO_ROOT/bin"

  TMP="$(mktemp -d)"
  # A throwaway repo with an origin remote and a docs/wiki tree.
  REPO="$TMP/sample"
  mkdir -p "$REPO/docs/wiki"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email t@t.t
  git -C "$REPO" config user.name t
  git -C "$REPO" remote add origin "https://github.com/just3ws/sample.git"
  printf '# Home\nwelcome\n' > "$REPO/docs/wiki/Home.md"
  printf '# Sub\nbody\n'     > "$REPO/docs/wiki/Sub-Page.md"
  git -C "$REPO" add -A
  git -C "$REPO" commit -qm init

  # Stub gh: visibility driven by GH_STUB_PRIVATE; canned description/wiki.
  STUB="$TMP/bin"; mkdir -p "$STUB"
  cat >"$STUB/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"isPrivate"*)       [[ "${GH_STUB_PRIVATE:-false}" == "true" ]] && echo true || echo false ;;
  *"hasWikiEnabled"*)  echo false ;;
  *"description"*)      echo "sample repo" ;;
  *)                   echo "{}" ;;
esac
EOF
  chmod +x "$STUB/gh"
  export PATH="$STUB:$PATH"
}

teardown() { rm -rf "$TMP"; }

@test "zdots-pages: --help exits 0 and shows usage" {
  run "$BIN/zdots-pages" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "zdots-pages: status reports public repo and page count" {
  run "$BIN/zdots-pages" status --repo "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"just3ws/sample"* ]]
  [[ "$output" == *"visibility:  public"* ]]
  [[ "$output" == *"2 pages"* ]]
  [[ "$output" == *"https://just3ws.github.io/sample"* ]]
}

@test "zdots-pages: build renders index + front matter + shared config" {
  run "$BIN/zdots-pages" init --repo "$REPO"
  [ "$status" -eq 0 ]
  run "$BIN/zdots-pages" build --repo "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"built 2 pages"* ]]

  [ -f "$REPO/.gh-pages/index.md" ]          # Home → index
  [ -f "$REPO/.gh-pages/Sub-Page.md" ]
  grep -q 'permalink: /' "$REPO/.gh-pages/index.md"
  grep -q 'title: Sub Page' "$REPO/.gh-pages/Sub-Page.md"
  grep -q 'remote_theme: just-the-docs' "$REPO/.gh-pages/_config.yml"
  grep -q 'baseurl: "/sample"' "$REPO/.gh-pages/_config.yml"
  grep -q 'url: "https://just3ws.github.io"' "$REPO/.gh-pages/_config.yml"
}

@test "zdots-pages: publish refuses a PRIVATE repo without --allow-private" {
  "$BIN/zdots-pages" init  --repo "$REPO"
  "$BIN/zdots-pages" build --repo "$REPO"
  GH_STUB_PRIVATE=true run "$BIN/zdots-pages" publish --repo "$REPO"
  [ "$status" -ne 0 ]
  [[ "$output" == *"PRIVATE"* ]]
  [[ "$output" == *"refusing"* ]]
}

@test "zdots-pages: publish without --push commits locally but does not push" {
  "$BIN/zdots-pages" init  --repo "$REPO"
  "$BIN/zdots-pages" build --repo "$REPO"
  run "$BIN/zdots-pages" publish --repo "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Re-run with --push"* ]]
  # A commit exists on gh-pages, but origin is a bare URL we never pushed to.
  run git -C "$REPO/.gh-pages" log --oneline
  [ "$status" -eq 0 ]
  [[ "$output" == *"publish site via zdots-pages"* ]]
}

@test "zdots-pages: build on a BARE repo via --git-dir + --wiki-src + --worktree" {
  # A bare repo (no working tree) with an origin remote — mirrors adots (~/.homegit).
  BARE="$TMP/home.git"
  git init -q --bare "$BARE"
  git --git-dir="$BARE" remote add origin "https://github.com/just3ws/adots.git"

  # Docs live outside the repo: --wiki-src is REQUIRED in bare mode.
  SRC="$TMP/wikisrc"; mkdir -p "$SRC"
  printf '# Home\nwelcome\n' > "$SRC/Home.md"
  printf '# Notes\nbody\n'   > "$SRC/Notes.md"

  WT="$TMP/adots.gh-pages"; mkdir -p "$WT"

  run "$BIN/zdots-pages" build --git-dir "$BARE" --wiki-src "$SRC" --worktree "$WT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"built 2 pages"* ]]

  [ -f "$WT/index.md" ]                       # Home → index
  [ -f "$WT/Notes.md" ]
  grep -q 'permalink: /' "$WT/index.md"
  grep -q 'title: Notes' "$WT/Notes.md"
  # owner/repo derived from origin remote, not a working-tree toplevel.
  grep -q 'baseurl: "/adots"' "$WT/_config.yml"
  grep -q 'url: "https://just3ws.github.io"' "$WT/_config.yml"
}

@test "zdots-pages: --git-dir without --wiki-src is refused" {
  BARE="$TMP/home.git"
  git init -q --bare "$BARE"
  git --git-dir="$BARE" remote add origin "https://github.com/just3ws/adots.git"
  run "$BIN/zdots-pages" build --git-dir "$BARE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--wiki-src"* ]]
}

@test "zdots-pages: nav_order is sequential with Home pinned to 1 (no collisions)" {
  # Home plus three other pages — Home must not reset the counter for the rest.
  printf '# Alpha\na\n'   > "$REPO/docs/wiki/Alpha.md"
  printf '# Beta\nb\n'    > "$REPO/docs/wiki/Beta.md"
  printf '# Gamma\nc\n'   > "$REPO/docs/wiki/Gamma.md"

  "$BIN/zdots-pages" init  --repo "$REPO"
  run "$BIN/zdots-pages" build --repo "$REPO"
  [ "$status" -eq 0 ]

  # Home → index.md → nav_order: 1
  grep -q '^nav_order: 1$' "$REPO/.gh-pages/index.md"

  # Collect nav_order from every non-Home page; assert distinct + none equal 1.
  local orders=()
  for p in "$REPO"/.gh-pages/*.md; do
    if [[ "$(basename "$p")" == "index.md" ]]; then continue; fi
    local o; o="$(grep -m1 '^nav_order: ' "$p" | awk '{print $2}')"
    [ -n "$o" ]
    [ "$o" -ne 1 ]
    orders+=("$o")
  done
  # No duplicates: unique count equals total count.
  local total uniq
  total="${#orders[@]}"
  uniq="$(printf '%s\n' "${orders[@]}" | sort -u | wc -l | tr -d ' ')"
  [ "$total" -eq "$uniq" ]
  [ "$total" -ge 4 ]   # Sub-Page + Alpha + Beta + Gamma (Home excluded)
}
