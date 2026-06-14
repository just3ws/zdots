---
id: zdots-pages
title: "Docs Publishing — zdots-pages"
purpose: Canonical repo→wiki→Pages mapping and the maintenance contract for the shared just3ws documentation surface.
---

# Docs Publishing — `zdots-pages`

`bin/zdots-pages` is the single publisher for every just3ws system's
documentation. One framework renders a repo's curated `docs/wiki/*.md` into a
[just-the-docs](https://just-the-docs.com) Jekyll site (a `gh-pages` worktree)
and syncs the same pages to the repo's GitHub Wiki. Built and proven in zdots,
applied identically to adots and vdots.

This page is the **maintenance contract**: the authoritative mapping plus the
expectations that keep all three surfaces consistent. When you add a page, a
repo, or a domain, update this file.

## The mapping

| Repo | Wiki source (authoritative) | Tracked via | Pages site | Wiki |
|---|---|---|---|---|
| **zdots** | `docs/wiki/` (this repo) | `git` (main) | `www.just3ws.com/zdots/` | `github.com/just3ws/zdots/wiki` |
| **adots** | `~/.config/adots/wiki/` | `homegit` (bare `~/.homegit`) | `www.just3ws.com/adots/` | `github.com/just3ws/adots/wiki` |
| **vdots** | `~/.config/nvim/docs/wiki/` | `git` (main) | `www.just3ws.com/vdots/` | `github.com/just3ws/vdots/wiki` |
| **my** | — | — | *none — private* | *none — private* |

- Pages canonical host is `www.just3ws.com/<repo>/`; `just3ws.github.io/<repo>/`
  resolves to the same site.
- **`my` is private and has no public surface.** Its operator docs live as a
  page **inside the adots wiki** (`My-System`). Never publish `my`.

## Source of truth

The repo's `docs/wiki/` (or adots' `~/.config/adots/wiki/`) **wins**. The live
GitHub Wiki and the Pages site are *generated* outputs.

- **Never edit a page on `github.com` directly** — the next `zdots-pages wiki`
  overwrites it. Edit the source `.md`, commit, then re-publish.
- `Home.md` becomes the site index and the wiki landing page.

## Maintenance commands

Run from the zdots checkout (the tool lives in `bin/`; alias `zpages`).

```bash
# zdots (operate on the current repo)
zdots-pages status
zdots-pages build                 # render site into ./.gh-pages (local, reversible)
zdots-pages publish --push        # commit + push the gh-pages branch
zdots-pages wiki    --push        # sync docs/wiki -> <repo>.wiki.git

# vdots (another normal repo)
zdots-pages <cmd> --repo ~/.config/nvim [--push]

# adots (BARE repo — no working tree to infer docs from)
zdots-pages <cmd> --git-dir ~/.homegit --wiki-src ~/.config/adots/wiki [--push]
```

Bare-repo notes (adots): `--wiki-src` is **required**; owner/repo derive from the
`origin` remote, not the directory name; the gh-pages worktree lives at
`~/.local/state/zdots-pages/just3ws-adots.gh-pages`. A net-new site needs
`zdots-pages init` once before the first `build`.

**Routine — edit a page:** edit source `.md` → commit (to that repo) →
`zdots-pages wiki --push` → `zdots-pages build && zdots-pages publish --push`.
`build`/`status` are local and reversible; `publish`/`wiki` only push with
`--push` (without it they stage and report).

## Expectations (invariants)

1. **Every wiki Home carries a "The ecosystem" section** linking the two peer
   systems and pointing `my` at the adots `My-System` page.
2. **Cross-repo links are absolute** `https://github.com/just3ws/<repo>/wiki`
   URLs. Relative links only resolve *within* one wiki; a relative peer link is
   a broken link.
3. **Inline cross-references** link the *first* mention of a peer system on a
   page where it already appears — no invented references, no link spam.
4. **Fail-closed visibility.** `zdots-pages` refuses to publish a private repo to
   a public Pages site without `--allow-private`. `my` never gets `--allow-private`.
5. **Shared theme.** All sites use `etc/pages/_config.yml.template`
   (`remote_theme: just-the-docs/just-the-docs`, built server-side — no local
   Ruby). Change theme/nav once, in the template, for all repos.

## Custom domain (`www.just3ws.com`)

The custom domain is configured **once, at the org level** on the user/org Pages
repo `just3ws/just3ws.github.io`:

| Where | Setting |
|---|---|
| `just3ws/just3ws.github.io` | cname `www.just3ws.com` + `CNAME` file; TLS cert approved; HTTPS enforced |
| Project repos (zdots/adots/vdots) | `cname` stays **null** (inherit the org apex); `https_enforced = true` |
| DNS | `www` CNAME → `just3ws.github.io`; apex `just3ws.com` A → `185.199.108–111.153` |

**Do not set a per-repo `cname`** — project pages inherit the org domain and a
repo-level `www.just3ws.com` would conflict with it. Enforce HTTPS per repo with:

```bash
gh api -X PUT repos/just3ws/<repo>/pages -F https_enforced=true
```

## Onboarding a new repo

The operator playbook — including folding in a **legacy** project's existing
docs or old wiki — is the published page
[Onboarding a Project](wiki/Onboarding-a-Project.md) (live at
`www.just3ws.com/zdots/onboarding-a-project/`). The short form:

1. Create `docs/wiki/` with at least `Home.md`; add the "The ecosystem" section
   and absolute peer links per the invariants above.
2. Add the repo to **the mapping table in this file**.
3. Confirm the repo is **public** (private repos do not get a public surface).
4. `zdots-pages init` → `build` → `publish --push`; enable Pages and enforce
   HTTPS via `gh api`. Bare repos pass `--git-dir`/`--wiki-src`.
5. `zdots-pages wiki --push` (the `.wiki.git` repo only exists after the first
   wiki page is saved once in the GitHub UI).
6. Cross-link the existing systems' Home pages back to the new repo.

## Verify

```bash
# sites serve over HTTPS
for r in zdots adots vdots; do curl -sI "https://www.just3ws.com/$r/" | head -1; done

# cross-links render and resolve on the live wikis
for r in zdots adots vdots; do
  curl -fsSL "https://github.com/just3ws/$r/wiki" \
    | grep -oE 'href="https://github.com/just3ws/(zdots|adots|vdots)/wiki[A-Za-z/_-]*"' \
    | grep -v "/just3ws/$r/wiki" | sort -u
done
```

## See also

- [documentation-system.md](documentation-system.md) — overall doc authority model
- `bin/zdots-pages --help` · `etc/pages/_config.yml.template` · `tests/zdots_pages.bats`
