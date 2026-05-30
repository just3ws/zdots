# ruby-audit — Static Analysis Suite for Ruby/Rails Codebases

## What it does

`ruby-audit <directory>` runs six static analysis tools against any Ruby or
Rails project directory and produces three outputs:

- **`report.md`** — human-readable findings, one section per tool
- **`summary.json`** — machine-readable scores for automation
- **`context.md`** — AI-ready brief (findings + metrics) for LLM interrogation

The analyzed codebase never needs to run. No target gems are installed. The
tool runs from zdots' own mise-pinned Ruby 4.0.2 against any target directory,
including source extracted from a container with `docker cp`.

```
ruby-audit /path/to/any/ruby/app [--ruby 2.6] [--rails 5.2] [--out ./report]
```

---

## Current architecture

```
bin/ruby-audit            Entry point (Ruby script, not bash)
lib/ruby_audit/
  detector.rb             Version detection: Gemfile.lock → .ruby-version → Gemfile
  runners.rb              Six analyzer runners, each returning { ok:, output:, raw: }
  report_builder.rb       Markdown + JSON + AI context writer
etc/ruby-audit/
  prompts/                Version-specific LLM system prompts
    ruby-2.6.md           Language constraints, EOL callouts, upgrade path
    ruby-4.0.md           Current Ruby features, security patterns
    rails-5.2.md          Framework orientation, security patterns, upgrade notes
```

### Isolation model

zdots' Ruby (mise, `~/.local/share/mise/installs/ruby/4.0.2/`) runs all
analyzers. The target project's Ruby version is only used as a configuration
signal (`TargetRubyVersion` for RuboCop, `--rails5` for Brakeman). The target
bundle is never installed.

For targets that truly require their runtime (e.g. running the app's own
tests): `mise exec ruby@2.6 -- <command>` provides a clean isolated runtime
without touching the system Ruby or the target bundle.

---

## Design gap: it is not yet modular

The current tool works but has hardcoded assumptions:

- Analyzer set is fixed (all six, or CLI `--skip`/`--only`)
- RuboCop config is a single generated file with hardcoded cop list
- Version prompts cover only the versions encountered so far
- No database awareness
- LLM backend is hardcoded to Pi (`zpi`) via `--interrogate`
- No profile system — you can't say "Rails 5.2 + MariaDB + Sidekiq" and get
  the right rule set automatically

The next phase redesigns around three composable primitives:
**Profiles**, **Rule Packs**, and **Backends**.

---

## Proposed modular architecture

### Mental model: RuboCop as the reference

RuboCop analyzes Ruby 2.x code from a Ruby 3.x host because it separates
*what version to target* from *what runtime to use*. It loads departments
(cops) based on version constraints and configuration. `ruby-audit` should work
the same way at a higher level: the stack description drives which rules and
analyzers are activated, independently of what Ruby is installed locally.

```
ruby-audit /path/to/app
  └── Detector        reads Gemfile.lock → builds stack description
  └── ProfileLoader   maps stack → Profile (or auto-selects closest match)
  └── Profile         declares which Analyzers + RulePacks are active
        ├── Analyzers  bundler-audit, brakeman, rubocop, reek, flog, flay, custom...
        └── RulePacks  ruby/2.6, rails/5.2, db/postgresql, security/common...
  └── ReportBuilder   normalizes all output → report.md / summary.json / context.md
  └── Backend         packages context → sends to Pi / OpenCode / Claude / local LLM
```

---

### Primitive 1: Profiles

A profile declares the full analysis configuration for a known stack. Profiles
compose via inheritance so common rules are defined once.

```yaml
# etc/ruby-audit/profiles/rails-5.2-postgresql.yml
name: rails-5.2-postgresql
inherits:
  - base/ruby-2.6
  - base/rails-5.2
  - base/db-postgresql
description: "Rails 5.2 on Ruby 2.6, PostgreSQL backend"

analyzers:
  bundler-audit: true
  brakeman:
    flags: [--rails5]
  rubocop:
    config: etc/ruby-audit/rubocop/rails-5.2.yml
  reek: true
  flog:
    threshold: 25          # lower threshold for older codebases
  flay: true

rule_packs:
  - ruby/2.6/language
  - ruby/2.6/security
  - rails/5.2/security
  - rails/5.2/patterns
  - rails/5.2/upgrade-path
  - db/postgresql/n-plus-one
  - db/postgresql/schema
  - db/postgresql/jsonb
  - security/common
```

```yaml
# etc/ruby-audit/profiles/rails-7.1-mariadb.yml
name: rails-7.1-mariadb
inherits:
  - base/ruby-3.2
  - base/rails-7.1
  - base/db-mariadb

rule_packs:
  - ruby/3.x/language
  - rails/7.x/hotwire
  - rails/7.x/turbo
  - db/mariadb/charset
  - db/mariadb/json-vs-text
  - db/mariadb/group-by
  - security/common
```

Auto-detection: if no `--profile` is given, the Detector builds a stack
description and `ProfileLoader` selects the closest matching profile by
version range. Unmatched versions fall back to `base/ruby-unknown` + whatever
framework is detected.

Manual override:
```bash
ruby-audit /path/to/app --profile rails-5.2-mariadb
ruby-audit /path/to/app --ruby 2.6 --rails 5.2 --db mariadb   # builds profile inline
```

---

### Primitive 2: Rule Packs

A rule pack is a directory of Markdown files with structured frontmatter. Rule
packs are the LLM system prompt ingredients — they tell the model what to look
for in a given context.

```
etc/ruby-audit/rules/
  ruby/
    2.6/
      language.md       # what doesn't exist, common patterns, EOL callouts
      security.md       # version-specific security patterns
      upgrade-path.md   # 2.6→3.x migration guide for the LLM
    3.x/
      language.md
      security.md
    4.0/
      language.md
  rails/
    5.2/
      security.md       # mass assignment, SQLi, XSS, serialization
      patterns.md       # auth gaps, service objects, fat models
      upgrade-path.md   # 5.2→6.0 breaking changes
    6.x/
      ...
    7.x/
      hotwire.md        # Turbo, Stimulus patterns
      upgrade-path.md
  db/
    postgresql/
      n-plus-one.md     # ActiveRecord N+1 patterns to look for
      schema.md         # missing indexes, counter caches, FK constraints
      jsonb.md          # jsonb vs json vs text, operators, indexes
    mariadb/
      charset.md        # utf8 vs utf8mb4 landmines
      json-vs-text.md   # JSON column limitations
      group-by.md       # ONLY_FULL_GROUP_BY gotchas
    sqlite/
      concurrency.md    # no concurrent writes
  security/
    common.md           # eval, Marshal.load, YAML.load, open(), send()
    phi.md              # PHI-specific: logging, serialization, audit trails
```

Each rule pack file has frontmatter:
```yaml
---
id: rails-5.2-mass-assignment
applies_to:
  rails: "~> 5.2"
severity: high
category: security
tags: [mass-assignment, strong-parameters]
---
```

The `ReportBuilder` concatenates relevant rule packs into the system prompt,
ordered by: security → framework → db → language → style.

---

### Primitive 3: Backends

A backend is anything that can receive `(system_prompt, codebase_context,
optional_query)` and return analysis. Each backend is a thin adapter with a
common interface.

```
etc/ruby-audit/backends.yml     # describes available backends
lib/ruby_audit/backends/
  pi.rb                         # zpi CLI integration
  claude.rb                     # Claude API via ruby_llm
  opencode.rb                   # opencode CLI
  local_llm.rb                  # direct HTTP to zsvc llama-server
  none.rb                       # write context.md only, no LLM
```

Backend selection:
```bash
ruby-audit /path/to/app --interrogate --llm pi        # local Pi (default)
ruby-audit /path/to/app --interrogate --llm claude    # frontier via API
ruby-audit /path/to/app --interrogate --llm opencode  # OpenCode CLI
ruby-audit /path/to/app --interrogate --llm local     # local llama-server
ruby-audit /path/to/app                               # no interrogation; write context.md only
```

The backends file:
```yaml
# etc/ruby-audit/backends.yml
backends:
  pi:
    type: cli
    command: zpi
    context_flag: --context
    phi_safe: true             # local, no data leaves the machine
  claude:
    type: api
    gem: ruby_llm
    model: claude-opus-4-7
    phi_safe: false            # data leaves the machine — PHI warning
  opencode:
    type: cli
    command: opencode
    context_flag: --context
    phi_safe: false
  local:
    type: http
    endpoint: "${ZDOTS_AI_ENDPOINT}"
    phi_safe: true
```

PHI safety is surfaced as a warning when a non-local backend is selected and
the target directory contains `ZDOTS_CONTEXT=work` patterns or PHI-adjacent
paths (`app/models/patient`, `patient_record`, `encounter`, etc.).

---

### Database-aware analysis

The DB backend adds two layers beyond what the framework analyzers see:

**Static (schema-level):**
- Parse `db/schema.rb` or `db/structure.sql` for:
  - Foreign keys without indexes
  - Large `text` columns that should be `jsonb` (PostgreSQL)
  - Missing counter cache declarations
  - Polymorphic `*_type`/`*_id` pairs without composite indexes
  - `null: false` columns without database-level defaults
  - Charset/collation declarations (MariaDB: utf8 vs utf8mb4)

**Static (ActiveRecord call-site level):**
- N+1 detection: `find` / `where` inside loops, missing `.includes`
- `pluck` vs `select` vs loading full objects
- `count` vs `size` vs `length` semantics
- Unscoped queries in multi-tenant code

**Semi-dynamic (log analysis):**
```bash
ruby-audit /path/to/app --slow-query-log /var/log/mysql/slow.log
ruby-audit /path/to/app --pg-log /var/log/postgresql/postgresql.log
```
Parses the log for the top-N slow queries, cross-references them against the
schema and model call sites, and includes the correlation in the report.

---

### Rollout plan

Phase 1 (now): the current tool — six analyzers, version detection, three
version prompts, Pi interrogation. Good enough for initial use.

Phase 2: Profile system. Define base profiles for the combinations in use
(ruby-2.6-rails-5.2-postgresql, ruby-4.0-plain). ProfileLoader selects by
detected versions. No code change to the analyzers — just the dispatch layer.

Phase 3: Rule pack system. Split the current monolithic version prompt files
into individual rule pack files with frontmatter. `ReportBuilder` concatenates
them per profile. This makes adding a new DB or Rails version a file addition,
not a code change.

Phase 4: Backend abstraction. Thin adapters for Pi, Claude, OpenCode, local
llama-server. Backend selection via `--llm` flag. PHI-safety gate when using
remote backends.

Phase 5: DB-aware analysis. Schema parser + ActiveRecord call-site scanner as
a new analyzer module. Slow query log ingestion as an optional input.

---

## Usage reference

```bash
# Basic — auto-detects versions, runs all analyzers, no LLM
ruby-audit /path/to/app

# Override detected versions
ruby-audit /path/to/app --ruby 2.6 --rails 5.2

# Specify output location
ruby-audit /path/to/app --out ./audit-$(date +%Y%m%d)

# Skip slow tools for fast feedback
ruby-audit /path/to/app --skip flog --skip flay --no-repomix

# Run a single tool only
ruby-audit /path/to/app --only brakeman

# Interrogate with local Pi (after report)
ruby-audit /path/to/app --interrogate

# From a containerized app (extract source first)
docker cp myapp:/app ./extracted-app
ruby-audit ./extracted-app --ruby 2.6 --rails 5.2
```

## Output locations

Reports land in `~/.local/state/zsh/ruby-audits/<repo-slug>-<timestamp>/`:

| File | Content |
|------|---------|
| `report.md` | Full Markdown report, one section per analyzer |
| `summary.json` | Scores: CVE count, Brakeman counts, offense/smell/hotspot counts |
| `context.md` | AI-ready analysis brief for LLM interrogation |
| `repomix-context.md` | Full codebase pack (requires `repomix` in PATH) |
| `system-prompt.md` | Assembled version-specific rules injected as LLM context |

## Adding a new version prompt

Drop a Markdown file in `etc/ruby-audit/prompts/`:
- `ruby-3.3.md` — picked up automatically for Ruby 3.3.x targets
- `rails-6.1.md` — picked up automatically for Rails 6.1.x targets

No code change required. Naming convention: `ruby-X.Y.md`, `rails-X.Y.md`.
