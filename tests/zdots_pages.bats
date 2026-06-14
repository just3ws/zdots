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
