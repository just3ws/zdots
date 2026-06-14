# Onboarding a Project

How to fold another project — including a **legacy** repo with its own scattered
docs or an old GitHub wiki — into the shared just3ws documentation system, so it
gets the same themed Pages site, the same cross-linked wiki, and the same
custom-domain hosting as zdots / adots / vdots.

This is the operator playbook. The technical contract (the repo→Wiki→Pages
mapping, invariants, exact flags) is
[`docs/zdots-pages.md`](https://github.com/just3ws/zdots/blob/main/docs/zdots-pages.md)
in the zdots repo. Run everything below with `zdots-pages` (alias `zpages`)
from the zdots checkout.

## 0. Decide if it qualifies

| Check | Rule |
|---|---|
| **Visibility** | The site is **public**. A private repo gets **no public surface** — document it as a page inside an existing public wiki instead (the way `my` lives in the adots wiki). |
| **Ownership** | Under the `just3ws` org (or another owner you control). Owner/repo derive from the `origin` remote, not the directory name. |
| **Repo shape** | Normal repo *or* a bare repo (like adots at `~/.homegit`). Bare repos need `--git-dir` + `--wiki-src`. |

If it fails the visibility check, stop — do not publish it.

## 1. Gather the legacy docs

Find what already exists so nothing is lost in the move:

- `README`, `docs/`, loose `*.md` scattered in the repo.
- An **existing GitHub wiki** — clone it so its history/content is in hand:
  ```bash
  git clone https://github.com/<owner>/<repo>.wiki.git /tmp/<repo>.wiki
  ```
- Any external doc (Notion, gist, old site) the project depended on.

## 2. Curate into the source of truth

The authoritative source is the repo's `docs/wiki/*.md`. **Source wins** — once
onboarded, never edit the live wiki on github.com; the next sync overwrites it.

1. Create `docs/wiki/` in the project (for a bare repo, pick a tracked source
   dir and remember it for `--wiki-src`).
2. Distill the legacy material into curated pages. At minimum a `Home.md`
   (becomes both the site index and the wiki landing page) plus a few topic
   pages — navigation and operator workflow, not a dump.
3. Add the **"The ecosystem"** section to `Home.md` linking the peer systems
   with **absolute** URLs (`https://github.com/just3ws/<repo>/wiki`). Relative
   peer links are broken links.
4. Commit to the project repo.

## 3. Register it

Add a row to the mapping table in
[`docs/zdots-pages.md`](https://github.com/just3ws/zdots/blob/main/docs/zdots-pages.md):
repo · wiki source · how it's tracked · Pages URL · Wiki URL. This table is the
roster — if it is not in the table, it is not in the system.

## 4. Publish the Pages site

```bash
# normal repo
zdots-pages init    --repo /path/to/repo
zdots-pages build   --repo /path/to/repo
zdots-pages publish --repo /path/to/repo --push

# bare repo (like adots): --wiki-src is required
zdots-pages init    --git-dir /path/to/repo.git --wiki-src /path/to/wiki
zdots-pages build   --git-dir /path/to/repo.git --wiki-src /path/to/wiki
zdots-pages publish --git-dir /path/to/repo.git --wiki-src /path/to/wiki --push
```

Then enable Pages and enforce HTTPS (the custom domain is inherited from the
org — **do not** set a per-repo `cname`):

```bash
gh api -X POST repos/just3ws/<repo>/pages -f 'source[branch]=gh-pages' -f 'source[path]=/'
gh api -X PUT  repos/just3ws/<repo>/pages -F https_enforced=true
```

The site comes up at `www.just3ws.com/<repo>/`.

## 5. Sync the wiki

```bash
zdots-pages wiki --repo /path/to/repo --push          # or --git-dir/--wiki-src for bare
```

> **First-time gotcha:** GitHub only creates the `<repo>.wiki.git` repo *after
> the first wiki page is saved once in the web UI* (Wiki tab → Create the first
> page → Save). Do that one manual save, then `wiki --push` works.

If the legacy wiki from step 1 had content worth keeping, it is now folded into
`docs/wiki/` and re-published from source — the old wiki is retired, not edited.

## 6. Cross-link back

Add the new project to the **"The ecosystem"** tables on the *existing* systems'
`Home.md` pages (zdots, adots, vdots), and link the first inline mention wherever
a page already references it. Re-sync those wikis. The web is only complete when
every system points at the newcomer and back.

## 7. Verify

```bash
curl -sI "https://www.just3ws.com/<repo>/" | head -1          # expect HTTP/2 200
curl -fsSL "https://github.com/just3ws/<repo>/wiki" \
  | grep -oE 'href="https://github.com/just3ws/[a-z]+/wiki[A-Za-z/_-]*"' | sort -u
```

Confirm: site serves over HTTPS, the ecosystem cross-links render, and the
mapping table in `docs/zdots-pages.md` includes the new row.

## Checklist

- [ ] Public repo (private → document inside an existing wiki instead)
- [ ] Legacy docs gathered (README, `docs/`, old `.wiki.git`)
- [ ] `docs/wiki/Home.md` + topic pages curated, with "The ecosystem" section
- [ ] Absolute peer links (no relative cross-repo links)
- [ ] Row added to the `docs/zdots-pages.md` mapping table
- [ ] Pages: `init` → `build` → `publish --push`; Pages enabled; HTTPS enforced
- [ ] No per-repo `cname` set (org apex is inherited)
- [ ] First wiki page saved once in the UI, then `wiki --push`
- [ ] Existing systems cross-linked back and re-synced
- [ ] Verified: HTTPS 200 + cross-links resolve

## See also

- [System Map](System-Map.md) — where the systems sit
- `bin/zdots-pages --help` · the maintenance contract in `docs/zdots-pages.md`
