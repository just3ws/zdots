# Work and personal setup

The platform shares tools across machines while keeping machine identity and
employer content separate. `ZDOTS_CONTEXT` is a machine posture (`home` or
`work`), not an isolation mechanism for switching employers or terminal tabs.

## Ownership across the platform

| Repository | Shared on both machines | Local to each environment |
| --- | --- | --- |
| zdots | Shell, Platform Services, CLI, base PHI Pattern Registry | `.zdots.local`, Keychain, runtime databases and state |
| adots | Home configuration and bootstrap tools, managed through `adots` / `adots-git` | `adots-profile` machine identity and local identity overrides |
| my | `my.structure.v1` directory contract and platform epoch | Separate repository history, content, databases, and vaults for each environment |
| vdots | Editor configuration and zdots integration | Runtime state and explicitly verified AI provider choices |

Employer identity, app wiring, and tenant PHI patterns belong in a separate
work-extension repository at `${ZDOTS_WORK_EXT:-~/.config/zdots-work}`. It has
its own history and remote; it is never a platform submodule. Do not reuse a
previous employer's extension or copy its runtime state to the new role.

## Set up the company baseline first

Start with the issued Mac as provided. Complete company enrollment, security
controls, developer access, and the approved AI setup first. For Rails work,
confirm the team's Ruby version manager, Ruby and Rails versions, database,
services, test commands, and editor expectations from an actual project or
team setup guide. Keep those project requirements authoritative; zdots' own
Ruby baseline does not set the company's app runtime.

Then add personal environment tools selectively:

1. Confirm which home files and package sources IT manages. Review
   `Brewfile.work` and `Brewfile.common` before installing: the work manifest
   adds AWS, Kubernetes, Terraform, VPN, and Copilot tooling, which may not fit
   this Rails role. Install only what is approved and useful.
2. Create `.zdots.local` from the example **before bootstrap**, set
   `ZDOTS_CONTEXT=work`, and add only this machine's network/identity settings.
   Store credentials in Keychain. Do not copy personal credentials or a prior
   employer's local configuration.
3. Before bootstrap, inspect the adots paths it would restore against the
   company baseline. Bootstrap restores all tracked home paths and has no skip
   switch or automatic backup. Back up existing files and defer any colliding
   paths until a selective restore is available.
4. Set `adots-profile work` after installing the adots commands; run
   `adots-profile validate` with the work environment loaded. This profile is
   separate from `ZDOTS_CONTEXT`; changing it does not activate zdots work mode.
5. Preview `adots-my prepare --dry-run`, then use `adots-my prepare --apply`
   to seed an empty environment when appropriate. Establish its own repository
   and destination. Do not clone the personal `~/my` vault onto the work Mac.
6. Create the new employer extension only after its ownership and remote are
   settled. Keep it outside all four platform repositories.

For Rails projects, first build against the team's documented setup in a
project-specific shell. Adopt zdots' Ruby language-server and optional tools
only after checking that they work with the team's version files, Bundler setup,
database, and editor plugins. Keep local AI on the approved endpoint and verify
where each editor integration sends buffer contents before using it with company
code.

## Work posture and verification

`env.sh` and bootstrap load `.zdots.work` after `.zdots.local`. Work mode
enforces Session Residue capture off, command analytics off, history redaction
on, and AI mode `local` or `none`. An old machine's encryption key or successful
encryption audit does not authorize capture on a new machine.

After opening a fresh shell, inspect only these non-secret settings:

```sh
printenv ZDOTS_CONTEXT ZDOTS_AI_MODE ZDOTS_CAPTURE_ENABLED ZDOTS_HISTORY_REDACT ZDOTS_CMD_ANALYTICS
adots-profile validate
adots-my doctor
zdots-ctl check
```

Expected posture is `work`, `local` (or `none`), `0`, `1`, `0`, respectively.
Complete the PHI checklist in [SETUP.md](../SETUP.md) and verify the actual
machine before using work data. Repository tests do not verify a new host's
FileVault, SIP, Keychain, network, or employer policy.

## Gaps to resolve before calling onboarding ready

- **Managed home files:** bootstrap needs a reviewed selective/skip restore
  path if the employer manages tracked paths. Documentation alone does not
  protect those files from its current unconditional restore.
- **Extension activation:** `conf.d/31-work-ext.zsh` sources an installed
  extension whenever readable, even in home context. A context change does not
  unload its variables, functions, or hooks. Review explicit activation before
  using both contexts under one macOS user.
- **Editor AI:** vdots' `editor/llm.lua` invokes `ai-query`, but CodeCompanion
  is configured separately without an explicit adapter in `lua/plugins.lua`.
  Its provider and data path require verification before using work buffers.
- **Git identity:** verify effective identity and destination in a synthetic
  work repository and a personal repository. adots machine profile validation
  alone does not prove Git include rules or SSH account selection are correct.

If both contexts must run on one Mac, choose the account/data separation first.
A fresh work shell does not isolate shared home files, Keychain items, editor
state, or existing Platform Services and databases.

## Review evidence — 2026-11-06

The review covered tracked setup/load paths in all four repositories without
opening employer extension contents, vault contents, credentials, or local
identity values. On this personal host, `adots-profile validate` passed and
`adots-my doctor` passed all 11 structural checks. The machine profile file was
not tracked in adots, so the old Z-277 report is not evidence of a current issue.

Knowledge Layer hydration failed with database authentication unavailable to
the agent session. Live Platform Service probes also reported multiple
unavailable endpoints. Neither result establishes the posture of the future
work machine; no Platform Services were started or restarted during this review.
