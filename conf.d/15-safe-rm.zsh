# conf.d/15-safe-rm.zsh — rm safety guard
#
# Wraps rm to block patterns that have historically destroyed home/config dirs.
# Blocking list: ~, $HOME, /, /*, /usr, /etc, /bin, /opt, /System.
# If trash(1) is available, 'del' is a non-destructive alternative.

rm() {
  local arg resolved
  for arg in "$@"; do
    # Skip flags
    [[ "$arg" == -* ]] && continue

    # Resolve to absolute path (handles ~, ., .., relative paths)
    if [[ "$arg" == '~' || "$arg" == "$HOME" || "$arg" == "$HOME/" ]]; then
      print -u2 "rm: BLOCKED — refusing to remove home directory: $arg"
      return 1
    fi

    # Expand to absolute
    resolved="${arg:A}"

    # Block the home directory itself
    if [[ "$resolved" == "$HOME" ]]; then
      print -u2 "rm: BLOCKED — refusing to remove home directory: $arg"
      return 1
    fi

    # Block filesystem roots and critical system paths
    local -a forbidden=(/ /usr /etc /bin /sbin /opt /System /Library /Applications)
    for f in "${forbidden[@]}"; do
      if [[ "$resolved" == "$f" ]]; then
        print -u2 "rm: BLOCKED — refusing to remove critical path: $arg ($resolved)"
        return 1
      fi
    done

    # Block wildcards that expand to include $HOME (e.g. rm -rf ~/*)
    if [[ "$arg" == "$HOME/"* && -z "${arg##$HOME/}" ]]; then
      print -u2 "rm: BLOCKED — refusing wildcard remove of home contents: $arg"
      return 1
    fi
  done

  command rm "$@"
}

# 'del' sends to macOS Trash instead of permanent deletion (requires trash CLI)
if command -v trash >/dev/null 2>&1; then
  alias del='trash'
elif [[ "$OSTYPE" == darwin* ]]; then
  function del {
    local f
    for f in "$@"; do
      osascript -e "tell application \"Finder\" to delete POSIX file \"${f:A}\"" >/dev/null 2>&1 \
        || { print -u2 "del: failed to trash: $f"; return 1; }
    done
  }
fi
