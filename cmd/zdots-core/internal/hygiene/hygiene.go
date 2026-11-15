// Package hygiene implements the zdots-hygiene storage hygiene & eviction applet.
package hygiene

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
	"github.com/just3ws/zdots/cmd/zdots-core/internal/storage"
)

var hex16Re = regexp.MustCompile(`^[0-9a-f]{16}$`)

type scanResult struct {
	ingestBytes       int64
	olderIngestBytes  int64
	olderIngestCount  int
	staleDiagFiles    []string
	staleDiagBytes    int64
	uvCacheBytes      int64
	codexCacheBytes   int64
	staleNpxDirs      []string
	staleNpxBytes     int64
	staleScratchFiles []string
	staleScratchBytes int64
	brewCacheDir      string
	brewCacheBytes    int64
	totalReclaimable  int64
}

// Run executes the zdots-hygiene applet and returns an exit code.
func Run(args []string) int {
	return runWithIO(args, os.Stdout, os.Stderr, true)
}

func runWithIO(args []string, stdout, stderr io.Writer, runStorage bool) int {
	apply := false
	for _, arg := range args {
		switch arg {
		case "-f", "--apply":
			apply = true
		case "-h", "--help":
			printUsage(stdout)
			return 0
		default:
			fmt.Fprintf(stderr, "zdots-hygiene: unknown option: %s\n", arg)
			return 1
		}
	}

	tracer := otel.New("zdots-hygiene")
	defer tracer.Flush(250 * time.Millisecond)

	root := tracer.Start("hygiene.run", nil)
	root.SetAttr("apply", apply)

	home, _ := os.UserHomeDir()
	now := time.Now()

	scanSpan := tracer.Start("hygiene.scan", root)
	res := scanHome(home, now, stderr)
	scanSpan.SetAttr("reclaimable_bytes", res.totalReclaimable)
	scanSpan.SetAttr("stale_diag_count", len(res.staleDiagFiles))
	scanSpan.SetAttr("stale_npx_count", len(res.staleNpxDirs))
	scanSpan.SetAttr("stale_scratch_count", len(res.staleScratchFiles))
	scanSpan.End(true, "")

	if !apply {
		npxDir := filepath.Join(home, ".npm", "_npx")
		scratchDir := filepath.Join(home, ".local", "state", "just3ws", "scratch")
		fmt.Fprint(stdout, "zdots-hygiene: dry run -- pass -f or --apply to execute sweeps.\n\n")
		fmt.Fprintln(stdout, "Candidate Evictions:")
		fmt.Fprintf(stdout, "  1. Durable Ingest Sources:         retained; %d files >7d (%s)\n",
			res.olderIngestCount, fmtBytes(res.ingestBytes))
		fmt.Fprintf(stdout, "  2. Old Logs & Rotations:           %-8s  (diagnostics >14d, archives >30d; %d files)\n",
			fmtBytes(res.staleDiagBytes), len(res.staleDiagFiles))
		fmt.Fprintf(stdout, "  3. Python uv Cache:              %-8s  (prune; actual reclaim varies)\n",
			fmtBytes(res.uvCacheBytes))
		fmt.Fprintf(stdout, "  4. Codex Runtimes Cache:          %-8s\n",
			fmtBytes(res.codexCacheBytes))
		fmt.Fprintf(stdout, "  5. Stale npx Runtimes (>30d):     %-8s  (%d dirs in %s)\n",
			fmtBytes(res.staleNpxBytes), len(res.staleNpxDirs), npxDir)
		fmt.Fprintf(stdout, "  6. Stale Audio Scratch (>2d):     %-8s  (%d files in %s)\n",
			fmtBytes(res.staleScratchBytes), len(res.staleScratchFiles), scratchDir)
		fmt.Fprintf(stdout, "  7. Homebrew Download Cache:       %-8s\n",
			fmtBytes(res.brewCacheBytes))
		fmt.Fprintln(stdout, "  ─────────────────────────────────────────────────────────────")
		fmt.Fprintf(stdout, "  Total Estimated Reclaimable:      %-8s  (excludes uv/Docker/pnpm estimates)\n\n",
			fmtBytes(res.totalReclaimable))
		fmt.Fprint(stdout, "To execute, run:\n  zdots-hygiene -f\n")
		root.End(true, "")
		return 0
	}

	applySpan := tracer.Start("hygiene.apply", root)
	executeSweeps(home, res, stdout, stderr)
	applySpan.End(true, "")

	if runStorage {
		fmt.Fprint(stdout, "\nzdots-hygiene: sweep complete. Current status:\n")
		_ = storage.Run(nil)
	}

	root.End(true, "")
	return 0
}

func printUsage(w io.Writer) {
	fmt.Fprint(w, `zdots-hygiene — Unified system storage hygiene & eviction routine

Usage:
  zdots-hygiene [options]

Options:
  (no flag)     Dry run mode — preview reclaimable space and actions
  -f, --apply   Execute non-destructive cleanup sweeps
  -h, --help    Show this help message

Actions Executed on --apply:
  1. Docker/Colima VM: Prune unused images/volumes & run fstrim inside Colima
  2. Python uv Cache: Prune dangling entries (preserves useful cache)
  3. Homebrew: Remove old formula bottles & clear brew download cache
  4. Ingestion Sources: Retained source of truth; never age-pruned
  5. Diagnostic Logs: Remove stale trace dumps (collector-diag-*.jsonl) > 14 days old
  6. Agent Runtimes: Purge obsolete codex-runtimes cache
  7. Package Caches: Prune unreferenced pnpm packages, stale npx (>30d), and unused mise versions
`)
}

func scanHome(home string, now time.Time, stderr io.Writer) scanResult {
	var res scanResult

	ingestDir := filepath.Join(home, ".local", "state", "zdots", "ingest-sources")
	res.ingestBytes = dirBytes(ingestDir)
	_ = filepath.WalkDir(ingestDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		if info, infoErr := d.Info(); infoErr == nil && olderThanDays(now, info.ModTime(), 7) {
			res.olderIngestBytes += info.Size()
			res.olderIngestCount++
		}
		return nil
	})

	logStateDir := filepath.Join(home, ".local", "state", "zsh")
	if entries, err := os.ReadDir(logStateDir); err == nil {
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			name := e.Name()
			info, infoErr := e.Info()
			if infoErr != nil {
				continue
			}
			isDiag := strings.HasPrefix(name, "collector-diag-") && strings.HasSuffix(name, ".jsonl") && olderThanDays(now, info.ModTime(), 14)
			isArchive := strings.Contains(name, ".log.") && strings.HasSuffix(name, ".gz") && olderThanDays(now, info.ModTime(), 30)
			if isDiag || isArchive {
				res.staleDiagFiles = append(res.staleDiagFiles, filepath.Join(logStateDir, name))
				res.staleDiagBytes += info.Size()
			}
		}
	}

	res.uvCacheBytes = dirBytes(filepath.Join(home, ".cache", "uv"))
	res.codexCacheBytes = dirBytes(filepath.Join(home, ".cache", "codex-runtimes"))

	npxDir := filepath.Join(home, ".npm", "_npx")
	if entries, err := os.ReadDir(npxDir); err == nil {
		for _, e := range entries {
			if !e.IsDir() {
				continue
			}
			full := filepath.Join(npxDir, e.Name())
			info, infoErr := e.Info()
			if infoErr != nil || !olderThanDays(now, info.ModTime(), 30) {
				continue
			}
			if isValidNpxSignature(full) {
				res.staleNpxDirs = append(res.staleNpxDirs, full)
				res.staleNpxBytes += dirBytes(full)
			} else {
				fmt.Fprintf(stderr, "zdots-hygiene: [warn] skipping anomalous npx path (signature mismatch): %s\n", full)
			}
		}
	}

	scratchDir := filepath.Join(home, ".local", "state", "just3ws", "scratch")
	_ = filepath.WalkDir(scratchDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(d.Name()))
		if ext != ".wav" && ext != ".mp3" && ext != ".flac" {
			return nil
		}
		if info, infoErr := d.Info(); infoErr == nil && olderThanDays(now, info.ModTime(), 2) {
			res.staleScratchFiles = append(res.staleScratchFiles, path)
			res.staleScratchBytes += info.Size()
		}
		return nil
	})

	if _, err := exec.LookPath("brew"); err == nil {
		if out, err := exec.Command("brew", "--cache").Output(); err == nil {
			bcache := strings.TrimSpace(string(out))
			if bcache != "" {
				res.brewCacheDir = bcache
				res.brewCacheBytes = dirBytes(bcache)
			}
		}
	}

	res.totalReclaimable = res.staleDiagBytes + res.codexCacheBytes + res.staleNpxBytes + res.staleScratchBytes + res.brewCacheBytes
	return res
}

func executeSweeps(home string, res scanResult, stdout, stderr io.Writer) {
	fmt.Fprintln(stdout, "zdots-hygiene: executing storage hygiene sweeps...")

	fmt.Fprintf(stdout, "  [hygiene] preserving durable ingest sources; no age-based deletion (%s)\n",
		fmtBytes(res.ingestBytes))

	if len(res.staleDiagFiles) > 0 {
		fmt.Fprintf(stdout, "  [hygiene] purging %d stale diagnostic dumps and rotated log archives (>30d)...\n", len(res.staleDiagFiles))
		for _, f := range res.staleDiagFiles {
			_ = os.Remove(f)
		}
		fmt.Fprintf(stdout, "  [hygiene] freed %s from stale logs\n", fmtBytes(res.staleDiagBytes))
	} else {
		fmt.Fprintln(stdout, "  [hygiene] diagnostic dumps & log archives clean")
	}

	if _, err := exec.LookPath("docker-reclaim"); err == nil {
		fmt.Fprintln(stdout, "  [hygiene] running docker-reclaim -f...")
		_ = exec.Command("docker-reclaim", "-f").Run()
	}

	if _, err := exec.LookPath("uv"); err == nil {
		fmt.Fprintln(stdout, "  [hygiene] pruning dangling uv cache entries...")
		_ = exec.Command("uv", "cache", "prune").Run()
	}

	codexDir := filepath.Join(home, ".cache", "codex-runtimes")
	if fi, err := os.Stat(codexDir); err == nil && fi.IsDir() {
		fmt.Fprintln(stdout, "  [hygiene] removing codex-runtimes cache...")
		_ = os.RemoveAll(codexDir)
	}

	if _, err := exec.LookPath("brew"); err == nil {
		fmt.Fprintln(stdout, "  [hygiene] running brew cleanup...")
		_ = exec.Command("brew", "cleanup", "--prune=all").Run()
		if res.brewCacheDir != "" {
			_ = os.RemoveAll(res.brewCacheDir)
		}
	}

	if len(res.staleScratchFiles) > 0 {
		fmt.Fprintf(stdout, "  [hygiene] purging %d stale audio scratch files (>2d)...\n", len(res.staleScratchFiles))
		for _, f := range res.staleScratchFiles {
			_ = os.Remove(f)
		}
		fmt.Fprintf(stdout, "  [hygiene] freed %s from audio scratch buffer\n", fmtBytes(res.staleScratchBytes))
	} else {
		fmt.Fprintln(stdout, "  [hygiene] media audio scratch buffer clean (no files >2d)")
	}

	if _, err := exec.LookPath("pnpm"); err == nil {
		out, err := exec.Command("pnpm", "store", "path").Output()
		pstore := strings.TrimSpace(string(out))
		if err == nil && pstore != "" {
			if fi, stErr := os.Stat(pstore); stErr == nil && fi.IsDir() {
				fmt.Fprintf(stdout, "  [hygiene] pruning unreferenced packages from pnpm store (%s)...\n", pstore)
				_ = exec.Command("pnpm", "store", "prune").Run()
			} else {
				fmt.Fprintln(stderr, "  [hygiene:warn] pnpm installed but store path unreachable; skipping store prune")
			}
		} else {
			fmt.Fprintln(stderr, "  [hygiene:warn] pnpm installed but store path unreachable; skipping store prune")
		}
	}

	if len(res.staleNpxDirs) > 0 {
		fmt.Fprintf(stdout, "  [hygiene] purging %d verified stale npx runtimes (>30d)...\n", len(res.staleNpxDirs))
		var freedNpx int64
		for _, d := range res.staleNpxDirs {
			sz := dirBytes(d)
			_ = os.RemoveAll(d)
			freedNpx += sz
		}
		fmt.Fprintf(stdout, "  [hygiene] freed %s from verified npx cache\n", fmtBytes(freedNpx))
	}

	if _, err := exec.LookPath("npm"); err == nil {
		_ = exec.Command("npm", "cache", "verify").Run()
	}

	if _, err := exec.LookPath("mise"); err == nil {
		if exec.Command("mise", "prune", "--help").Run() == nil {
			fmt.Fprintln(stdout, "  [hygiene] pruning unused mise tool versions...")
			_ = exec.Command("mise", "prune", "-y").Run()
		} else {
			fmt.Fprintln(stderr, "  [hygiene:warn] mise installed but prune command unsupported; skipping mise prune")
		}
	}
}

func olderThanDays(now, mod time.Time, days int) bool {
	return now.Sub(mod) > time.Duration(days+1)*24*time.Hour
}

func isValidNpxSignature(dir string) bool {
	base := filepath.Base(dir)
	if !hex16Re.MatchString(base) {
		return false
	}
	if _, err := os.Stat(filepath.Join(dir, "package.json")); err == nil {
		return true
	}
	if fi, err := os.Stat(filepath.Join(dir, "node_modules")); err == nil && fi.IsDir() {
		return true
	}
	return false
}

func dirBytes(root string) int64 {
	var total int64
	_ = filepath.WalkDir(root, func(_ string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		if info, infoErr := d.Info(); infoErr == nil {
			total += info.Size()
		}
		return nil
	})
	return total
}

func fmtBytes(b int64) string {
	switch {
	case b >= 1073741824:
		return fmt.Sprintf("%.1fGB", float64(b)/1073741824.0)
	case b >= 1048576:
		return fmt.Sprintf("%.1fMB", float64(b)/1048576.0)
	case b >= 1024:
		return fmt.Sprintf("%.1fKB", float64(b)/1024.0)
	default:
		return fmt.Sprintf("%dB", b)
	}
}
