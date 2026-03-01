SHELL := /bin/zsh
ZDOTDIR ?= $(HOME)/.config/zsh

.PHONY: bootstrap check check-fast bench upgrade upgrade-dry

bootstrap:
	$(ZDOTDIR)/bin/bootstrap

check:
	$(ZDOTDIR)/bin/check

check-fast:
	ZDOTS_CHECK_SKIP_EXTERNAL=1 $(ZDOTDIR)/bin/check

bench:
	@for i in 1 2 3 4 5; do \
		echo "run $$i"; \
		/usr/bin/time -p env ZDOTDIR="$(ZDOTDIR)" HOME="$(HOME)" zsh -i -c exit >/dev/null; \
	done

upgrade:
	ZDOTDIR="$(ZDOTDIR)" zsh -i -c upgrade

upgrade-dry:
	ZDOTDIR="$(ZDOTDIR)" ZDOTS_UPGRADE_DRY_RUN=1 zsh -i -c upgrade
