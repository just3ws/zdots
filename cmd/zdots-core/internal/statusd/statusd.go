package statusd

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/ctlstatus"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/zsvc"
)

func usage() string {
	return `Usage: zdots-statusd            # serve the control-plane console (foreground)

The zdots.localhost status console — a no-dep loopback HTTP server rendering live
platform health (zdots-ctl status, zsvc, service logs). Binds
127.0.0.1:${ZDOTS_STATUS_PORT:-11600}. Routes: GET / (console), GET /map
(interactive topology with hostname families, nginx path-to-upstream routes,
ports, and system connections), GET /map.json (sanitized live snapshot), GET /healthz,
GET /man, GET /docs, GET /help, GET /backlog (read-only Backlog.md board), GET /theme.
The lan.just3ws.com vhost exposes only /map and /map.json.

Don't run this by hand for normal use — manage it as a Platform Service:
  zsvc start|stop|restart|status|logs status

Env:
  ZDOTS_STATUS_PORT   listen port (default 11600)
  ZDOTDIR             zdots root
`
}

type serverEnv struct {
	host     string
	port     int
	home     string
	zdotdir  string
	binDir   string
	stateDir string
	waveImg  []byte
	tokens   string
	css      string
	tr       *otel.Tracer
}

func newServerEnv() (*serverEnv, error) {
	host := envOr("ZDOTS_STATUS_HOST", "127.0.0.1")
	if host != "127.0.0.1" && host != "localhost" && host != "::1" {
		return nil, fmt.Errorf("zdots-statusd: error: ZDOTS_STATUS_HOST must be loopback (127.0.0.1, localhost or ::1), got: %s", host)
	}
	port := 11600
	if p, err := strconv.Atoi(envOr("ZDOTS_STATUS_PORT", "11600")); err == nil && p > 0 {
		port = p
	}
	home, _ := os.UserHomeDir()
	zdotdir := envOr("ZDOTDIR", filepath.Join(home, ".config", "zsh"))
	xdgState := envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	stateDir := filepath.Join(xdgState, "zsh")

	waveImg, _ := os.ReadFile(filepath.Join(zdotdir, "assets", "kanagawa-wave", "great-wave.jpg"))
	tokensBytes, err := os.ReadFile(filepath.Join(zdotdir, "assets", "craftsmanship", "tokens.css"))
	tokens := defaultTokensCSS
	if err == nil {
		tokens = string(tokensBytes)
	}

	return &serverEnv{
		host:     host,
		port:     port,
		home:     home,
		zdotdir:  zdotdir,
		binDir:   filepath.Join(zdotdir, "bin"),
		stateDir: stateDir,
		waveImg:  waveImg,
		tokens:   tokens,
		css:      buildCSS(tokens),
		tr:       otel.New("zdots-statusd"),
	}, nil
}

// Run executes the zdots-statusd HTTP server and returns the exit code.
func Run(args []string) int {
	if len(args) > 0 && (args[0] == "-h" || args[0] == "--help") {
		fmt.Print(usage())
		return 0
	}
	env, err := newServerEnv()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}

	addr := fmt.Sprintf("%s:%d", env.host, env.port)
	if strings.Contains(env.host, ":") {
		addr = fmt.Sprintf("[%s]:%d", env.host, env.port)
	}
	srv := &http.Server{
		Addr:              addr,
		Handler:           env.handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = srv.Shutdown(ctx)
	}()

	fmt.Fprintf(os.Stderr, "zdots-statusd listening on http://%s\n", addr)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		fmt.Fprintf(os.Stderr, "zdots-statusd: %v\n", err)
		return 1
	}
	return 0
}

type statusRecorder struct {
	http.ResponseWriter
	code int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.code = code
	r.ResponseWriter.WriteHeader(code)
}

func (e *serverEnv) handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sp := e.tr.Start("statusd.http", nil)
		sp.SetAttr("http.method", r.Method)
		sp.SetAttr("http.path", r.URL.Path)
		rec := &statusRecorder{ResponseWriter: w, code: http.StatusOK}
		defer func() {
			sp.SetAttr("http.status_code", rec.code)
			sp.End(rec.code < 500, "")
			go e.tr.Flush(250 * time.Millisecond)
		}()

		p := r.URL.Path
		switch {
		case p == "/healthz":
			writeResp(rec, http.StatusOK, "text/plain; charset=utf-8", []byte("ok"))
		case p == "/map" || p == "/map/":
			writeHTML(rec, e.topologyPage())
		case p == "/map.json":
			writeResp(rec, http.StatusOK, "application/json; charset=utf-8", e.topologyJSON())
		case p == "/man" || p == "/man/":
			writeHTML(rec, e.manIndex())
		case strings.HasPrefix(p, "/man/"):
			cmd := strings.TrimPrefix(p, "/man/")
			if page, ok := e.renderMan(cmd); ok {
				writeHTML(rec, page)
			} else {
				writeResp(rec, http.StatusNotFound, "text/plain", []byte("no such man page"))
			}
		case p == "/theme/great-wave.jpg":
			if len(e.waveImg) > 0 {
				rec.Header().Set("Cache-Control", "max-age=86400")
				writeResp(rec, http.StatusOK, "image/jpeg", e.waveImg)
			} else {
				writeResp(rec, http.StatusNotFound, "text/plain", []byte("no image"))
			}
		case p == "/theme/palette.json":
			writeResp(rec, http.StatusOK, "application/json", e.themeJSON())
		case p == "/theme/fonts/FiraCodeNerdFontMono-Retina.ttf":
			fp := filepath.Join(e.zdotdir, "assets", "craftsmanship", "FiraCodeNerdFontMono-Retina.ttf")
			if b, err := os.ReadFile(fp); err == nil {
				rec.Header().Set("Cache-Control", "max-age=86400")
				writeResp(rec, http.StatusOK, "font/ttf", b)
			} else {
				writeResp(rec, http.StatusNotFound, "text/plain", []byte("font not found"))
			}
		case strings.HasPrefix(p, "/theme/download/"):
			key := strings.TrimPrefix(p, "/theme/download/")
			if wp := e.waveTierPath(key); wp != "" {
				if b, err := os.ReadFile(wp); err == nil {
					rec.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, filepath.Base(wp)))
					rec.Header().Set("Cache-Control", "max-age=86400")
					writeResp(rec, http.StatusOK, "image/png", b)
					return
				}
			}
			writeResp(rec, http.StatusNotFound, "text/plain", []byte("no such wallpaper"))
		case p == "/theme" || p == "/theme/":
			writeHTML(rec, e.themePage())
		case p == "/backlog" || p == "/backlog/":
			writeHTML(rec, e.backlogIndex())
		case strings.HasPrefix(p, "/backlog/"):
			id := strings.TrimPrefix(p, "/backlog/")
			if page, ok := e.renderBacklogTask(id); ok {
				writeHTML(rec, page)
			} else {
				writeResp(rec, http.StatusNotFound, "text/plain", []byte("no such task"))
			}
		case p == "/docs" || p == "/docs/":
			writeHTML(rec, e.docsIndex())
		case strings.HasPrefix(p, "/docs/"):
			key := strings.TrimPrefix(p, "/docs/")
			if page, ok := e.renderDoc(key); ok {
				writeHTML(rec, page)
			} else {
				writeResp(rec, http.StatusNotFound, "text/plain", []byte("no such doc"))
			}
		case p == "/help" || p == "/help/":
			writeHTML(rec, e.helpIndex())
		case strings.HasPrefix(p, "/help/"):
			cmd := strings.TrimPrefix(p, "/help/")
			if page, ok := e.renderHelp(cmd); ok {
				writeHTML(rec, page)
			} else {
				writeResp(rec, http.StatusNotFound, "text/plain", []byte("no such command"))
			}
		case p == "/" || p == "":
			live := r.URL.Query().Get("live") != "0"
			writeHTML(rec, e.renderConsole(live))
		default:
			writeResp(rec, http.StatusNotFound, "text/plain", []byte("not found"))
		}
	})
}

func writeResp(w http.ResponseWriter, code int, ctype string, body []byte) {
	w.Header().Set("Content-Type", ctype)
	w.Header().Set("Content-Length", strconv.Itoa(len(body)))
	w.WriteHeader(code)
	_, _ = w.Write(body)
}

func writeHTML(w http.ResponseWriter, body string) {
	writeResp(w, http.StatusOK, "text/html; charset=utf-8", []byte(body))
}

func h(s string) string { return html.EscapeString(s) }

type svcRow struct {
	name, state, pid, endpoint string
}

func (e *serverEnv) services() []svcRow {
	out := zsvc.ListText(e.zdotdir)
	var rows []svcRow
	re := regexp.MustCompile(`\s{2,}`)
	for _, ln := range strings.Split(out, "\n") {
		tr := strings.TrimSpace(ln)
		if tr == "" || strings.HasPrefix(tr, "SERVICE") || strings.HasPrefix(tr, "-") {
			continue
		}
		cols := re.Split(tr, -1)
		if len(cols) < 2 {
			continue
		}
		pid, ep := "-", "-"
		if len(cols) > 2 {
			pid = cols[2]
		}
		if len(cols) > 3 {
			ep = cols[3]
		}
		rows = append(rows, svcRow{name: cols[0], state: cols[1], pid: pid, endpoint: ep})
	}
	return rows
}

func (e *serverEnv) platformVersions() map[string]*string {
	xdgCfg := envOr("XDG_CONFIG_HOME", filepath.Join(e.home, ".config"))
	paths := map[string]string{
		"zdots":             filepath.Join(e.zdotdir, "VERSION"),
		"adots":             filepath.Join(e.home, "VERSION"),
		"my":                filepath.Join(e.home, "my", "VERSION"),
		"vdots":             filepath.Join(xdgCfg, "nvim", "VERSION"),
		"ztranscribe":       filepath.Join(envOr("ZDOTS_ZTRANSCRIBE_ROOT", filepath.Join(e.home, "github.com", "just3ws", "ztranscribe")), "VERSION"),
		"media-pipeline":    filepath.Join(envOr("MEDIA_PIPELINE_ROOT", filepath.Join(e.home, "github.com", "just3ws", "media-pipeline")), "VERSION"),
		"just3ws.github.io": filepath.Join(envOr("JUST3WS_SITE_ROOT", filepath.Join(e.home, "github.com", "just3ws", "just3ws.github.io")), "VERSION"),
	}
	res := make(map[string]*string, len(paths))
	for name, p := range paths {
		if b, err := os.ReadFile(p); err == nil {
			v := strings.TrimSpace(string(b))
			res[name] = &v
		} else {
			res[name] = nil
		}
	}
	return res
}

func (e *serverEnv) topology() map[string]any {
	raw, err := os.ReadFile(filepath.Join(e.zdotdir, "etc", "system-topology.json"))
	if err != nil {
		return map[string]any{"nodes": []any{}, "links": []any{}}
	}
	var m map[string]any
	if json.Unmarshal(raw, &m) != nil {
		return map[string]any{"nodes": []any{}, "links": []any{}}
	}
	return m
}

func (e *serverEnv) topologyWithVersions() map[string]any {
	atlas := e.topology()
	versions := e.platformVersions()
	atlas["platform_versions"] = versions
	if nodes, ok := atlas["nodes"].([]any); ok {
		for _, item := range nodes {
			if node, ok := item.(map[string]any); ok {
				if key, _ := node["version_key"].(string); key != "" {
					if v := versions[key]; v != nil {
						node["version"] = *v
					}
				}
			}
		}
	}
	return atlas
}

func (e *serverEnv) topologyJSON() []byte {
	atlas := e.topologyWithVersions()
	var rows []svcRow
	var st ctlstatus.Status
	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); rows = e.services() }()
	go func() { defer wg.Done(); st = ctlstatus.Probe(e.zdotdir) }()
	wg.Wait()

	nonAlnum := regexp.MustCompile(`[^a-z0-9]+`)
	stateByKey := make(map[string]string, len(rows))
	for _, r := range rows {
		k := nonAlnum.ReplaceAllString(strings.ToLower(r.name), "-")
		stateByKey[k] = r.state
	}
	platformBytes, _ := json.Marshal(st)
	var platform map[string]any
	_ = json.Unmarshal(platformBytes, &platform)

	type nodeSnap struct {
		ID      string  `json:"id"`
		State   string  `json:"state"`
		Health  any     `json:"health"`
		Version *string `json:"version"`
	}
	rawNodes, _ := atlas["nodes"].([]any)
	snaps := make([]nodeSnap, len(rawNodes))
	var nwg sync.WaitGroup
	for i, item := range rawNodes {
		nwg.Add(1)
		go func(idx int, raw any) {
			defer nwg.Done()
			node, _ := raw.(map[string]any)
			id, _ := node["id"].(string)
			key, _ := node["service_key"].(string)
			state := "catalogued"
			if key != "" {
				if s, ok := stateByKey[key]; ok {
					state = s
				} else {
					state = "unobserved"
				}
			}
			var health any
			if hk, ok := node["health_key"].(string); ok && hk != "" {
				health = platform[hk]
			}
			if hu, ok := node["health_url"].(string); ok && hu != "" {
				health = httpHealthy(hu)
			}
			var ver *string
			if v, ok := node["version"].(string); ok && v != "" {
				ver = &v
			}
			snaps[idx] = nodeSnap{ID: id, State: state, Health: health, Version: ver}
		}(i, item)
	}
	nwg.Wait()

	running, checked, unhealthy := 0, 0, 0
	for _, n := range snaps {
		if n.State == "running" {
			running++
		}
		if n.Health != nil {
			checked++
			if b, ok := n.Health.(bool); ok && !b {
				unhealthy++
			}
		}
	}
	payload := map[string]any{
		"checked_at":        time.Now().UTC().Format(time.RFC3339),
		"platform_versions": atlas["platform_versions"],
		"summary":           map[string]int{"running": running, "checked": checked, "unhealthy": unhealthy},
		"nodes":             snaps,
	}
	b, _ := json.Marshal(payload)
	return b
}

func httpHealthy(url string) bool {
	c := &http.Client{Timeout: 600 * time.Millisecond}
	resp, err := c.Get(url)
	if err != nil {
		return false
	}
	_ = resp.Body.Close()
	return resp.StatusCode >= 200 && resp.StatusCode < 300
}

func (e *serverEnv) topologyPage() string {
	atlas := e.topologyWithVersions()
	versions, _ := atlas["platform_versions"].(map[string]*string)
	beacon := ""
	if versions != nil && versions["zdots"] != nil {
		beacon = *versions["zdots"]
	}
	var versionCards strings.Builder
	for _, pair := range [][2]string{
		{"zdots", "zdots"}, {"adots", "adots"}, {"my", "my"}, {"vdots", "vdots"},
		{"ztranscribe", "ztranscribe"}, {"media-pipeline", "media-pipeline"}, {"just3ws.github.io", "just3ws site"},
	} {
		var ver *string
		if versions != nil {
			ver = versions[pair[0]]
		}
		state, text := "missing", "no VERSION"
		if ver != nil {
			text = *ver
			if *ver == beacon {
				state = "aligned"
			} else {
				state = "drift"
			}
		}
		fmt.Fprintf(&versionCards, `<div class="version-card %s"><b>%s</b><span>%s</span></div>`, state, h(pair[1]), h(text))
	}

	rawNodes, _ := atlas["nodes"].([]any)
	nodeByID := make(map[string]map[string]any, len(rawNodes))
	var graphNodes strings.Builder
	svcRegCount := 0
	for _, item := range rawNodes {
		node, ok := item.(map[string]any)
		if !ok {
			continue
		}
		id, _ := node["id"].(string)
		nodeByID[id] = node
		sk, _ := node["service_key"].(string)
		hk, _ := node["health_key"].(string)
		hu, _ := node["health_url"].(string)
		if sk != "" {
			svcRegCount++
		}
		statusHTML := ""
		if sk != "" || hk != "" || hu != "" {
			statusHTML = fmt.Sprintf(`<span class="state" data-node-state="%s">checking</span>`, h(id))
		}
		verHTML := ""
		if v, _ := node["version"].(string); v != "" {
			verHTML = fmt.Sprintf(`<small class="node-version">%s</small>`, h(v))
		}
		kind, _ := node["kind"].(string)
		label, _ := node["label"].(string)
		port := fmt.Sprint(node["port"])
		if node["port"] == nil {
			port = ""
		}
		fmt.Fprintf(&graphNodes, `<button class="node %s" data-node="%s" style="--x:%v;--y:%v" type="button"><b>%s</b><small>%s</small>%s%s</button>`,
			h(kind), h(id), node["x"], node["y"], h(label), h(port), verHTML, statusHTML)
	}

	rawLinks, _ := atlas["links"].([]any)
	var graphLinks strings.Builder
	for _, item := range rawLinks {
		link, ok := item.(map[string]any)
		if !ok {
			continue
		}
		fID, _ := link["from"].(string)
		tID, _ := link["to"].(string)
		from, ok1 := nodeByID[fID]
		to, ok2 := nodeByID[tID]
		if !ok1 || !ok2 {
			continue
		}
		fmt.Fprintf(&graphLinks, `<line x1="%v%%" y1="%v%%" x2="%v%%" y2="%v%%" data-link-from="%s" data-link-to="%s" />`,
			from["x"], from["y"], to["x"], to["y"], h(fID), h(tID))
	}

	rawFamilies, _ := atlas["hostname_families"].([]any)
	var familyCards strings.Builder
	for _, item := range rawFamilies {
		fam, ok := item.(map[string]any)
		if !ok {
			continue
		}
		fmt.Fprintf(&familyCards, `<div class="domain-family"><b>%s · %s</b><small>Local: %s<br>LAN: %s<br>%s</small></div>`,
			h(fmt.Sprint(fam["owner"])), h(fmt.Sprint(fam["status"])),
			h(fmt.Sprint(fam["local_pattern"])), h(fmt.Sprint(fam["lan_pattern"])), h(fmt.Sprint(fam["notes"])))
	}

	catBytes, _ := json.Marshal(atlas)
	catalog := strings.ReplaceAll(string(catBytes), "</", "<\\/")
	beaconTitle := beacon
	if beaconTitle == "" {
		beaconTitle = "beacon missing"
	}

	return fmt.Sprintf(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>LAN System Map</title>
  <style>
    %s
    body { min-height: 100vh; }
    .map-head { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-start; flex-wrap: wrap; }
    .map-head h1 { font-size: 1.6rem; }
    .map-head p { max-width: 48rem; }
    .version-ribbon { display: flex; flex-direction: column; gap: .5rem; margin: 0 0 1rem; }
    .version-ribbon h2 { margin: 0; border: 0; padding: 0; color: var(--text); font-size: .78rem; }
    .version-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(9rem, 1fr)); gap: .5rem; }
    .version-card { display: flex; flex-direction: column; gap: .2rem; min-width: 0; padding: .5rem .65rem; border: 1px solid var(--border); border-radius: 8px; background: var(--surface); }
    .version-card b { font-size: .7rem; color: var(--text-dim); }
    .version-card span { font: .73rem var(--mono); overflow-wrap: anywhere; }
    .version-card.aligned { border-color: rgba(5,150,105,.35); }
    .version-card.drift, .version-card.missing { border-color: rgba(180,83,9,.55); }
    .map-shell { display: grid; grid-template-columns: minmax(0, 1fr) minmax(16rem, 22rem); gap: 1rem; align-items: start; }
    .map-canvas { position: relative; height: calc(100vh - 17rem); min-height: 40rem; max-height: 70rem; overflow: auto; background: radial-gradient(ellipse at center, rgba(15,118,110,.07), transparent 70%%), var(--bg); border: 1px solid var(--border); border-radius: 16px; padding: 1rem; }
    .map-stage { position: relative; min-width: 1000px; height: 100%%; min-height: 38rem; }
    .map-stage svg { position: absolute; inset: 0; width: 100%%; height: 100%%; overflow: visible; }
    .map-stage line { stroke: var(--accent); stroke-width: 1.4; opacity: .4; vector-effect: non-scaling-stroke; }
    .map-stage line.active { stroke: var(--green); stroke-width: 2.3; opacity: .9; }
    .region { position: absolute; left: 0; right: 0; border-top: 1px dashed var(--border); color: var(--text-dim); font: .68rem var(--mono); padding-top: .15rem; pointer-events: none; }
    .region.r1 { top: 1.5%%; } .region.r2 { top: 22%%; } .region.r3 { top: 47%%; } .region.r3b { top: 61%%; } .region.r4 { top: 73%%; }
    .node { position: absolute; left: calc(var(--x) * 1%%); top: calc(var(--y) * 1%%); transform: translate(-50%%, -50%%); min-width: 9rem; max-width: 12rem; min-height: 4.5rem; background: var(--surface); color: var(--text); border: 1px solid var(--border); border-radius: 10px; padding: .55rem .7rem; text-align: left; cursor: pointer; box-shadow: var(--craft-shadow); z-index: 1; }
    .node:hover, .node:focus-visible, .node.selected { border-color: var(--accent); box-shadow: 0 0 0 2px rgba(91,141,238,.18); }
    .node.edge { border-top: 3px solid var(--accent); } .node.route { border-top: 3px solid var(--yellow); } .node.app { border-top: 3px solid var(--accent); } .node.core { border-top: 3px solid var(--green); } .node.data { border-top: 3px solid var(--yellow); } .node.telemetry { border-top: 3px solid #957fb8; }
    .node small, .node .state { display: block; color: var(--text-dim); font: .7rem var(--mono); margin-top: .2rem; }
    .node .node-version { color: var(--accent); font-size: .62rem; }
    .node .state[data-state="running"], .node .state[data-state="healthy"] { color: var(--green); }
    .node .state[data-state="stopped"] { color: var(--yellow); }
    .node .state[data-state="unobserved"], .node .state[data-state="catalogued"] { color: var(--text-dim); }
    .node .state[data-state="unhealthy"] { color: var(--red-text); }
    .detail { position: sticky; top: 1rem; background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 1rem; }
    .detail h2 { font-size: 1rem; text-transform: none; letter-spacing: 0; color: var(--text); }
    .detail dt { color: var(--text-dim); font-size: .72rem; text-transform: uppercase; margin-top: .8rem; }
    .detail dd { margin: .1rem 0 0; font-size: .85rem; overflow-wrap: anywhere; }
    .detail dd small { display: block; color: var(--text-dim); }
    .detail a { display: inline-block; margin: .3rem .7rem .1rem 0; }
    .detail button { border: 0; background: none; color: var(--accent); text-decoration: underline; cursor: pointer; padding: 0; font: inherit; }
    .map-foot { font-size: .78rem; color: var(--text-dim); }
    .system-links { display: flex; gap: .6rem; flex-wrap: wrap; }
    .system-links a { padding: .45rem .7rem; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; text-decoration: none; }
    .domain-families { display: grid; grid-template-columns: repeat(auto-fit,minmax(14rem,1fr)); gap: .6rem; margin: 1rem 0; }
    .domain-family { padding: .65rem .8rem; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; font-size: .8rem; }
    .domain-family b, .domain-family small { display: block; }
    .domain-family small { color: var(--text-dim); margin-top: .2rem; }
    @media (max-width: 850px) { .map-shell { grid-template-columns: 1fr; } .detail { position: static; } .map-canvas { height: 48rem; min-height: 48rem; } .map-stage { height: 46rem; } }
  </style>
</head>
<body>
  <main class="system-atlas">
    <header class="map-head">
      <div>
        <h1>System Atlas <span class="mark">· LAN</span></h1>
        <p class="sub">A connectionist map of the local system. Move from the network edge inward through routes, applications, and shared infrastructure. Select a node to inspect hostname families, request paths, backend ports, health signals, and connected systems.</p>
      </div>
      <div class="sub"><span id="map-summary">Checking service state…</span><br>Observed <time id="checked-at">—</time></div>
    </header>
    <section class="version-ribbon" aria-label="Astronomicon version status">
      <h2>Astronomicon · %s <span class="dim">· all release markers</span></h2>
      <div class="version-cards">%s</div>
      <p class="sub">SwiftBar reads the zdots epoch; my keeps the separate my.structure.v1 content contract.</p>
    </section>
    <nav class="system-links" aria-label="System views">
      <a data-local-only href="https://zdots.localhost/">zdots control plane · this Mac</a>
      <a href="https://media-pipeline.lan.just3ws.com">Media Pipeline · LAN</a>
      <a href="https://lan.phalanxduel.com">Phalanx Duel · LAN</a>
    </nav>
    <section class="domain-families" aria-label="Hostname families">%s</section>
    <section class="map-shell">
      <div class="map-canvas" aria-label="Interactive system topology">
        <div class="map-stage">
          <span class="region r1">NETWORK EDGE · browser, DNS, HTTPS</span>
          <span class="region r2">ROUTING · nginx and named entrypoints</span>
          <span class="region r3">APPLICATIONS · owned workflows</span>
          <span class="region r3b">ON-DEMAND · project apps and optional coordinator</span>
          <span class="region r4">SHARED CORE · data, inference, telemetry</span>
          <svg viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">%s</svg>
          %s
        </div>
      </div>
      <aside class="detail" id="node-detail" aria-live="polite">
        <h2>Select a node</h2><p class="sub">The detail panel follows the selected point in the map.</p>
      </aside>
    </section>
    <p class="map-foot">%d nodes · %d connections · %d service-registry entries.</p>
    <script type="application/json" id="topology-catalog">%s</script>
    <script>
      (() => {
        const catalog = JSON.parse(document.getElementById("topology-catalog").textContent);
        const detail = document.getElementById("node-detail");
        const lanView = location.hostname === "lan.just3ws.com";
        let snapshot = { nodes: [] };
        if (lanView) { document.querySelectorAll("[data-local-only]").forEach((el) => { el.hidden = true; }); }
        function stateFor(node) { if (node.health === true) return "healthy"; if (node.health === false) return "unhealthy"; return node.state || "catalogued"; }
        function select(id) {
          const node = catalog.nodes.find((item) => item.id === id); if (!node) return;
          document.querySelectorAll(".node").forEach((b) => b.classList.toggle("selected", b.dataset.node === id));
          document.querySelectorAll("svg line").forEach((l) => l.classList.toggle("active", l.dataset.linkFrom === id || l.dataset.linkTo === id));
          const connected = catalog.links.filter((l) => l.from === id || l.to === id);
          const linkMarkup = connected.map((l) => {
            const other = catalog.nodes.find((item) => item.id === (l.from === id ? l.to : l.from));
            return other ? '<span><button type="button" data-select="' + other.id + '">' + other.label + '</button><small>' + l.label + '</small></span>' : '';
          }).join('');
          const observed = snapshot.nodes.find((item) => item.id === id) || {};
          const route = lanView ? node.lan_href : node.href;
          const open = route ? '<a href="' + route + '" rel="noreferrer">' + route + '</a>' : (node.href ? node.href + ' · available on this Mac only' : 'No web route');
          const health = observed.health === true ? 'healthy' : (observed.health === false ? 'unhealthy' : 'not checked');
          detail.innerHTML = '<h2>' + node.label + '</h2><p class="sub">' + node.description + '</p><dl>' +
            '<dt>Area</dt><dd>' + node.area + '</dd><dt>Owner</dt><dd>' + node.owner + '</dd>' +
            '<dt>Process / port</dt><dd>' + (node.process || '—') + ' · ' + (node.port || '—') + '</dd>' +
            '<dt>Process state</dt><dd>' + (observed.state || 'checking') + '</dd>' +
            '<dt>Health</dt><dd><span class="state" data-state="' + stateFor(observed) + '">' + health + '</span></dd>' +
            '<dt>Open</dt><dd>' + open + '</dd><dt>Connected to</dt><dd>' + (linkMarkup || '—') + '</dd></dl>';
          detail.querySelectorAll('[data-select]').forEach((b) => b.addEventListener('click', () => select(b.dataset.select)));
        }
        async function refresh() {
          try {
            const resp = await fetch('/map.json', { cache: 'no-store' });
            if (!resp.ok) throw new Error('status unavailable');
            snapshot = await resp.json();
            document.getElementById('checked-at').textContent = new Date(snapshot.checked_at).toLocaleString();
            document.getElementById('map-summary').textContent = snapshot.summary.checked + ' health checks · ' + snapshot.summary.unhealthy + ' need attention · ' + snapshot.summary.running + ' processes running';
            snapshot.nodes.forEach((n) => { const s = document.querySelector('[data-node-state="' + n.id + '"]'); if (s) { s.textContent = stateFor(n); s.dataset.state = stateFor(n); } });
            const sel = document.querySelector('.node.selected'); if (sel) select(sel.dataset.node);
          } catch (_e) { document.getElementById('map-summary').textContent = 'Live status unavailable'; }
        }
        document.querySelectorAll(".node").forEach((b) => b.addEventListener("click", () => select(b.dataset.node)));
        if (catalog.nodes[0]) select(catalog.nodes[0].id);
        refresh(); setInterval(refresh, 30000);
      })();
    </script>
  </main>
</body>
</html>`, e.css, h(beaconTitle), versionCards.String(), familyCards.String(), graphLinks.String(), graphNodes.String(), len(rawNodes), len(rawLinks), svcRegCount, catalog)
}

func (e *serverEnv) renderConsole(live bool) string {
	var st ctlstatus.Status
	var svcs []svcRow
	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); st = ctlstatus.Probe(e.zdotdir) }()
	go func() { defer wg.Done(); svcs = e.services() }()
	wg.Wait()

	cards := []struct {
		label string
		up    bool
	}{
		{"Colima (Docker VM)", st.Colima},
		{"OpenObserve", st.OpenObserve},
		{"OTel Collector", st.OTelCollector},
		{"Inference (llama.cpp)", st.AIServer},
		{"Embed server", st.EmbedServer},
		{"Knowledge Layer", st.IntelligenceSuite},
		{"Redis", st.Cache},
		{"zdots-worker", st.Worker},
	}
	upCount := 0
	var cardsHTML strings.Builder
	for _, c := range cards {
		if c.up {
			upCount++
		}
		cardsHTML.WriteString(fmt.Sprintf(`<div class="card"><div class="lbl">%s</div>%s</div>`, h(c.label), pill(c.up)))
	}

	var svcRowsHTML strings.Builder
	var svcNames []string
	for _, s := range svcs {
		svcNames = append(svcNames, s.name)
		svcRowsHTML.WriteString(fmt.Sprintf(`<tr><td>%s</td><td>%s</td><td class="mono">%s</td><td class="mono">%s</td></tr>`,
			e.svcLink(s.name), pill(s.state == "running"), h(s.pid), h(s.endpoint)))
	}

	var logRowsHTML strings.Builder
	for _, l := range e.logHealth(svcNames) {
		p := `<span class="pill ok">clean</span>`
		if l.errors > 0 {
			p = fmt.Sprintf(`<span class="pill warn">%d</span>`, l.errors)
		}
		logRowsHTML.WriteString(fmt.Sprintf(`<tr><td class="mono">%s</td><td>%s</td></tr>`, h(l.name), p))
	}

	epsHTML := fmt.Sprintf(
		`<li class="mono">o2_url: %s</li><li class="mono">ai_endpoint: %s</li><li class="mono">embed_endpoint: %s</li><li class="mono">otlp_endpoint: %s</li>`,
		h(st.O2URL), h(st.AIEndpoint), h(st.EmbedEndpoint), h(st.OTLPEndpoint))

	refresh := ""
	toggle := `<a href="/">▶ resume live</a>`
	if live {
		refresh = `<meta http-equiv="refresh" content="10">`
		toggle = `<a href="/?live=0">⏸ pause</a>`
	}
	now := time.Now().Format("2006-01-02 15:04:05")

	return fmt.Sprintf(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>zdots.localhost — Control Plane</title>%s<style>%s</style></head>
<body>
<header><h1><span class="mark">zdots</span>.localhost</h1>
<p class="sub">Observable Control Plane · %d/%d services up · %s · <a href="/map">system map</a> · <a href="https://lan.just3ws.com">LAN Atlas ↗</a> · <a href="/man">man</a> · <a href="/docs">docs</a> · <a href="/help">help</a> · <a href="/backlog">backlog</a> · <span class="live">%s</span></p></header>
<main>
<section aria-labelledby="svc-h"><h2 id="svc-h">Platform Services</h2><div class="grid">%s</div></section>
<section aria-labelledby="ld-h"><h2 id="ld-h">launchd / processes</h2><table><thead><tr><th>Service</th><th>State</th><th>PID</th><th>Endpoint</th></tr></thead><tbody>%s</tbody></table></section>
<section aria-labelledby="log-h"><h2 id="log-h">Log health <span class="dim">(errors in last 400 lines)</span></h2><table><thead><tr><th>Log</th><th>Errors</th></tr></thead><tbody>%s</tbody></table></section>
<section aria-labelledby="ep-h"><h2 id="ep-h">Endpoints</h2><ul class="eps">%s</ul></section>
</main></body></html>`,
		refresh, e.css, upCount, len(cards), now, toggle, cardsHTML.String(), svcRowsHTML.String(), logRowsHTML.String(), epsHTML)
}

func pill(up bool) string {
	if up {
		return `<span class="pill ok">up</span>`
	}
	return `<span class="pill down">down</span>`
}

func (e *serverEnv) svcLink(name string) string {
	base := strings.SplitN(name, "@", 2)[0]
	manMap := map[string]string{
		"llama-server": "llama-ctl", "llama-embed": "llama-ctl",
		"otel-collector": "otel-collector", "openobserve": "openobserve-ctl", "whisper": "whisper-ctl",
	}
	man := manMap[base]
	if man == "" {
		man = base
	}
	if matches, _ := filepath.Glob(filepath.Join(e.zdotdir, "man", "man*", man+".*")); len(matches) > 0 {
		return fmt.Sprintf(`<a href="/man/%s">%s</a>`, h(man), h(name))
	}
	return h(name)
}

func (e *serverEnv) logHealth(svcNames []string) []struct {
	name   string
	errors int
} {
	keys := []string{"zdots-worker"}
	for _, n := range svcNames {
		keys = append(keys, strings.SplitN(n, "@", 2)[0])
	}
	paths, _ := filepath.Glob(filepath.Join(e.stateDir, "*.log"))
	sort.Strings(paths)
	errRe := regexp.MustCompile(`(?i)\b(ERROR|FAILED|FATAL)\b`)
	var out []struct {
		name   string
		errors int
	}
	for _, p := range paths {
		name := strings.TrimSuffix(filepath.Base(p), ".log")
		matched := false
		for _, k := range keys {
			if strings.Contains(name, k) {
				matched = true
				break
			}
		}
		if !matched {
			continue
		}
		data, err := os.ReadFile(p)
		if err != nil || len(data) == 0 {
			continue
		}
		lines := strings.Split(string(data), "\n")
		if len(lines) > 400 {
			lines = lines[len(lines)-400:]
		}
		errs := 0
		for _, ln := range lines {
			if errRe.MatchString(ln) {
				errs++
			}
		}
		out = append(out, struct {
			name   string
			errors int
		}{name, errs})
	}
	return out
}

const rootNav = `<a href="/">← console</a> · <a href="/map">system map</a> · <a href="https://lan.just3ws.com">LAN Atlas ↗</a> · <a href="/man">man index</a> · <a href="/backlog">backlog</a> · <a href="/theme">theme</a>`

func (e *serverEnv) wrap(title, inner string) string {
	return fmt.Sprintf(`<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>%s — zdots.localhost</title><style>%s</style></head><body><header><h1><span class="mark">zdots</span>.localhost</h1><p class="sub">%s</p></header><main>%s</main></body></html>`,
		h(title), e.css, rootNav, inner)
}

func (e *serverEnv) manIndex() string {
	paths, _ := filepath.Glob(filepath.Join(e.zdotdir, "man", "man*", "*"))
	sort.Strings(paths)
	numSuffix := regexp.MustCompile(`\.\d+$`)
	var items strings.Builder
	for _, p := range paths {
		sect := strings.TrimPrefix(filepath.Base(filepath.Dir(p)), "man")
		name := numSuffix.ReplaceAllString(filepath.Base(p), "")
		items.WriteString(fmt.Sprintf(`<li><a href="/man/%s">%s</a> <span class="mono">(%s)</span></li>`, h(name), h(name), h(sect)))
	}
	return e.wrap("man pages", fmt.Sprintf(`<section aria-labelledby="m-h"><h2 id="m-h">Manual pages</h2><ul class="eps cols">%s</ul></section>`, items.String()))
}

func (e *serverEnv) renderMan(cmd string) (string, bool) {
	if !regexp.MustCompile(`^[a-z0-9][a-z0-9-]*$`).MatchString(cmd) {
		return "", false
	}
	matches, _ := filepath.Glob(filepath.Join(e.zdotdir, "man", "man*", cmd+".*"))
	if len(matches) == 0 {
		return "", false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "mandoc", "-Thtml", "-O", "fragment", matches[0]).Output()
	if err != nil || len(bytes.TrimSpace(out)) == 0 {
		return "", false
	}
	xrRe := regexp.MustCompile(`<a class="Xr">([a-z0-9][a-z0-9._-]*)\((\d+)\)</a>`)
	rendered := xrRe.ReplaceAllStringFunc(string(out), func(m string) string {
		sub := xrRe.FindStringSubmatch(m)
		if len(sub) < 3 {
			return m
		}
		name, sect := sub[1], sub[2]
		if mm, _ := filepath.Glob(filepath.Join(e.zdotdir, "man", "man*", name+".*")); len(mm) > 0 {
			return fmt.Sprintf(`<a class="Xr" href="/man/%s">%s(%s)</a>`, h(name), h(name), h(sect))
		}
		return fmt.Sprintf("%s(%s)", name, sect)
	})
	return e.wrap(cmd+" (man)", fmt.Sprintf(`<section class="man"><p class="dim"><a href="/man">↩ all man pages</a></p>%s</section>`, rendered)), true
}

func (e *serverEnv) docFiles() []string {
	seen := make(map[string]bool)
	var files []string
	top, _ := filepath.Glob(filepath.Join(e.zdotdir, "*.md"))
	for _, p := range top {
		if !seen[p] {
			seen[p] = true
			files = append(files, p)
		}
	}
	_ = filepath.WalkDir(filepath.Join(e.zdotdir, "docs"), func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() && strings.HasSuffix(d.Name(), ".md") && !seen[p] {
			seen[p] = true
			files = append(files, p)
		}
		return nil
	})
	return files
}

func (e *serverEnv) docKey(p string) string {
	rel := strings.TrimPrefix(p, e.zdotdir+"/")
	rel = strings.TrimSuffix(rel, ".md")
	return strings.ReplaceAll(rel, "/", ":")
}

func (e *serverEnv) docsIndex() string {
	files := e.docFiles()
	sort.Slice(files, func(i, j int) bool { return e.docKey(files[i]) < e.docKey(files[j]) })
	var items strings.Builder
	for _, p := range files {
		k := e.docKey(p)
		items.WriteString(fmt.Sprintf(`<li><a href="/docs/%s">%s</a></li>`, h(k), h(k)))
	}
	return e.wrap("docs", fmt.Sprintf(`<section aria-labelledby="d-h"><h2 id="d-h">Documentation</h2><ul class="eps cols">%s</ul></section>`, items.String()))
}

func (e *serverEnv) renderDoc(key string) (string, bool) {
	if !regexp.MustCompile(`^[A-Za-z0-9:._-]+$`).MatchString(key) {
		return "", false
	}
	var target string
	files := e.docFiles()
	for _, p := range files {
		if e.docKey(p) == key {
			target = p
			break
		}
	}
	if target == "" {
		return "", false
	}
	md, err := os.ReadFile(target)
	if err != nil {
		return "", false
	}
	body := renderMarkdownHTML(md)
	return e.wrap(key+" (doc)", fmt.Sprintf(`<section class="doc"><p class="dim"><a href="/docs">↩ all docs</a></p>%s</section>`, body)), true
}

func (e *serverEnv) helpIndex() string {
	entries, _ := os.ReadDir(e.binDir)
	var names []string
	for _, ent := range entries {
		if ent.IsDir() {
			continue
		}
		if info, err := os.Stat(filepath.Join(e.binDir, ent.Name())); err == nil && (info.Mode()&0o111) != 0 {
			names = append(names, ent.Name())
		}
	}
	sort.Strings(names)
	var items strings.Builder
	for _, c := range names {
		items.WriteString(fmt.Sprintf(`<li><a href="/help/%s">%s</a></li>`, h(c), h(c)))
	}
	return e.wrap("help", fmt.Sprintf(`<section aria-labelledby="hp-h"><h2 id="hp-h">Command <code>--help</code></h2><ul class="eps cols">%s</ul></section>`, items.String()))
}

func (e *serverEnv) renderHelp(cmd string) (string, bool) {
	if !regexp.MustCompile(`^[a-z0-9][a-z0-9._-]*$`).MatchString(cmd) {
		return "", false
	}
	bin := filepath.Join(e.binDir, cmd)
	info, err := os.Stat(bin)
	if err != nil || info.IsDir() || (info.Mode()&0o111) == 0 {
		return "", false
	}
	man := ""
	if mm, _ := filepath.Glob(filepath.Join(e.zdotdir, "man", "man*", cmd+".*")); len(mm) > 0 {
		man = fmt.Sprintf(` · <a href="/man/%s">man page</a>`, h(cmd))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	outBytes, _ := exec.CommandContext(ctx, bin, "--help").CombinedOutput()
	out := string(outBytes)
	if strings.TrimSpace(out) == "" {
		outBytes, _ = exec.CommandContext(ctx, bin, "-h").CombinedOutput()
		out = string(outBytes)
	}
	return e.wrap(cmd+" --help", fmt.Sprintf(`<section><h2>%s <span class="dim">--help%s</span></h2><pre class="man">%s</pre></section>`, h(cmd), man, h(out))), true
}

func renderMarkdownHTML(md []byte) string {
	if _, err := exec.LookPath("pandoc"); err == nil {
		ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, "pandoc", "-f", "gfm", "-t", "html")
		cmd.Stdin = bytes.NewReader(md)
		if out, err := cmd.Output(); err == nil {
			return string(out)
		}
	}
	return "<pre>" + h(string(md)) + "</pre>"
}

const defaultTokensCSS = `:root { --bg:#FAF8F5; --surface:#FFFFFF; --border:#E3DFD7; --text:#1E232A; --text-dim:#525866; --accent:#0F766E; --accent-dim:#B9D6D1; --green:#059669; --yellow:#B45309; --red:#DC2626; --red-text:#991B1B; --craft-paper-subtle:#F4F0E8; --craft-blue:#1D4ED8; --craft-serif:Georgia,serif; --font-sans:system-ui,sans-serif; --craft-shadow:0 2px 8px rgba(30,35,42,.04); --craft-shadow-raised:0 8px 24px rgba(30,35,42,.08); --mono:'FiraCode Nerd Font Mono','Fira Code',monospace; }`

func buildCSS(tokens string) string {
	return tokens + `
* { box-sizing:border-box; } body { margin:0; background:var(--bg); color:var(--text); font:15px/1.5 var(--font-sans); }
header { padding:1.5rem 2rem; border-bottom:1px solid var(--border); }
h1 { margin:0; color:var(--heading); font-family:var(--craft-serif); font-size:1.35rem; }
h1 .mark { color:var(--accent); }
.sub { margin:.35rem 0 0; color:var(--text-dim); font-size:.85rem; }
.live a { color:var(--accent); }
main { width:100%; max-width:none; margin:0 auto; padding:clamp(1rem,2vw,2rem); }
section { margin-bottom:2rem; }
h2 { font-size:.75rem; text-transform:uppercase; letter-spacing:.07em; color:var(--text-dim); border-bottom:1px solid var(--border); padding-bottom:.4rem; }
h2 .dim { text-transform:none; letter-spacing:0; font-weight:400; }
.grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(13rem,1fr)); gap:.6rem; }
.card { background:var(--surface); border:1px solid var(--border); border-radius:8px; padding:.75rem .9rem; display:flex; justify-content:space-between; align-items:center; }
.card .lbl { font-size:.85rem; }
.pill { font-size:.72rem; font-weight:700; padding:.12rem .5rem; border-radius:99px; }
.pill.ok { background:rgba(152,187,108,.15); color:var(--green); }
.pill.down { background:rgba(195,64,67,.15); color:var(--red-text); }
.pill.warn { background:rgba(230,195,132,.15); color:var(--yellow); }
table { width:100%; border-collapse:collapse; font-size:.85rem; }
th { text-align:left; padding:.45rem .6rem; font-size:.7rem; text-transform:uppercase; letter-spacing:.06em; color:var(--text-dim); border-bottom:1px solid var(--border); }
td { padding:.45rem .6rem; border-bottom:1px solid var(--border); }
.mono { font-family:var(--mono); color:var(--text-dim); }
.eps { list-style:none; padding:0; margin:0; } .eps li { padding:.25rem 0; font-size:.82rem; }
.eps.cols { columns:3; } @media (max-width:48rem){ .eps.cols { columns:2; } }
a { color:var(--accent); }
.doc pre, .man pre { background:var(--surface); border:1px solid var(--border); border-radius:6px; padding:.75rem; overflow-x:auto; }
.kpis { display:flex; gap:.6rem; flex-wrap:wrap; margin-bottom:1.2rem; }
.kpi { border:1px solid var(--border); border-radius:8px; padding:.4rem .8rem; background:var(--surface); font-size:.85rem; }
.kpi b { font-size:1.15rem; color:var(--accent); margin-right:.3rem; }
.pr { display:inline-block; border-radius:6px; padding:0 .4rem; font-size:.72rem; font-weight:700; }
.pr.high { background:rgba(195,64,67,.15); color:var(--red-text); }
.pr.medium { background:rgba(230,195,132,.15); color:var(--yellow); }
.pr.low { background:var(--surface); color:var(--text-dim); }
.lb { display:inline-block; background:var(--surface); border:1px solid var(--border); border-radius:6px; padding:0 .35rem; font-size:.7rem; margin-right:.2rem; }
.swatches { display:grid; grid-template-columns:repeat(auto-fill,minmax(9rem,1fr)); gap:.6rem; }
figure.sw { margin:0; border:1px solid var(--border); border-radius:8px; overflow:hidden; background:var(--surface); }
figure.sw .chip { height:52px; }
figure.sw figcaption { padding:.4rem .55rem; display:flex; flex-direction:column; gap:.1rem; font-size:.75rem; }
`
}

func envOr(k, fallback string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fallback
}
