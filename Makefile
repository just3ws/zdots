# Zdots - Agent & System Management Makefile
SHELL := /bin/zsh
ZDOTDIR ?= $(HOME)/.config/zsh

.PHONY: bootstrap check check-fast bench upgrade upgrade-dry map search refactor context tags stats ci-up ci-down ci-status ci-run ci-clean

# ------------------------------------------------------------------------------
# CORE & VALIDATION
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# LOCAL CI (Colima + act)
# ------------------------------------------------------------------------------
ci-up:
	$(ZDOTDIR)/bin/local-ci up

ci-down:
	$(ZDOTDIR)/bin/local-ci down

ci-status:
	$(ZDOTDIR)/bin/local-ci status

ci-run:
	$(ZDOTDIR)/bin/local-ci run $(ARGS)

ci-clean:
	$(ZDOTDIR)/bin/local-ci clean

upgrade:

	ZDOTDIR="$(ZDOTDIR)" zsh -i -c upgrade

upgrade-dry:
	ZDOTDIR="$(ZDOTDIR)" ZDOTS_UPGRADE_DRY_RUN=1 zsh -i -c upgrade

# ------------------------------------------------------------------------------
# AGENT API (Standardized entry points for AI interactions)
# ------------------------------------------------------------------------------

# High-signal directory map (ignores noise)
map:
	@eza --tree --level=2 --icons --group-directories-first --ignore-glob=".git|node_modules|.iterm2"

# Project stats (languages, LOC)
stats:
	@tokei

# Structural search (requires sg/ast-grep)
search:
	@if [ -z "$(QUERY)" ]; then echo "Usage: make search QUERY='pattern'"; exit 1; fi
	@sg -p "$(QUERY)"

# Safe find-and-replace (requires sd)
# Usage: make refactor OLD='foo' NEW='bar'
refactor:
	@if [ -z "$(OLD)" ] || [ -z "$(NEW)" ]; then echo "Usage: make refactor OLD='foo' NEW='bar'"; exit 1; fi
	@fd -t f -X sd "$(OLD)" "$(NEW)"

# High-density context packing for LLM (requires repomix)
context:
	@repomix --output .project-context.md --ignore ".git,node_modules,assets,.iterm2"
	@echo "Context packed to .project-context.md"

# Symbol indexing
tags:
	@ctags -R --exclude=.git --exclude=node_modules .
	@echo "Tags file generated"
