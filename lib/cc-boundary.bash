# lib/cc-boundary.bash — work-data boundary checks (shared by cc-doctor + zdots-doctor).
#
# The recurring leak: Claude Code per-project memory (~/.claude/projects/) was
# swept into the $HOME-tracked repo (adots — bare ~/.homegit, work-tree $HOME)
# by a broad `git add`, publishing work-confidential content on a public repo.
# The DURABLE guard is the tracked $HOME/.gitignore (it travels on every clone);
# these checks catch drift. Disk residue is NOT a leak (untracked+ignored files
# reach no remote) but is surfaced as hygiene.
#
# Single source of truth so the two doctors can't diverge (cf. PHI-scrubber
# ADR-0002). Emits findings via the caller's _pass/_warn/_fail/_fix helpers —
# both doctors define them. The caller prints the section header. Safe under -e.

zdots_cc_boundary_check() {
  if [[ -d "$HOME/.homegit" ]]; then
    local _hg=(--git-dir="$HOME/.homegit")
    # 1. the actual leak vector: adots must not TRACK CC memory
    if [[ -z "$(git "${_hg[@]}" ls-files -- '.claude/projects/' 2>/dev/null | head -1)" ]]; then
      _pass "adots tracks no .claude/projects/ (CC memory out of git)"
    else
      _fail "adots is TRACKING .claude/projects/ — CC memory in git (active leak vector)"
      _fix "git --git-dir=\$HOME/.homegit rm -r --cached .claude/projects/ && commit"
    fi
    # 2. the portable guard: the ignore entry travels on clone/pull
    if git "${_hg[@]}" cat-file -p main:.gitignore 2>/dev/null | grep -q '^\.claude/projects/'; then
      _pass "adots .gitignore ignores .claude/projects/ (guard travels on clone)"
    else
      _fail ".claude/projects/ missing from adots tracked .gitignore (the portable guard)"
      _fix "add '.claude/projects/' to \$HOME/.gitignore and commit it"
    fi
    # 3. the $HOME-tracked repo must be private
    if command -v gh >/dev/null 2>&1; then
      case "$(gh repo view just3ws/adots --json visibility -q .visibility 2>/dev/null)" in
        PRIVATE) _pass "adots repo is private" ;;
        PUBLIC)  _fail "adots (\$HOME-tracked) is PUBLIC — work-data exposure risk"
                 _fix "gh repo edit just3ws/adots --visibility private" ;;
        *)       _warn "adots visibility undetermined (gh unauthed?) — verify it is private" ;;
      esac
    fi
  else
    _warn "no \$HOME/.homegit — adots (home-dir repo) not found; skipping boundary checks"
  fi

  # 4. best-effort hygiene: another machine's CC memory on this box. Not a leak,
  # but worth surfacing. Foreign = project dir keyed to a user other than $USER
  # whose first path token doesn't resolve under $HOME (home=mike / work=mike.hall).
  local _uenc="${USER//./-}" _foreign="" _p _b _rest _tok
  for _p in "$HOME/.claude/projects/"-Users-*/; do
    [[ -d "$_p" ]] || continue
    _b="$(basename "$_p")"; _rest="${_b#-Users-"${_uenc}"}"
    [[ "$_rest" == "$_b" ]] && { _foreign+="$_b "; continue; }   # different user entirely
    [[ -z "$_rest" ]] && continue                                 # exactly $USER home root
    _tok="$(printf '%s' "$_rest" | sed -E 's/^-+//; s/-.*//')"
    compgen -G "$HOME/${_tok}*" >/dev/null 2>&1 || compgen -G "$HOME/.${_tok}*" >/dev/null 2>&1 || _foreign+="$_b "
  done
  if [[ -n "$_foreign" ]]; then
    _warn "foreign/stale CC-memory dir(s) on disk (another machine's user): $_foreign"
    _fix "verify then remove the exact path(s): rm -rf \$HOME/.claude/projects/<dir>"
  else
    _pass "no foreign-user CC memory on disk"
  fi
}
