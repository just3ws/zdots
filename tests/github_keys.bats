#!/usr/bin/env bats

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
}

stub_github_keygen() {
  local stub_dir="$BATS_TEST_TMPDIR/stub-bin"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/github-keygen" <<'STUB'
#!/usr/bin/env bash
printf '%q ' "$@" >> "$BATS_TEST_TMPDIR/github-keygen-args"
printf '\n' >> "$BATS_TEST_TMPDIR/github-keygen-args"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      key="$2"
      mkdir -p "$(dirname "$key")"
      printf 'PRIVATE %s\n' "$key" > "$key"
      printf 'ssh-ed25519 AAAATEST %s\n' "$key" > "${key}.pub"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
STUB
  chmod +x "$stub_dir/github-keygen"
  export PATH="$stub_dir:$PATH"
  export BATS_TEST_TMPDIR
}

@test "zdots-github-keys: --help exits 0" {
  run "$BIN/zdots-github-keys" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"rotate-stage PROFILE"* ]]
}

@test "zdots-github-keys: plan requires explicit account names" {
  run "$BIN/zdots-github-keys" plan
  [ "$status" -eq 1 ]
  [[ "$output" == *"--home-user is required"* ]]
}

@test "zdots-github-keys: plan shows fixed aliases and exact command" {
  run "$BIN/zdots-github-keys" plan --home-user just3ws --work-user workacct --default home
  [ "$status" -eq 0 ]
  [[ "$output" == *"host_alias: home.github.com"* ]]
  [[ "$output" == *"key_file: $HOME/.ssh/id_home@github"* ]]
  [[ "$output" == *"host_alias: work.github.com"* ]]
  [[ "$output" == *"git@home.github.com:OWNER/REPO.git"* ]]
  [[ "$output" == *"github-keygen --offline home -i $HOME/.ssh/id_home@github"* ]]
  [[ "$output" == *"-d work -i $HOME/.ssh/id_work@github"* ]]
}

@test "zdots-github-keys: apply refuses mutation without --yes" {
  stub_github_keygen
  run "$BIN/zdots-github-keys" apply --home-user just3ws --work-user workacct
  [ "$status" -eq 1 ]
  [[ "$output" == *"rerun with --yes"* ]]
  [ ! -f "$BATS_TEST_TMPDIR/github-keygen-args" ]
}

@test "zdots-github-keys: apply invokes github-keygen offline for home and work" {
  stub_github_keygen
  run "$BIN/zdots-github-keys" apply --home-user just3ws --work-user workacct --default work --yes
  [ "$status" -eq 0 ]
  args="$(cat "$BATS_TEST_TMPDIR/github-keygen-args")"
  [[ "$args" == *"--offline home -i $HOME/.ssh/id_home@github"* ]]
  [[ "$args" == *"work -i $HOME/.ssh/id_work@github"* ]]
  [[ "$args" == *"-d"* ]]
  [ -f "$HOME/.ssh/id_home@github.pub" ]
  [ -f "$HOME/.ssh/id_work@github.pub" ]
  [[ "$output" == *"add this public key to GitHub account 'just3ws'"* ]]
  [[ "$output" == *"ssh -T work.github.com"* ]]
}

@test "zdots-github-keys: rotate-stage creates next alias only" {
  stub_github_keygen
  run "$BIN/zdots-github-keys" rotate-stage home --home-user just3ws --work-user workacct
  [ "$status" -eq 0 ]
  args="$(cat "$BATS_TEST_TMPDIR/github-keygen-args")"
  [[ "$args" == *"--offline home_next -i $HOME/.ssh/id_home@github.next"* ]]
  [[ "$args" != *" home -i $HOME/.ssh/id_home@github "* ]]
  [ -f "$HOME/.ssh/id_home@github.next.pub" ]
  [[ "$output" == *"host_alias: home_next.github.com"* ]]
}

@test "zdots-github-keys: rotate-promote requires staged key and --yes" {
  stub_github_keygen
  mkdir -p "$HOME/.ssh"
  printf 'PRIVATE\n' > "$HOME/.ssh/id_work@github.next"
  printf 'ssh-ed25519 AAAATEST\n' > "$HOME/.ssh/id_work@github.next.pub"

  run "$BIN/zdots-github-keys" rotate-promote work --home-user just3ws --work-user workacct
  [ "$status" -eq 1 ]
  [[ "$output" == *"rerun with --yes"* ]]

  run "$BIN/zdots-github-keys" rotate-promote work --home-user just3ws --work-user workacct --yes
  [ "$status" -eq 0 ]
  args="$(tail -n 1 "$BATS_TEST_TMPDIR/github-keygen-args")"
  [[ "$args" == *"--offline work -i $HOME/.ssh/id_work@github.next"* ]]
  [[ "$args" == *"work_next -r"* ]]
  [[ "$output" == *"ssh -T work.github.com"* ]]
}
