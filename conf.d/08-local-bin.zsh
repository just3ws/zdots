# conf.d/08-local-bin.zsh — Add ./bin to PATH when in a directory that has one.
# Commands in a project's bin/ run without the ./bin/ prefix.
#
# The hook fires on directory change (chpwd). It removes ONLY the entry it
# added last time, and never adopts a $PWD/bin that is already on PATH from
# somewhere else (env.sh §9c, .zshrc.local — e.g. ~/.config/nvim/bin). Those
# stay put when you leave the repo. See Z-338 for the eviction bug this fixes.

_zdots_local_bin_added=""   # the entry THIS hook prepended; "" when none

_zdots_chpwd_local_bin() {
  local new_bin="$PWD/bin"

  # Drop the entry we added on the previous cd, if we've moved off it.
  if [[ -n "$_zdots_local_bin_added" && "$_zdots_local_bin_added" != "$new_bin" ]]; then
    path=("${(@)path:#${_zdots_local_bin_added}}")
    _zdots_local_bin_added=""
  fi

  [[ -d "$new_bin" ]] || return

  # Already on PATH — either ours from a prior cd into here, or a "sticky"
  # dir something else put on permanently. Either way, don't touch it.
  (( ${path[(Ie)$new_bin]} )) && return

  path=("$new_bin" $path)
  _zdots_local_bin_added="$new_bin"
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _zdots_chpwd_local_bin

# Prime once, after the rest of init (conf.d + .zshrc.local) has finished
# building PATH — so a shell started inside a repo whose ./bin is also a
# sticky PATH entry doesn't adopt (and later evict) it.
_zdots_prime_local_bin() {
  add-zsh-hook -d precmd _zdots_prime_local_bin
  _zdots_chpwd_local_bin
}
add-zsh-hook precmd _zdots_prime_local_bin
