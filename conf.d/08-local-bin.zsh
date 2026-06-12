# conf.d/08-local-bin.zsh — Add ./bin to PATH when in a directory that has one.
# Commands in a project's bin/ run without the ./bin/ prefix.
#
# The hook fires on directory change (chpwd). The previous local bin is removed
# before the new one is added so PATH never accumulates stale entries.

_zdots_local_bin_prev=""

_zdots_chpwd_local_bin() {
  local new_bin="$PWD/bin"
  # Remove the previous local bin if we've left that directory
  if [[ -n "$_zdots_local_bin_prev" && "$_zdots_local_bin_prev" != "$new_bin" ]]; then
    path=("${(@)path:#${_zdots_local_bin_prev}}")
  fi
  if [[ -d "$new_bin" ]]; then
    path=("$new_bin" "${(@)path:#${new_bin}}")
    _zdots_local_bin_prev="$new_bin"
  else
    _zdots_local_bin_prev=""
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _zdots_chpwd_local_bin
_zdots_chpwd_local_bin  # Prime for the shell's initial directory
