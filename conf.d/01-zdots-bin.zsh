# conf.d/01-zdots-bin.zsh — Add zdots/bin to PATH early (before phi-history hook).
# This ensures tools like zdots-phi-scrub are available during shell startup.

[[ -d "${ZDOTDIR}/bin" ]] && path=("${ZDOTDIR}/bin" "${(@)path:#${ZDOTDIR}/bin}")
