#!/usr/bin/env bash
# lib/sdk/cli-help.bash — Tenant CLI SDK: header-driven --help before side effects (Z-185, ADR-0005).
#
# Bash- and Zsh-compatible. Source after `set -euo pipefail`:
#   source "${ZDOTDIR:-$HOME/.config/zsh}/lib/sdk/cli-help.bash"
#   zdots_cli_wants_help "$@" && { zdots_sdk_help_from_header "$0"; exit 0; }

_zdots_sdk_dir="${ZDOTDIR:-$HOME/.config/zsh}"
if [ -r "$_zdots_sdk_dir/lib/cli-help.bash" ]; then
  # shellcheck source=/dev/null
  . "$_zdots_sdk_dir/lib/cli-help.bash"
fi
unset _zdots_sdk_dir

# Print the leading `# ...` comment block from a script (after the shebang),
# stripping the leading `# ` prefix. Stops at the first non-comment line.
zdots_sdk_help_from_header() {
  local script="${1:-$0}"
  [ -r "$script" ] || return 1
  awk '
    NR == 1 && /^#!/ { next }
    /^#[[:space:]]?/ {
      sub(/^# ?/, "")
      print
      started = 1
      next
    }
    started { exit }
    /^[[:space:]]*$/ { next }
    { exit }
  ' "$script"
}
