# Testing Strategy

Zdots uses a multi-tier testing strategy to ensure shell stability and contract reliability.

## 1. Automated Checks

```sh
make check       # Runs all fast checks and tests
make check-fast  # Shellcheck and sanity checks (no external dependencies)
```

## 2. Unit Testing (Bats-core)

We use `bats-core` for shell unit testing. Tests are located in `tests/`.

| Test File | Scope |
|---|---|
| `tests/env_posix.bats` | Ensures POSIX compliance of bootstrap scripts. |
| `tests/observability.bats` | Validates OTel span rotation and trace headers. |
| `tests/metadata.bats` | Tests the unified metadata service. |
| `tests/lifecycle.bats` | Tests service lifecycle primitives. |

Run specific tests:
```sh
bats tests/metadata.bats
```

## 3. Ruby Unit Testing (RSpec)

Ruby infrastructure (AI pipeline, PHI scrubber, encryption) is covered by an RSpec suite in `spec/`. All specs run isolated — no database or AI server required. Integration specs are tagged `:integration` and excluded by default.

```sh
zdots-ruby -S rspec                  # all unit specs (fast, no services)
zdots-ruby -S rspec --tag integration  # integration specs (requires live DB)
```

The suite runs in CI on every push and PR via the `ruby` job in `check.yml`. Use `zdots-ruby` (not the ambient `ruby`) so the specs always run on the pinned version from `etc/ruby-version`.

## 4. Integration Testing (RubyLLM × llama.cpp)

End-to-end validation of the AI stack (chat, embeddings, tool use). Requires a running llama.cpp server (`zdots-ctl up`).

```sh
zdots-ruby tests/llama_integration.rb --quick  # fast: health + chat
zdots-ruby tests/llama_integration.rb          # full suite (streaming, tools)
```

## 5. Contract Testing

The `bin/capabilities` script performs live contract testing on the current environment. It verifies that all active providers fulfill their defined interface requirements.

```sh
capabilities --json
```

## 6. Performance Benchmarking

Shell startup time is a critical metric.
```sh
make bench
```
Target interactive startup: **< 80ms**.

## 7. Manual Verification

Use `zdots-ctl check` for a comprehensive environment audit that includes tool presence, configuration validity, and service health.
