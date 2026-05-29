# Testing Strategy

Zdots uses a multi-tier testing strategy to ensure shell stability and contract reliability.

## 1. Automated Checks

```sh
make check       # Runs all fast checks and tests
make check-fast  # Shellcheck and sanity checks (no external dependencies)
make coverage    # Generates unified Ruby (SimpleCov) and Shell (kcov) metrics
```

## 2. Unit Testing (Bats-core)

We use `bats-core` for shell unit testing. Tests are located in `tests/`.

| Test File | Scope |
|---|---|
| `tests/env_posix.bats` | Ensures POSIX compliance of bootstrap scripts. |
| `tests/observability.bats` | Validates OTel span rotation and trace headers. |
| `tests/metadata.bats` | Tests the unified metadata service. |
| `tests/update_local_logging.bats` | Verifies the deployment log partitioning contract. |
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

---

## Known Limitations & Pitfalls

### Non-TTY plugin warnings (p10k, zsh-vi-mode)

When zsh is invoked interactively but without a real PTY (e.g. `zsh -i` with piped output, or subshells in automated scripts), `p10k` and `zsh-vi-mode` emit:

```
(anon):setopt:7: can't change option: monitor
(eval):1: can't change option: zle
```

These are in external plugin internals — not fixable in zdots. The `-t 1` guard in `conf.d/20-prompt.zsh` prevents `gitstatus` from failing in this scenario, but does not suppress all plugin noise.

**Mitigation for scripts/CI that need to source zdots:** use `ZDOTS_SAFE_MODE=1` (loads only `conf.d/05–60`, skips heavy integrations) or suppress with `2>/dev/null` around the source call.

### Environment variable bleed-through in bats tests

Real shell environment variables (e.g. `ZDOTS_AI_PROFILE`, `ZDOTS_WHISPER_PROFILE`) bleed into bats test subshells. `tests/setup.bash::setup_environment()` does **not** clear service-profile vars.

**Rule:** every `tests/*.bats` `setup()` function must explicitly `unset` any env var its fixture overrides. Failure mode: tests pass in a clean shell but fail when the matching var is set in the developer's session (or vice versa).
