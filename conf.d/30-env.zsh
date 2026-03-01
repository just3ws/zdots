export MALLOC_ARENA_MAX=2
export RUBY_CONFIGURE_OPTS="--with-jemalloc=$HOMEBREW_PREFIX/opt/jemalloc --with-openssl-dir=$HOMEBREW_PREFIX/opt/openssl@3"
# export RUBYOPT='-W:no-deprecated -W:no-experimental'

export ANSIBLE_COW_SELECTION=random
export ANSIBLE_NOCOWS=1

export CLICOLOR=1
_zdots_nord_dircolors_file="${ZDOTDIR}/assets/nord/dir_colors"
if [[ -r "${_zdots_nord_dircolors_file}" ]]; then
  if command -v gdircolors >/dev/null 2>&1; then
    eval "$(gdircolors -b "${_zdots_nord_dircolors_file}")"
  elif command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b "${_zdots_nord_dircolors_file}")"
  fi
elif command -v vivid >/dev/null 2>&1; then
  export LS_COLORS="$(vivid generate nord)"
fi
unset _zdots_nord_dircolors_file
export DISABLE_SPRING=true
export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'
export HYPHEN_INSENSITIVE=true
export KEYTIMEOUT=1
export WORDCHARS='-*?.[]~=&;!#$%^(){}<>@'

# Ensure history directory exists for reliable persistence.
mkdir -p "${HISTFILE:h}"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
