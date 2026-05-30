# Ruby 4.0 Analysis Context

Ruby 4.0 is current (released 2026). Active development; security patches are current.

## Key language features available

- Pattern matching stable and idiomatic (`case/in`, `deconstruct`, `deconstruct_keys`)
- Numbered block parameters (`_1`, `_2`)
- Endless methods (`def foo = expr`)
- `Hash#except`, `Hash#transform_keys`
- `Enumerator::Product`, `Enumerator::Chain`
- `Fiber::Scheduler` (concurrency primitive)
- YJIT enabled by default
- `Data.define` for immutable value objects (3.2+)
- `Struct` keyword init (`Struct.new(:a, :b, keyword_init: true)`)
- No more `$PROGRAM_NAME` as `__FILE__` alias nuance

## Breaking changes from 3.x to watch for

- Keyword argument separation fully enforced (no implicit hash→kwargs conversion)
- `Proc` argument forwarding semantics tightened
- Some `ObjectSpace` and `GC` APIs changed
- `Integer#[]` with range returns a value (not an array) — behavior change
- Frozen string literals may become default — check `# frozen_string_literal: true` usage

## Security patterns

- `eval` family — always flag, no exceptions
- `send` / `public_send` with user-controlled input
- `YAML.load` without `permitted_classes:` argument — safe_load or Psych 4+ defaults
- Shell injection: backticks, `system`, `%x{}`, `IO.popen` with user input
- `Kernel#open` with URL-like strings — can invoke shell via `|` prefix
- Regex: `\A`/`\Z` vs `^`/`$` for full-string matching in validators
