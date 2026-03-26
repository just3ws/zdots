# Interface: Homebrew / Package Manager
# Depends on zdots_pkg_manager_init provided by the active pkg-manager service.

if [[ -n "$(command -v zdots_pkg_manager_init)" ]]; then
  if [[ -z "${_ZDOTS_BREW_INITIALIZED:-}" ]]; then
    zdots_pkg_manager_init
  fi
fi
