---
name: ruby-audit
scope: zdots command
audience: platform operators
---

# Ruby audit

`ruby-audit` runs a fixed set of static analyzers against a Ruby or Rails
checkout. The target bundle is not installed; the audit tools run from the
isolated `etc/ruby-audit/Gemfile`.

```bash
ruby-audit --setup                          # install the isolated analyzer bundle
ruby-audit ~/src/project                    # detect Ruby/Rails versions and run all analyzers
ruby-audit ~/src/project --only rubocop     # run one analyzer
ruby-audit ~/src/project --skip flog        # skip an analyzer
ruby-audit ~/src/project --ruby 4.0 --rails 8.1
ruby-audit ~/src/project --no-repomix --no-slices
ruby-audit ~/src/project --interrogate      # explicitly launch Pi with the audit context
```

Supported analyzers: `bundler-audit`, `brakeman`, `rubocop`, `reek`, `flog`,
and `flay`. Version detection reads the target's lockfile and runtime markers;
`--ruby` and `--rails` override detection.

## Output

By default, each run writes to
`${XDG_STATE_HOME:-~/.local/state}/zsh/ruby-audits/<project>-<timestamp>/`.
Use `--out DIR` to choose another directory. Outputs include:

- `report.md`, `summary.json`, and `dashboard.txt` — findings and scores
- `context.md` and `system-prompt.md` — concise model context and detected rules
- `repomix-context.md` — selected source files, when Repomix is installed
- `slices/` — token-budgeted Pi context files, unless `--no-slices` is set

`--interrogate` is opt-in and starts Pi with a combined context brief. It uses
Pi's configured route; the platform default is local inference.

Related commands: `ruby-audit-diff` compares two reports, `ruby-audit-batch`
runs audits over a list of projects, and `zmetrics` shows score history.
Use each command's `--help` as the live interface contract.
