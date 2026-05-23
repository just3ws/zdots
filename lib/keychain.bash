#!/usr/bin/env bash
# lib/keychain.bash — macOS Keychain integration for zdots secrets.
#
# All secrets live under service "zdots" with account == variable name.
# On non-darwin, functions no-op cleanly so zdots runs everywhere.
#
# Usage:
#   zdots_keychain_get VARNAME         → stdout: secret value, exit 1 if missing
#   zdots_keychain_set VARNAME VALUE   → stores/updates entry
#   zdots_keychain_delete VARNAME      → removes entry
#   zdots_keychain_list                → list all zdots entries (names only, no values)
#   zdots_keychain_load VAR [VAR ...]  → export each VAR from Keychain into environment

_ZDOTS_KEYCHAIN_SERVICE="zdots"

zdots_keychain_get() {
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || return 1
  local account="${1:?zdots_keychain_get: account required}"
  /usr/bin/security find-generic-password \
    -s "$_ZDOTS_KEYCHAIN_SERVICE" \
    -a "$account" \
    -w 2>/dev/null
}

zdots_keychain_set() {
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || return 0
  local account="${1:?zdots_keychain_set: account required}"
  local value="${2:?zdots_keychain_set: value required}"
  /usr/bin/security add-generic-password \
    -s "$_ZDOTS_KEYCHAIN_SERVICE" \
    -a "$account" \
    -w "$value" \
    -U 2>/dev/null
}

zdots_keychain_delete() {
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || return 0
  local account="${1:?zdots_keychain_delete: account required}"
  /usr/bin/security delete-generic-password \
    -s "$_ZDOTS_KEYCHAIN_SERVICE" \
    -a "$account" 2>/dev/null
}

zdots_keychain_list() {
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || return 0
  # 0x00000007 is kSecAttrService — appears before "acct" in each entry block
  /usr/bin/security dump-keychain 2>/dev/null | awk '
    /0x00000007 <blob>="zdots"/ { in_zdots=1; next }
    /"acct"<blob>=/ {
      if (in_zdots) {
        line=$0
        gsub(/^.*"acct"<blob>="/, "", line)
        gsub(/".*$/, "", line)
        if (line != "") print line
      }
      in_zdots=0
    }
  '
}

# zdots_keychain_load VAR [VAR ...] — export each variable from Keychain.
# Silently skips missing entries (var is left unset, not empty-exported).
zdots_keychain_load() {
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || return 0
  local var val
  for var in "$@"; do
    val=$(zdots_keychain_get "$var") && export "$var=$val"
  done
}
