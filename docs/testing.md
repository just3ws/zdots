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

## 3. Integration Testing (RubyLLM)

End-to-end validation of the AI stack (chat, embeddings, tool use) is handled via Ruby integration tests.

```sh
ruby tests/llama_integration.rb --quick  # Fast health + chat check
ruby tests/llama_integration.rb          # Full suite (includes streaming/tools)
```

## 4. Contract Testing

The `bin/capabilities` script performs live contract testing on the current environment. It verifies that all active providers fulfill their defined interface requirements.

```sh
capabilities --json
```

## 5. Performance Benchmarking

Shell startup time is a critical metric.
```sh
make bench
```
Target interactive startup: **< 80ms**.

## 6. Manual Verification

Use `zdots-ctl check` for a comprehensive environment audit that includes tool presence, configuration validity, and service health.
