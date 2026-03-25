export MALLOC_ARENA_MAX=2
export RUBY_CONFIGURE_OPTS="--with-jemalloc --with-openssl-dir=$HOMEBREW_PREFIX/opt/openssl@3"
export CPPFLAGS="-I$HOMEBREW_PREFIX/opt/jemalloc/include -I$HOMEBREW_PREFIX/opt/openjdk/include"
export LDFLAGS="-L$HOMEBREW_PREFIX/opt/jemalloc/lib"
# export RUBYOPT='-W:no-deprecated -W:no-experimental'

export ANSIBLE_COW_SELECTION=random
export ANSIBLE_NOCOWS=1
export HOMEBREW_BAT=1

export CLICOLOR=1
if [[ "$ZDOTS_THEME" == "nord" ]]; then
  _zdots_theme_dircolors_file="${ZDOTDIR}/assets/nord/dir_colors"
fi

if [[ -r "${_zdots_theme_dircolors_file}" ]]; then
  if command -v gdircolors >/dev/null 2>&1; then
    eval "$(gdircolors -b "${_zdots_theme_dircolors_file}")"
  elif command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors -b "${_zdots_theme_dircolors_file}")"
  fi
elif command -v vivid >/dev/null 2>&1; then
  _zdots_lsc_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/ls_colors.${ZDOTS_THEME}"
  if [[ -r "$_zdots_lsc_cache" ]]; then
    export LS_COLORS="$(<"$_zdots_lsc_cache")"
  else
    _zdots_vivid_theme="$ZDOTS_THEME"
    [[ "$_zdots_vivid_theme" == dracula-* ]] && _zdots_vivid_theme="dracula"
    export LS_COLORS="$(vivid generate "$_zdots_vivid_theme")"
    mkdir -p "$_zdots_lsc_cache:h"
    echo "$LS_COLORS" > "$_zdots_lsc_cache"
    unset _zdots_vivid_theme
  fi
  unset _zdots_lsc_cache
fi
unset _zdots_theme_dircolors_file
export DISABLE_SPRING=true
export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'
export HYPHEN_INSENSITIVE=true
export KEYTIMEOUT=1
export WORDCHARS='-*?.[]~=&;!#$%^(){}<>@'

# Re-assert history settings after system zshrc defaults.
HISTFILE="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/history"
typeset -gi HISTSIZE=999999
typeset -gi SAVEHIST=999999

# Ensure history directory exists for reliable persistence.
mkdir -p "${HISTFILE:h}"

