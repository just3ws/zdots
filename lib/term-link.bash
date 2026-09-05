#!/usr/bin/env bash
# lib/term-link.bash — Terminal hyperlink helper (OSC 8)
#
# Generates clickable hyperlinks for modern terminal emulators supporting
# the OSC 8 escape sequence (iTerm2, Ghostty, WezTerm, Apple Terminal, VSCode, etc.).
# Degrades gracefully to plain text when not attached to a TTY or in dumb terminals.

term_supports_links() {
  [[ -t 1 && "${TERM:-}" != "dumb" && -z "${NO_COLOR:-}" ]]
}

# OSC 8 hyperlink: clickable in modern terminals, plain text elsewhere.
# shellcheck disable=SC1003 # \e\\ is the OSC-8 ST terminator, not a quote escape
term_link() {
  local url="$1"
  local text="${2:-$1}"
  if term_supports_links; then
    printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$url" "$text"
  else
    printf '%s' "$text"
  fi
}

term_file_link() {
  local path="$1"
  local text="${2:-$path}"
  term_link "file://${path}" "$text"
}

term_bus_channel_link() {
  local channel="$1"
  local text="${2:-$channel}"
  term_link "https://my.localhost/bus#${channel}" "$text"
}
