# Commit Signing for Agents

Every commit and tag an agent makes in the zdots system — **zdots**, **adots**,
**vdots** and **my** — is signed with the operator's SSH key held in
1Password. GitHub then shows it as *Verified*, and provenance survives the
trip through any number of agents and machines.

Signing is per machine, not per agent: the agent signs because the git config
of the shell it runs in says so. An agent never chooses its own key, never
generates one, and never turns signing off.

## Rules for agents

1. **Never bypass signing.** No `--no-gpg-sign`, `-c commit.gpgsign=false`,
   `git config commit.gpgsign false`, unsetting `user.signingkey`, or
   committing through a tool that skips git's signing path. If signing fails,
   stop and report the exact error; the operator fixes the cause.
2. **Expect a Touch ID prompt and say so.** Before a commit, an amend, or a
   rebase (each rewritten commit is re-signed), tell the operator a 1Password
   approval is coming. Batch related commits in one run so one approval
   covers them.
3. **Verify before you push** (see [Verify](#verify)). An unsigned commit
   found before the push is fixed with `git commit --amend --no-edit -S`
   (last commit) or `git rebase --force-rebase -S origin/main` (a series).
4. **Merge by fast-forward.** Push the reviewed branch head to `main`
   (`git push origin <branch>:main`); GitHub marks the PR merged and every
   signature is kept. GitHub's *Rebase and merge* rewrites the commits and
   drops your signatures; *Squash* and *Merge commit* are signed by GitHub,
   not by you.
5. **Can't sign? Don't commit to `main`.** Headless and remote agents (cloud
   sandboxes, CI, an SSH session with no desktop) have no 1Password app to
   sign with. Push a branch and hand off; the operator re-signs it locally
   with `git rebase --force-rebase -S origin/main` before merging.
6. **Don't rewrite old history** to sign past commits — that stays deferred,
   as with attribution (AGENTS.md).

## How signing works here

Git signs with SSH keys (`gpg.format = ssh`). The private key never leaves
1Password: git calls 1Password's `op-ssh-sign`, which asks the 1Password
desktop app to sign. That means:

- the 1Password app must be installed, signed in, and running in the same
  macOS login session as the agent;
- the first signature from an application asks for approval (Touch ID or the
  account password); the approval then covers that application and its
  subprocesses until 1Password locks or quits, or for the duration chosen in
  1Password › Settings › Developer;
- an agent sandbox must let `git commit` reach the 1Password app. If the
  sandbox blocks it, run the commit outside the sandbox with the operator's
  approval — never fall back to an unsigned commit.

Prefer the default approval scope (*per key, per application*). *Approve for
all applications* hands the key to every process of the user for the session;
use it only deliberately.

## Set up a machine (once)

Signing settings are machine-local because the signing key can differ per
machine (a work 1Password account holds a different key than the personal
one). adots' tracked `~/.config/git/config` includes
`~/.config/git/config.signing`, which is never tracked; git ignores the include
when the file is absent.

1. **In 1Password:** Settings › Developer › *Use the SSH agent* on, and an SSH
   key item to sign with.
2. **On GitHub:** add that public key to the account as a **Signing key**
   (Settings › SSH and GPG keys › *New SSH key* › Key type *Signing Key*).
   The commit email (`mike@just3ws.com`) must be verified on the same account.
3. **In git** — choose by machine type:
   - *Personal machine* — write the signing block to the untracked file:
     ```sh
     f=~/.config/git/config.signing
     git config -f "$f" gpg.format ssh
     git config -f "$f" gpg.ssh.program /Applications/1Password.app/Contents/MacOS/op-ssh-sign
     git config -f "$f" user.signingkey "key::ssh-ed25519 AAAA…"   # 1Password › key item › public key
     git config -f "$f" commit.gpgsign true
     git config -f "$f" tag.gpgsign true
     ```
   - *Employer-managed machine* — the employer's `~/.gitconfig` usually
     already carries the signing block (see the
     [work migration playbook](work-migration-playbook.md), Phase 4). Keep it
     as-is; do not repeat it in `config.signing`. Signing then applies to the
     platform repos too, because adots' config is included after it.
4. **Local verification** — git can only check SSH signatures against an
   allowed-signers list:
   ```sh
   key="$(git -C ~/.config/zsh config user.signingkey)"; key="${key#key::}"
   printf '%s namespaces="git" %s\n' mike@just3ws.com "$key" >> ~/.config/git/allowed_signers
   git config -f ~/.config/git/config.signing gpg.ssh.allowedSignersFile ~/.config/git/allowed_signers
   ```
   Put one line per key; list every email that signs with that key,
   comma-separated, in the first field.
5. **Prove it:** make a throwaway signed commit in a scratch repo and run
   `git log --show-signature -1` — expect `Good "git" signature for
   mike@just3ws.com`.

## Verify

Before pushing, list unsigned commits on the branch (works even without an
allowed-signers file):

```sh
git rev-list origin/main..HEAD | while read -r c; do
  git cat-file -p "$c" | grep -q '^gpgsig' || git log -1 --format='UNSIGNED %h %s' "$c"
done
```

With the allowed-signers file in place, `git log --format='%h %G? %s'
origin/main..HEAD` shows `G` for every good signature.

After pushing, GitHub is the authority:

```sh
gh api repos/just3ws/<repo>/commits/<sha> --jq .commit.verification.reason   # → valid
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `error: 1Password: failed to fill whole buffer` / `agent returned an error` | 1Password locked, approval declined, or the app is not running | Unlock 1Password and approve; retry the same command |
| `gpg failed to sign the data` with `gpg.format` unset | Machine not set up | [Set up a machine](#set-up-a-machine-once) |
| Commit made but unsigned | `commit.gpgsign` not set in this shell's git config, or `GIT_CONFIG_GLOBAL` points at a file without the include | `git config --show-origin --get commit.gpgsign`; fix the config, then amend with `-S` |
| `gpg.ssh.allowedSignersFile needs to be configured` | Only local verification is affected | Step 4 of the setup |
| GitHub shows *Unverified* | Key not added as a **Signing** key, or the commit email is not verified on the account | Step 2 of the setup |
| GitHub shows *Unverified* after a PR merge | Merged with *Rebase and merge* | Merge by fast-forward (rule 4) |
