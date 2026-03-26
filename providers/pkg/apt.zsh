# providers/pkg/apt.zsh — APT implementation for the pkg-manager service

zdots_pkg_manager_init() {
  command -v apt-get >/dev/null || return 1
  export _ZDOTS_APT_INITIALIZED=1
}

zdots_pkg_manager_paths() {
  # Standard system paths
  return 0
}
