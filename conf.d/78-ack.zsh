# conf.d/78-ack.zsh — Interactive ack search helpers & shell ergonomics

if ! command -v ack >/dev/null 2>&1; then
  return 0
fi

# fack: Fuzzy Ack — live interactive search via ack, fzf, and bat preview, jumping straight into nvim
fack() {
  local initial_query="${*:-}"
  local ack_cmd='[[ -n {q} ]] && ack -H --nogroup --column --smart-case --nocolor --nofilter {q} || true'
  local selected

  if [[ -n "$initial_query" ]]; then
    ack_cmd="ack -H --nogroup --column --smart-case --nocolor --nofilter {q}"
  fi

  selected=$(fzf --disabled --query "$initial_query" \
      --bind "start:reload:$ack_cmd" \
      --bind "change:reload:$ack_cmd" \
      --delimiter : \
      --preview 'bat --style=numbers --color=always --highlight-line {2} {1} 2>/dev/null || cat {1}' \
      --preview-window '+{2}-/2' \
      --header 'Enter: edit | Ctrl-Y: copy path | Esc: quit' \
      --prompt "ack> ") || return 0

  if [[ -n "$selected" ]]; then
    local file line col
    file=$(cut -d: -f1 <<< "$selected")
    line=$(cut -d: -f2 <<< "$selected")
    col=$(cut -d: -f3 <<< "$selected")
    ${EDITOR:-nvim} "+call cursor($line, $col)" "$file"
  fi
}

# fackf: Fuzzy Ack Files — find files indexed by ack (.ackrc rules) via fzf
fackf() {
  local selected
  selected=$(ack -f 2>/dev/null | fzf \
    --preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}' \
    --preview-window 'right:60%' \
    --header 'Enter: edit | Esc: quit' \
    --prompt "ack-files> ") || return 0

  if [[ -n "$selected" ]]; then
    ${EDITOR:-nvim} "$selected"
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

# ZLE Widget: Ctrl-X Ctrl-A invokes interactive live fack
if [[ -o interactive ]] && (( ${+widgets} )); then
  fack-widget() {
    fack
    zle reset-prompt
  }
  zle -N fack-widget
  bindkey '^X^A' fack-widget
  bindkey -M emacs '^X^A' fack-widget
  bindkey -M viins '^X^A' fack-widget
  bindkey -M vicmd '^X^A' fack-widget
fi
