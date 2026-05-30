# Ruby 2.6 Analysis Context

Ruby 2.6 reached end-of-life March 2022. Code running on this version cannot receive
security patches. Flag this prominently in any assessment.

## Language constraints (things that do NOT exist in 2.6)

- No numbered block parameters (`_1`, `_2`) — added in 2.7
- No pattern matching (`case/in`) — added in 2.7 (experimental), 3.0 (stable)
- No `then` in one-line pattern matching — not applicable
- No `Hash#except` — added in 3.0; look for manual key deletion workarounds
- No `Enumerator::Chain` chaining with `+` — added in 2.6 actually (ok)
- No `endless method` (`def foo = expr`) — added in 3.0
- No `Hash#transform_keys!` — added in 2.5 (ok)
- `Proc#>>` and `Proc#<<` composition — added in 2.6 (ok)
- `Array#union`, `Array#difference` — added in 2.7; look for `|` and `-` instead
- No `Integer#[]` with range argument — added in 2.7
- Frozen string literals pragma respected but not default
- `Enumerable#tally` — added in 2.7; look for `group_by.transform_values(&:count)` patterns
- `Comparable#clamp` with range — added in 2.7; only scalar clamp in 2.6

## Common 2.6 patterns to recognize

- `Proc` vs `lambda` semantics matters — watch for `&method(:foo)` patterns
- `rescue` in blocks without `begin` is valid (added 2.5)
- `yield_self` (2.5) is the predecessor to `then` (2.6) — both present
- `RubyVM::AbstractSyntaxTree` available but unstable API
- Hash ordering is insertion-ordered (since 1.9, fine)

## Security considerations specific to 2.6

- No security patches since EOL — treat ALL CVEs in bundled gems seriously
- Ruby 2.6 stdlib includes older OpenSSL bindings — check `openssl` gem version
- `JSON.load` is dangerous in 2.6 (same as newer, but older Psych serialization exploits relevant)
- Default YAML deserialization was unsafe; look for `YAML.load` without `safe_load`
- `Marshal.load` from untrusted input is always dangerous — flag all occurrences
- Regex-based input validation is common at this era — look for ReDoS patterns
- `send` with user-controlled method names — common pattern in older Rails controllers

## Upgrade path notes

Upgrading 2.6 → 3.x requires: keyword argument separation (2.7 warning, 3.0 error),
pattern matching adaptation, `Hash#except` adoption, numbered block params optional refactor.
The 2.7 step is the critical compatibility gate — run with `$VERBOSE` to surface warnings.
