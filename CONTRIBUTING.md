# Contributing to Zdots

Thank you for contributing to Zdots! This project follows rigorous engineering standards to maintain a high-performance, observable, and AI-friendly shell environment.

## 1. Local Setup

Refer to [SETUP.md](SETUP.md) for full installation and bootstrapping instructions.

**Required Tooling:**
- `brew` (Homebrew)
- `zsh` (Latest)
- `make`
- `ruby` (for AI integration tests)

## 2. Standards & Quality

All contributions must adhere to the [Zsh Configuration Quality Rubric](docs/zsh-quality-rubric.md).

### Shell Scripting
- **Indentation:** 2 spaces.
- **Linter:** `shellcheck` for `.sh` and `.bash` files.
- **Validation:** `bin/check` for Zsh modules.
- **POSIX Compatibility:** Logic in `env.sh` and `.zshenv` MUST be POSIX-compliant. Use `tests/env_posix.bats` to verify.

### Commit Workflow
- **Atomic Commits:** Prefer small, single-purpose commits.
- **Sign-off:** All commits should follow project-specific conventions (see existing history).
- **Auto-attribute:** Use `git absorb` to automatically attribute fixup changes.

## 3. Pull Request Expectations

Before opening a PR, ensure:
1. `make check` passes locally.
2. New features include appropriate tests in `tests/`.
3. Documentation is updated in `docs/` to reflect changes.
4. Architectural changes are accompanied by an ADR (Architecture Decision Record) if necessary.

## 4. Architecture Decisions (ADR)

Significant changes to the platform's design or service contracts require an ADR.
- ADRs live in `backlog/decisions/`.
- Use the `backlog decision create` command to start a new record.

## 5. Security

- **Secrets:** NEVER commit secrets or API keys. Use `.zdots.secrets` (gitignored) for private overrides.
- **Secret Scanning:** `pre-commit` runs `gitleaks` automatically. Do not bypass this.
- **Verification:** Refer to [SECURITY.md](SECURITY.md) for the project's security baseline.

## 6. Documentation Updates

- All new scripts in `bin/` must be added to the reference table in `README.md`.
- New service providers must be documented in `docs/architecture.md`.
- Use the `agent-guide` to verify operational documentation is current.
