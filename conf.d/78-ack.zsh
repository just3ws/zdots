# conf.d/78-ack.zsh — Interactive ack search helpers & shell ergonomics

if ! command -v ack >/dev/null 2>&1; then
  return 0
fi

# fack: Fuzzy Ack — interactive search via ack, fzf, and bat preview, jumping straight into nvim
fack() {
  local query="${*:-}"
  if [[ -z "$query" ]]; then
    printf "fack: interactive ack search\n"
    read -r "query?Search query: "
    [[ -z "$query" ]] && return 0
  fi

  local selected
  selected=$(ack -H --nogroup --column --smart-case --nocolor --nofilter "$query" 2>/dev/null | \
    fzf --delimiter : \
        --preview 'bat --style=numbers --color=always --highlight-line {2} {1} 2>/dev/null || cat {1}' \
        --preview-window '+{2}-/2' \
        --prompt "ack ($query)> ") || return 0

  if [[ -n "$selected" ]]; then
    local file line col
    file=$(cut -d: -f1 <<< "$selected")
    line=$(cut -d: -f2 <<< "$selected")
    col=$(cut -d: -f3 <<< "$selected")
    ${EDITOR:-nvim} "+call cursor($line, $col)" "$file"
  fi
}

# acke: Ack & Edit — runs ack and opens matches directly in Neovim's quickfix list
acke() {
  if [[ $# -eq 0 ]]; then
    printf "acke: usage: acke <ack-arguments-or-pattern>\n" >&2
    return 1
  fi
  local tmpfile
  tmpfile=$(mktemp -t acke-qf.XXXXXX) || return 1
  ack -H --nogroup --column --smart-case --nocolor --nofilter "$@" > "$tmpfile"
  if [[ ! -s "$tmpfile" ]]; then
    printf "acke: no matches found for: %s\n" "$*"
    rm -f "$tmpfile"
    return 0
  fi
  ${EDITOR:-nvim} -q "$tmpfile"
  rm -f "$tmpfile"
}

# ack-types: list custom file types and built-in ack types
ack-types() {
  ack --help-types
}
