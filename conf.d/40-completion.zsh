fpath=(
  $ZDOTDIR/functions/enabled
  $ZDOTDIR/bin
  $HOMEBREW_PREFIX/share/zsh-completions
  $fpath
)
typeset -gU cdpath fignore fpath mailpath path

if [[ ${+functions[compdef]} -eq 0 ]]; then
  autoload -Uz compinit
  _zdots_compinit_args=()
  if [[ "${ZDOTS_COMPLETION_PERMISSIVE:-0}" == "1" ]]; then
    _zdots_compinit_args=(-i)
  fi
  _zdots_compdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
  if mkdir -p "${_zdots_compdump:h}" 2>/dev/null; then
    # Take the -C fast path (skip the fpath rescan + security audit) ONLY when
    # the dump is fresh (<24h, for upstream/brew completion churn) AND newer than
    # our own completion sources: the dir mtime (catches added/removed files) and
    # its newest file (catches edits). Otherwise rebuild — so a completion added
    # to functions/enabled registers on the next shell instead of waiting out a
    # 24h timer. bin/check does the heavy security validation.
    _zdots_comp_dir="$ZDOTDIR/functions/enabled"
    _zdots_comp_newest=("$_zdots_comp_dir"/*(.Nom[1]))
    if [[ -n "$_zdots_compdump"(#qN.m-1) \
          && "$_zdots_compdump" -nt "$_zdots_comp_dir" \
          && ( -z "${_zdots_comp_newest[1]:-}" || "$_zdots_compdump" -nt "${_zdots_comp_newest[1]}" ) ]]; then
      compinit "${_zdots_compinit_args[@]}" -C -d "$_zdots_compdump"
    else
      compinit "${_zdots_compinit_args[@]}" -d "$_zdots_compdump"
    fi
    unset _zdots_comp_dir _zdots_comp_newest
  else
    compinit "${_zdots_compinit_args[@]}"
  fi
  unset _zdots_compdump _zdots_compinit_args
fi

for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "${fn:t}"
done

# Every zdots command completes: commands without a dedicated _<cmd> get
# _gnu_generic (options parsed from --help). Docs-contract known gaps are left
# out: their "--help" is a real invocation, which TAB must never trigger.
if (( ${+functions[compdef]} )); then
  () {
    local f name gapfile="$ZDOTDIR/docs/generated/docs-contract-known-gaps.txt"
    local -a gaps
    [[ -r "$gapfile" ]] && gaps=(${${(M)${(f)"$(<$gapfile)"}:#[^#]*:*}%%:*})
    for f in "$ZDOTDIR"/bin/*(-.x); do
      name="${f:t}"
      [[ "$name" == *.(py|rb) || -n "${_comps[$name]:-}" ]] && continue
      (( ${gaps[(Ie)$name]} )) && continue
      compdef _gnu_generic "$name"
    done
  }
fi

autoload -Uz colors && colors
if [[ -n "${LS_COLORS:-}" ]]; then
  zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"
fi
