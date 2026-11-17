# lib/brewfile.bash — which Brewfile a host uses, and how to judge it.
#
# Shared by bin/check and bin/zdots-update-local so the check judges the same
# file the update installs from. A machine-local HOMEBREW_BUNDLE_FILE (e.g. a
# curated work Brewfile outside the repo) wins over Brewfile.<context>. A work
# host never upgrades, so outdated packages don't count as missing there.

# zdots_brewfile <repo-root> — print the Brewfile path for this host.
zdots_brewfile() {
  local root="$1" file
  case "${ZDOTS_CONTEXT:-home}" in
    work) file="$root/Brewfile.work" ;;
    *)    file="$root/Brewfile.home" ;;
  esac
  case "${HOMEBREW_BUNDLE_FILE:-}" in
    "" | "$root/Brewfile" | "$root/Brewfile.home" | "$root/Brewfile.work") ;;
    *) file="$HOMEBREW_BUNDLE_FILE" ;;
  esac
  printf '%s\n' "$file"
}

# zdots_brew_bundle_flags — extra `brew bundle` flags for this host.
zdots_brew_bundle_flags() {
  [[ "${ZDOTS_CONTEXT:-home}" == "work" ]] && printf '%s\n' "--no-upgrade"
  return 0
}
