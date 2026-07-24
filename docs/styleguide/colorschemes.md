# Colorscheme Styleguide

Canonical reference for the platform's colorschemes. The platform themes through a
**semantic token model**: surfaces reference tokens (`--bg`, `--accent`, …), and a
scheme binds those tokens to palette values. Swapping the binding re-themes every
surface. **Kanagawa Wave** is the default scheme, with **nord** as an alternate.

To reference or extend a scheme, start here.

---

## Heritage — *The Great Wave off Kanagawa*

Kanagawa Wave is named for **Katsushika Hokusai's** woodblock print *The Great
Wave off Kanagawa* (神奈川沖浪裏, *Kanagawa-oki Nami Ura*, c. 1831) — the opening
image of his *ukiyo-e* series *Thirty-Six Views of Mount Fuji*. A towering wave
of clawing foam rears over three fast boats while Mount Fuji sits small and
still on the horizon, framed by the very wave that seems poised to swallow it.
Its deep blues are **Prussian blue** (*bero-ai*), a synthetic pigment newly
imported to Japan in Hokusai's day — the colour that gives the print, and this
palette, its cool depth.

The palette (rebelot's `wave` variant) reads like an inventory of that world —
which is why the token names are worth keeping literally:

| Palette name | 日本語 | In the print |
|---|---|---|
| **sumiInk** | 墨 *sumi* — ink stick | the dark grounds; the deepest ink of the block-print line |
| **fujiWhite / fujiGray** | 富士 *Fuji* | the snow-capped mountain and its mist |
| **waveBlue / waveAqua / crystalBlue** | 波 *nami* — wave | the Great Wave itself; crystalBlue is "the wave" accent |
| **springGreen / autumnRed / autumnGreen** | 春・秋 seasons | the seasonal *Views of Mount Fuji* |
| **carpYellow** | 鯉 *koi* — carp | koi gold |
| **boatYellow** | 舟 *fune* — boat | the *oshiokuri-bune* boats fighting the wave |
| **sakuraPink** | 桜 *sakura* | cherry blossom |
| **oniViolet** | 鬼 *oni* — demon | the ogre's violet |
| **samuraiRed / peachRed** | 侍・桃 | samurai lacquer; peach |

The background is the one deliberate departure: hand-tuned bluer than canonical
(`#1F1F28` → `#1A1B2F`) to pull the whole platform a shade further into the
wave's Prussian depth. Everything else is upstream.

---

## 1. Kanagawa Wave — palette

Palette by **rebelot (Tommaso Laurenzi)** — [rebelot/kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim)
`wave` variant, **MIT License, Copyright (c) 2021 Tommaso Laurenzi**. The named
hex values are that work; the platform **hand-tunes only the background** bluer
than canonical (`#1F1F28` → `#1A1B2F`).

| Name | Hex | Role |
|---|---|---|
| sumiInk (tuned) | `#1A1B2F` | platform ground / bg |
| sumiInk0 | `#16161D` | deepest ink |
| sumiInk4 | `#2A2A37` | raised surface |
| sumiInk5 / 6 | `#363646` / `#54546D` | borders / hairlines |
| waveBlue1 / 2 | `#223249` / `#2D4F67` | panels / selection |
| fujiWhite | `#DCD7BA` | foreground text |
| fujiGray | `#727169` | muted text (see §5 A11y) |
| oldWhite | `#C8C093` | AA-safe muted text |
| crystalBlue | `#7E9CD8` | primary accent (the wave) |
| springBlue | `#7FB4CA` | bright blue |
| waveAqua2 | `#7AA89F` | cyan / types |
| springGreen | `#98BB6C` | success / additions |
| autumnGreen | `#76946A` | ansi green |
| carpYellow | `#E6C384` | highlight / warning |
| boatYellow2 | `#C0A36E` | ansi yellow |
| surimiOrange | `#FFA066` | numbers / options |
| oniViolet | `#957FB8` | keywords / headings |
| sakuraPink | `#D27E99` | punctuation |
| autumnRed | `#C34043` | error / deletions |
| samuraiRed | `#E82424` | bright red |
| peachRed | `#FF5D62` | unclosed / danger |

---

## 2. Semantic tokens (web + shell)

The dashboards (`my.localhost`, `zdots.localhost`) and shell bind these tokens:

| Token | Kanagawa Wave | Notes |
|---|---|---|
| `--bg` | `#1A1B2F` | page ground |
| `--surface` | `#2A2A37` | cards, inputs |
| `--border` | `#363646` | 1px separators |
| `--text` | `#DCD7BA` | body (11.6:1 — AA ✓) |
| `--text-dim` | `#727169` → **`#C8C093`** | **fails AA at `#727169` (3.45:1); use oldWhite `#C8C093` (9.2:1)** |
| `--accent` | `#7E9CD8` | links, primary (6.1:1 ✓) |
| `--accent-dim` | `#2D4F67` | dim accent |
| `--green` | `#98BB6C` | success |
| `--yellow` | `#E6C384` | warning |
| `--red` | `#C34043` → **`#F29B9B` for text on tint** | red-on-red-tint fails; use light red for pill/label text |
| `--mono` | `FiraCode Nerd Font Mono Ret`, … | matches the terminals (Retina weight) |

---

## 3. Terminal ANSI (0–15)

Used by the iTerm2 preset, ghostty theme, and (transitively) `dark-ansi` in Claude Code.

| # | Role | Hex | | # | Role | Hex |
|---|---|---|---|---|---|---|
| 0 | black | `#16161D` | | 8 | br black | `#727169` |
| 1 | red | `#C34043` | | 9 | br red | `#E82424` |
| 2 | green | `#76946A` | | 10 | br green | `#98BB6C` |
| 3 | yellow | `#C0A36E` | | 11 | br yellow | `#E6C384` |
| 4 | blue | `#7E9CD8` | | 12 | br blue | `#7FB4CA` |
| 5 | magenta | `#957FB8` | | 13 | br magenta | `#938AA9` |
| 6 | cyan | `#6A9589` | | 14 | br cyan | `#7AA89F` |
| 7 | white | `#C8C093` | | 15 | br white | `#DCD7BA` |

bg `#1A1B2F` · fg `#DCD7BA` · cursor `#C8C093` · selection `#2D4F67`

---

## 4. Application map — where the scheme lives

Reference this when adding a surface or auditing coverage.

| Surface | Where | Mechanism |
|---|---|---|
| shell syntax | `assets/kanagawa-wave/syntax-highlighting.zsh` | zsh-syntax-highlighting styles |
| LS_COLORS | `assets/kanagawa-wave/vivid-theme.yml` | vivid |
| LSCOLORS (BSD) | `conf.d/30-env.zsh` | `kanagawa-*` block |
| fzf | `fzfrc` | `--color` opts |
| prompt | `assets/kanagawa-wave/p10k-overrides.zsh` | ANSI palette indices |
| iTerm2 | `assets/kanagawa-wave/Kanagawa-Wave.itermcolors` | color preset (import) |
| Claude Code | `~/.claude/settings.json` | `theme: dark-ansi` (rides preset) |
| nvim | vdots `kanagawa.nvim` | `colors.theme.wave.ui.bg=#1A1B2F` |
| bat | `assets/kanagawa-wave/Kanagawa-Wave.tmTheme` | `bat --theme` |
| ghostty | `assets/kanagawa-wave/ghostty-kanagawa-wave` | `theme =` |
| Alfred | `assets/kanagawa-wave/alfred-kanagawa-wave.json` | appearance |
| lazygit | `assets/kanagawa-wave/lazygit-kanagawa-wave.yml` | `gui.theme` |
| k9s | `~/.config/k9s/skins/kanagawa.yaml` | `ui.skin` |
| gh-dash / delta | `~/.config/gh-dash`, git `[delta]` | theme colors |
| dashboards | context-engine `app.css` `:root`; `bin/zdots-statusd` CSS | semantic tokens |
| wallpapers | `~/Pictures/kanagawa-wave/` | desktop tiers + faint iTerm bg |

App-level source files live under `assets/kanagawa-wave/`; the commemorative
"Bedrock" artifact is `assets/kanagawa-wave/bedrock.html`.

---

## 5. Accessibility (WCAG 2.1 AA)

Verified pairs (computed sRGB contrast):

- **Pass:** body `#DCD7BA`/bg (11.6:1), accent `#7E9CD8`/bg (6.1:1), green/yellow on surface.
- **Fix — `--text-dim` `#727169`** = 3.45:1 on bg, fails AA. It carries section headings, table `th`, meta lines. Use **`#C8C093`** (oldWhite, 9.2:1) or `#9A9887` (5.8:1).
- **Fix — red text on red tint** (`#C34043` on `rgba(195,64,67,.15)`) = ~2.9:1. Use light red **`#F29B9B`** for the label, keep the tint.
- **Fix — input borders** (`#363646` on `#1A1B2F`) = 1.4:1, below 3:1 for UI components. Fill inputs with `--surface` or use a ≥3:1 border.
- Add an app-wide `:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px }` and a skip-link.

Color must never be the sole signal — pills/badges pair tint with a text label.

---

## 6. Adding a new colorscheme

Surfaces are **generated from one palette source** — do not hand-author them.

1. Copy `etc/themes/kanagawa-wave.yaml` → `etc/themes/<scheme>.yaml`; edit the
   `palette:` hexes and the `title`/`source`/`slug`. The role bindings (`ansi`,
   `iterm_slots`, `tokens`, `mermaid`, `outputs`) stay as-is — that's the point.
2. Run `zdots-theme-gen <scheme>` → writes every surface into `assets/<scheme>/`.
3. Add the `<scheme>-*` branches to `fzfrc` and `conf.d/30-env.zsh` (LSCOLORS),
   which are palette-derived but not yet generated (follow-up).
4. `p10k-overrides.zsh` is palette-independent (rides ANSI indices) — reuse it.
5. Set `ZDOTS_THEME=<scheme>` in `env.sh`.

`zdots-theme-gen <scheme> --check` fails if any generated artifact drifts from
its source; it is enforced by `tests/theme_gen.bats`. Keep the semantic tokens
stable; only the palette binding changes.
