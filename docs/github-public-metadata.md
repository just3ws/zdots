# GitHub public profile and repository metadata

Use this runbook to review and update the public profile biography and public
repository descriptions for an account you own. It uses the GitHub CLI (`gh`)
for authentication and API access; it never asks you to print or copy an access
token.

## 1. Confirm the account and current values

Check that `gh` is authenticated as the intended account, then confirm the API
identity. Stop if either account is unexpected.

```bash
gh auth status
gh api user --jq '{login, name, bio}'
```

For each repository, inspect its current public description and canonical URL:

```bash
gh repo view just3ws/REPOSITORY --json nameWithOwner,url,description
```

Use the canonical identity and project descriptions in the relevant project
documentation as the source for proposed copy. Keep historical names as project
lineage where useful; do not present a former brand or account as the current
owner identity.

## 2. Review the exact proposed copy

Draft the profile biography and each repository description before making any
API call that changes data. Check spelling, length, links, ownership, and that
each repository's description matches its current purpose. Compare the proposed
text with the output from step 1 and the canonical project documentation.

Keep a local before/after note if you need an audit record. These fields are
public, but the note should not contain credentials. Do not put a token in a
command, environment variable, script, issue, or handoff.

## 3. Apply one reviewed change at a time

Updating the signed-in user's biography uses GitHub's authenticated user
endpoint. Replace the example text with the reviewed biography:

```bash
gh api --method PATCH user -f bio='Reviewed public biography'
```

Updating one repository description uses `gh repo edit`. Replace the owner,
repository, and example text with the reviewed values:

```bash
gh repo edit just3ws/REPOSITORY --description 'Reviewed repository description'
```

Run each command separately so the returned value can be reviewed before making
the next change. These commands change public GitHub metadata immediately; they
do not publish code or alter repository contents. If GitHub reports an
authorization error, stop and follow `gh auth refresh` interactively for the
scope it requests. Never work around it by extracting or pasting the token.

## 4. Verify the result

Read back each changed field from GitHub and compare it with the approved copy:

```bash
gh api user --jq '{login, name, bio}'
gh repo view just3ws/REPOSITORY --json nameWithOwner,url,description
```

Update the canonical project documentation if the approved wording represents
a lasting identity or project-description decision. Do not treat the live GitHub
value as canonical without that review.

## Credential handling

- Authenticate with `gh auth login` when needed; let `gh` manage its credential
  store.
- Use `gh auth status` to inspect the active account. Avoid commands that print
  the stored credential.
- Never enable shell tracing (`set -x`) around authenticated commands or capture
  credential-bearing diagnostic output.
- The commands above use the CLI's authenticated API client; they do not place
  a token in the command line or require a token-bearing environment variable.
