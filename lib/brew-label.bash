# lib/brew-label.bash — Homebrew service launchd labels.
#
# Homebrew 7 registers services as sh.brew.<formula>; older releases used
# homebrew.mxcl.<formula>. Resolve whichever plist is installed (user agent or
# system daemon), preferring the current prefix, and default to it.
#
# ZDOTS_LAUNCHD_SYSTEM_DIR overrides /Library/LaunchDaemons (tests only).

zdots_brew_label() {
  local f="$1" d
  local -a dirs=("$HOME/Library/LaunchAgents" "${ZDOTS_LAUNCHD_SYSTEM_DIR:-/Library/LaunchDaemons}")
  for d in "${dirs[@]}"; do
    [[ -f "$d/sh.brew.$f.plist" ]] && { printf 'sh.brew.%s' "$f"; return; }
  done
  for d in "${dirs[@]}"; do
    [[ -f "$d/homebrew.mxcl.$f.plist" ]] && { printf 'homebrew.mxcl.%s' "$f"; return; }
  done
  printf 'sh.brew.%s' "$f"
}
