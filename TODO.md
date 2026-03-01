# TODO

## P0 (Highest)

- [x] Fix `asdf` loading behavior in interactive shells.
  - Switched from lazy wrapper to explicit `asdf.sh` initialization.
  - Added regression check in `bin/check` (`asdf --version` in interactive shell).

## P1

- [ ] Add explicit `compinit` cache setup.
  - Use `compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"` for predictable completion cache behavior.
  - Add cache reset guidance for troubleshooting.

- [ ] Add a `Makefile` for common workflows.
  - Targets: `bootstrap`, `check`, `bench`, `upgrade`.

- [ ] Add optional `shellcheck` pass to `bin/check`.
  - Run only when `shellcheck` exists.

- [ ] Add prompt health check to `bin/check`.
  - Verify at least one Powerlevel10k theme candidate is present.

## P2

- [ ] Review `upgrade-asdf` version strategy.
  - Replace broad `latest` installs with explicit stable version pins where needed.

- [ ] Trim alias surface area over time.
  - Keep frequently used aliases in `.aliasrc`.
  - Move low-usage aliases into an archived file.

- [ ] Add recovery/troubleshooting doc section.
  - Include startup failure workflow (`zsh -f`, disable a module, run `bin/check`).
