# lib/adots.bash — keep the adots bare clone (~/.homegit) in step with GitHub.
#
# `git clone --bare` writes no fetch rule, so origin/main stays wherever it was
# at clone time and later fetches never move it. Comparing against that stale
# ref shows files as missing, and `reset --hard origin/main` would roll $HOME
# back. bin/bootstrap calls this after cloning; it is safe on an existing clone.

# adots_ensure_fetch_rule <git-dir> — add the standard fetch rule unless one
# exists, fetch, and make main track origin/main. Never touches the work tree.
adots_ensure_fetch_rule() {
  local gd="$1"
  git --git-dir="$gd" config --get remote.origin.fetch >/dev/null 2>&1 ||
    git --git-dir="$gd" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git --git-dir="$gd" fetch --quiet --prune origin || return
  git --git-dir="$gd" config branch.main.remote origin
  git --git-dir="$gd" config branch.main.merge refs/heads/main
}
