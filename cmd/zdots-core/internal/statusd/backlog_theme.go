package statusd

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

type backlogTask struct {
	id       string
	title    string
	status   string
	priority string
	typ      string
	labels   []string
	created  string
	path     string
	body     string
}

var backlogDirs = []struct{ bucket, dir string }{
	{"active", "tasks"},
	{"completed", "completed"},
	{"draft", "drafts"},
}

func parseFrontmatter(raw string) (map[string]string, []string, string, bool) {
	if !strings.HasPrefix(raw, "---") {
		return nil, nil, "", false
	}
	parts := strings.SplitN(raw, "---", 3)
	if len(parts) < 3 {
		return nil, nil, "", false
	}
	fm := make(map[string]string)
	var labels []string
	inLabels := false
	for _, ln := range strings.Split(parts[1], "\n") {
		tr := strings.TrimSpace(ln)
		if tr == "" || strings.HasPrefix(tr, "#") {
			continue
		}
		if inLabels {
			if strings.HasPrefix(tr, "- ") {
				lbl := strings.TrimSpace(strings.TrimPrefix(tr, "- "))
				lbl = strings.Trim(lbl, `"'`)
				if lbl != "" {
					labels = append(labels, lbl)
				}
				continue
			}
			inLabels = false
		}
		if idx := strings.IndexByte(tr, ':'); idx > 0 {
			k := strings.TrimSpace(tr[:idx])
			v := strings.TrimSpace(tr[idx+1:])
			if k == "labels" {
				if strings.HasPrefix(v, "[") && strings.HasSuffix(v, "]") {
					inner := strings.TrimSuffix(strings.TrimPrefix(v, "["), "]")
					for _, p := range strings.Split(inner, ",") {
						p = strings.Trim(strings.TrimSpace(p), `"'`)
						if p != "" {
							labels = append(labels, p)
						}
					}
				} else if v == "" {
					inLabels = true
				}
				continue
			}
			fm[k] = strings.Trim(v, `"'`)
		}
	}
	return fm, labels, parts[2], true
}

func (e *serverEnv) loadBacklogTask(path, bucket string) *backlogTask {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	fm, labels, body, ok := parseFrontmatter(string(raw))
	if !ok {
		return nil
	}
	st := fm["status"]
	if st == "" {
		st = bucket
	}
	created := fm["created_date"]
	if len(created) > 10 {
		created = created[:10]
	}
	return &backlogTask{
		id: fm["id"], title: strings.TrimSpace(fm["title"]), status: st,
		priority: fm["priority"], typ: fm["type"], labels: labels,
		created: created, path: path, body: body,
	}
}

func (e *serverEnv) backlogIndex() string {
	byStatus := make(map[string][]*backlogTask)
	for _, bd := range backlogDirs {
		paths, _ := filepath.Glob(filepath.Join(e.zdotdir, "backlog", bd.dir, "*.md"))
		for _, p := range paths {
			if t := e.loadBacklogTask(p, bd.bucket); t != nil {
				byStatus[t.status] = append(byStatus[t.status], t)
			}
		}
	}
	docPaths, _ := filepath.Glob(filepath.Join(e.zdotdir, "backlog", "docs", "*.md"))
	var docs []string
	for _, p := range docPaths {
		docs = append(docs, h(strings.TrimSuffix(filepath.Base(p), ".md")))
	}
	sort.Strings(docs)

	statusRank := map[string]int{"In Progress": 0, "To Do": 1, "Draft": 2, "Done": 3}
	var statuses []string
	for k := range byStatus {
		statuses = append(statuses, k)
	}
	sort.Slice(statuses, func(i, j int) bool {
		ri, ok1 := statusRank[statuses[i]]
		if !ok1 {
			ri = 9
		}
		rj, ok2 := statusRank[statuses[j]]
		if !ok2 {
			rj = 9
		}
		if ri != rj {
			return ri < rj
		}
		return statuses[i] < statuses[j]
	})

	var kpis, sections strings.Builder
	prioRank := map[string]int{"high": 0, "medium": 1, "low": 2}
	for _, st := range statuses {
		list := byStatus[st]
		fmt.Fprintf(&kpis, `<div class="kpi"><b>%d</b> %s</div>`, len(list), h(st))
		sort.Slice(list, func(i, j int) bool {
			pi, ok1 := prioRank[list[i].priority]
			if !ok1 {
				pi = 3
			}
			pj, ok2 := prioRank[list[j].priority]
			if !ok2 {
				pj = 3
			}
			if pi != pj {
				return pi < pj
			}
			return list[i].id < list[j].id
		})
		var rows strings.Builder
		for _, t := range list {
			pr := ""
			if t.priority != "" {
				pr = fmt.Sprintf(`<span class="pr %s">%s</span>`, h(t.priority), h(t.priority))
			}
			var lbls strings.Builder
			for idx, l := range t.labels {
				if idx >= 4 {
					break
				}
				fmt.Fprintf(&lbls, `<span class="lb">%s</span>`, h(l))
			}
			idCell := ""
			if t.id != "" {
				idCell = fmt.Sprintf(`<a href="/backlog/%s">%s</a>`, h(t.id), h(t.id))
			}
			fmt.Fprintf(&rows, `<tr><td class="mono">%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td class="mono">%s</td></tr>`,
				idCell, pr, h(t.typ), h(t.title), lbls.String(), h(t.created))
		}
		fmt.Fprintf(&sections, `<h2>%s (%d)</h2><table><thead><tr><th>ID</th><th>Pri</th><th>Type</th><th>Title</th><th>Labels</th><th>Created</th></tr></thead><tbody>%s</tbody></table>`,
			h(st), len(list), rows.String())
	}

	return e.wrap("backlog", fmt.Sprintf(`<section aria-labelledby="bl-h">
  <h2 id="bl-h">Backlog — the plan of record</h2>
  <p class="dim">Read-only over backlog/ (Backlog.md). Edits go through the backlog CLI/MCP, never by hand. Docs: %s.</p>
  <div class="kpis">%s</div>%s</section>`, strings.Join(docs, " · "), kpis.String(), sections.String()))
}

func (e *serverEnv) renderBacklogTask(id string) (string, bool) {
	if !regexp.MustCompile(`^[A-Za-z][A-Za-z0-9._-]*$`).MatchString(id) {
		return "", false
	}
	var found *backlogTask
	for _, bd := range backlogDirs {
		paths, _ := filepath.Glob(filepath.Join(e.zdotdir, "backlog", bd.dir, "*.md"))
		for _, p := range paths {
			if t := e.loadBacklogTask(p, bd.bucket); t != nil && strings.EqualFold(t.id, id) {
				found = t
				break
			}
		}
		if found != nil {
			break
		}
	}
	if found == nil {
		return "", false
	}
	var meta strings.Builder
	for _, kv := range [][2]string{{"status", found.status}, {"priority", found.priority}, {"type", found.typ}} {
		if kv[1] != "" {
			fmt.Fprintf(&meta, `<span class="lb">%s: %s</span>`, h(kv[0]), h(kv[1]))
		}
	}
	for _, l := range found.labels {
		fmt.Fprintf(&meta, `<span class="lb">%s</span>`, h(l))
	}
	rendered := renderMarkdownHTML([]byte(found.body))
	return e.wrap(found.id+" (task)", fmt.Sprintf(`<section class="doc">
  <p class="dim"><a href="/backlog">↩ backlog</a> · %s</p>
  <h2>%s — %s</h2><p>%s</p>%s</section>`,
		h(filepath.Base(found.path)), h(found.id), h(found.title), meta.String(), rendered)), true
}

type themeData struct {
	Slug    string            `json:"slug"`
	Title   string            `json:"title"`
	Source  string            `json:"source"`
	Palette map[string]string `json:"palette"`
	ANSI    []string          `json:"ansi"`
	Tokens  map[string]string `json:"tokens"`
}

func (e *serverEnv) loadTheme() (*themeData, error) {
	name := envOr("ZDOTS_THEME", "kanagawa-wave")
	raw, err := os.ReadFile(filepath.Join(e.zdotdir, "etc", "themes", name+".yaml"))
	if err != nil {
		return nil, err
	}
	td := &themeData{
		Palette: make(map[string]string),
		Tokens:  make(map[string]string),
	}
	section := ""
	for _, ln := range strings.Split(string(raw), "\n") {
		if strings.TrimSpace(ln) == "" || strings.HasPrefix(strings.TrimSpace(ln), "#") {
			continue
		}
		if !strings.HasPrefix(ln, " ") && !strings.HasPrefix(ln, "\t") {
			tr := strings.TrimSpace(ln)
			if idx := strings.IndexByte(tr, ':'); idx > 0 {
				k := strings.TrimSpace(tr[:idx])
				v := strings.Trim(strings.TrimSpace(tr[idx+1:]), `"'`)
				switch k {
				case "slug":
					td.Slug = v
					section = ""
				case "title":
					td.Title = v
					section = ""
				case "source":
					td.Source = v
					section = ""
				case "palette", "tokens", "ansi":
					section = k
				default:
					section = ""
				}
			}
			continue
		}
		tr := strings.TrimSpace(ln)
		switch section {
		case "palette", "tokens":
			if idx := strings.IndexByte(tr, ':'); idx > 0 {
				k := strings.Trim(strings.TrimSpace(tr[:idx]), `"'`)
				v := strings.Trim(strings.TrimSpace(tr[idx+1:]), `"'#`)
				if section == "palette" {
					td.Palette[k] = v
				} else {
					td.Tokens[k] = v
				}
			}
		case "ansi":
			if strings.HasPrefix(tr, "- ") {
				v := strings.Trim(strings.TrimSpace(strings.TrimPrefix(tr, "- ")), `"'`)
				td.ANSI = append(td.ANSI, v)
			}
		}
	}
	return td, nil
}

func (e *serverEnv) themeJSON() []byte {
	td, err := e.loadTheme()
	if err != nil {
		b, _ := json.Marshal(map[string]string{"error": err.Error()})
		return b
	}
	b, _ := json.MarshalIndent(td, "", "  ")
	return append(b, '\n')
}

var waveTiers = []struct{ key, label, dims, file string }{
	{"fullhd", "Full HD", "1920×1080", "great-wave-fullhd-1920x1080-fill.png"},
	{"retina", "Retina", "2560×1600", "great-wave-retina-2560x1600-fill.png"},
	{"uhd4k", "4K UHD", "3840×2160", "great-wave-4k-3840x2160-fill.png"},
	{"retina5k", "Retina 5K", "5120×2880", "great-wave-retina5k-5120x2880-fill.png"},
}

func (e *serverEnv) waveTierPath(key string) string {
	for _, t := range waveTiers {
		if t.key == key {
			p := filepath.Join(e.home, "Pictures", "kanagawa-wave", t.file)
			if info, err := os.Stat(p); err == nil && !info.IsDir() {
				return p
			}
		}
	}
	return ""
}

func (e *serverEnv) themePage() string {
	td, err := e.loadTheme()
	if err != nil {
		return e.wrap("theme", fmt.Sprintf(`<section><h2>theme</h2><p class="lede">could not load palette: %s</p></section>`, h(err.Error())))
	}
	swatch := func(name, hex, sub string) string {
		subHTML := ""
		if sub != "" {
			subHTML = fmt.Sprintf(`<span class="rl">%s</span>`, h(sub))
		}
		return fmt.Sprintf(`<figure class="sw"><div class="chip" style="background:#%s"></div><figcaption><span class="nm">%s</span>%s<span class="hx">#%s</span></figcaption></figure>`,
			h(hex), h(name), subHTML, h(hex))
	}

	palKeys := make([]string, 0, len(td.Palette))
	for k := range td.Palette {
		palKeys = append(palKeys, k)
	}
	sort.Strings(palKeys)
	var palSW, tokSW, ansiSW, wpHTML strings.Builder
	for _, k := range palKeys {
		palSW.WriteString(swatch(k, td.Palette[k], ""))
	}
	tokKeys := make([]string, 0, len(td.Tokens))
	for k := range td.Tokens {
		tokKeys = append(tokKeys, k)
	}
	sort.Strings(tokKeys)
	for _, k := range tokKeys {
		name := td.Tokens[k]
		tokSW.WriteString(swatch("--"+k, td.Palette[name], name))
	}
	roles := []string{"black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"}
	for i, name := range td.ANSI {
		role := roles[i%8]
		if i >= 8 {
			role = "br " + role
		}
		ansiSW.WriteString(swatch(fmt.Sprintf("%d · %s", i, role), td.Palette[name], name))
	}
	for _, wt := range waveTiers {
		p := filepath.Join(e.home, "Pictures", "kanagawa-wave", wt.file)
		if info, err := os.Stat(p); err == nil && !info.IsDir() {
			mb := float64(info.Size()) / 1048576.0
			fmt.Fprintf(&wpHTML, `<li><a href="/theme/download/%s">%s</a> <span class="dim">%s · %.1f&nbsp;MB PNG</span></li>`, h(wt.key), h(wt.label), h(wt.dims), mb)
		} else {
			fmt.Fprintf(&wpHTML, `<li class="dim">%s <span>%s — not generated on this machine</span></li>`, h(wt.label), h(wt.dims))
		}
	}

	inner := fmt.Sprintf(`<section class="doc">
  <div class="hero"><h1>%s</h1><p class="src">%s</p></div>
  <p class="lede">Full prose: <a href="/docs/docs:styleguide:colorschemes">the styleguide</a>.</p>
</section>
<section><h2>Palette <span class="dim">(%d)</span></h2><div class="swatches">%s</div></section>
<section><h2>Semantic tokens</h2><div class="swatches">%s</div></section>
<section><h2>Terminal ANSI 0–15</h2><div class="swatches">%s</div></section>
<section><h2>Wallpapers</h2><ul class="eps">%s</ul></section>
<section><h2>Reference</h2><ul class="eps"><li><a href="/theme/palette.json">palette.json</a></li><li><a href="/docs/docs:styleguide:colorschemes">styleguide</a></li></ul></section>`,
		h(td.Title), h(td.Source), len(td.Palette), palSW.String(), tokSW.String(), ansiSW.String(), wpHTML.String())
	return e.wrap("theme — "+td.Title, inner)
}
