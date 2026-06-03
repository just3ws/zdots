# Tutorial: GitHub SSH Key Setup and Rotation

This tutorial shows the explicit home/work GitHub SSH setup used by `zdots-github-keys`.
It keeps the mapping unambiguous:

- `home` and `work` are local profile labels.
- `home.github.com` and `work.github.com` are the SSH host aliases.
- `~/.ssh/id_home@github` and `~/.ssh/id_work@github` are the private keys.
- `~/.ssh/id_home@github.pub` and `~/.ssh/id_work@github.pub` are the public keys you register in GitHub.

## 1. Prerequisites

- `github-keygen` installed via Homebrew.
- A GitHub username for the home account.
- A GitHub username for the work account.

The home and work usernames must be different. The tool treats them as separate accounts on purpose.

## 2. Initial Setup

Start by checking the exact plan. This shows the usernames, key paths, aliases, and the `github-keygen` command that will run.

```bash
zdots-github-keys plan \
  --home-user HOME_GITHUB_USER \
  --work-user WORK_GITHUB_USER \
  --default home
```

`--default home` means bare `github.com:` remotes will resolve to the home identity.
Use `--default work` if you want the work identity to be the default, or `--default none` if you want only explicit host aliases.

Apply the configuration only when you are ready to write `~/.ssh/config` and create the keys:

```bash
zdots-github-keys apply \
  --home-user HOME_GITHUB_USER \
  --work-user WORK_GITHUB_USER \
  --default home \
  --yes
```

This writes or updates:

- `~/.ssh/config`
- `~/.ssh/id_home@github`
- `~/.ssh/id_home@github.pub`
- `~/.ssh/id_work@github`
- `~/.ssh/id_work@github.pub`

After the command finishes, add each public key to the matching GitHub account:

```bash
zdots-github-keys public-key home
zdots-github-keys public-key work
```

Then paste each key into GitHub at:

`https://github.com/settings/keys`

Test the two explicit SSH aliases:

```bash
ssh -T home.github.com
ssh -T work.github.com
```

## 3. How To Use The Remotes

Use the explicit aliases in git remotes so there is never any ambiguity about which account is used.

```bash
git remote add origin git@home.github.com:OWNER/REPO.git
git remote add work git@work.github.com:OWNER/REPO.git
```

If you set `--default home` or `--default work`, bare `github.com:` URLs will use that default account.

## 4. Rotation

Rotation is a two-step flow.

1. Stage a replacement key.
2. Register the staged public key in GitHub.
3. Promote the staged key after GitHub accepts it.

Stage a new key for the home or work profile:

```bash
zdots-github-keys rotate-stage home \
  --home-user HOME_GITHUB_USER \
  --work-user WORK_GITHUB_USER
```

This creates the staged files:

- `~/.ssh/id_home@github.next`
- `~/.ssh/id_home@github.next.pub`

and exposes the staged SSH alias:

- `home_next.github.com`

Print the staged public key and add it to the matching GitHub account:

```bash
zdots-github-keys public-key home_next
```

Verify the staged alias before promotion:

```bash
ssh -T home_next.github.com
```

When the staged key is registered and works, promote it:

```bash
zdots-github-keys rotate-promote home \
  --home-user HOME_GITHUB_USER \
  --work-user WORK_GITHUB_USER \
  --yes
```

Promotion switches the active `home` profile to the staged key and removes the temporary `home_next` alias from the SSH config.

Repeat the same flow for `work`:

```bash
zdots-github-keys rotate-stage work \
  --home-user HOME_GITHUB_USER \
  --work-user WORK_GITHUB_USER

zdots-github-keys rotate-promote work \
  --home-user HOME_GITHUB_USER \
  --work-user WORK_GITHUB_USER \
  --yes
```

## 5. Status Check

Use `status` anytime to see what is present on disk.

```bash
zdots-github-keys status
```

This reports:

- the configured username for each profile
- the fixed host alias
- the private key path
- the public key path
- whether `~/.ssh/config` exists

## 6. Rules

- Never guess which account a remote should use.
- Use `home.github.com` or `work.github.com` when you want a specific identity.
- Use the `public-key` command to fetch the exact key that needs to go into GitHub.
- Treat rotation as a staged change, not an in-place swap.
