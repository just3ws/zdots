package storage

import (
	"context"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/just3ws/zdots/cmd/zdots-core/internal/otel"
)

const (
	fiveGiB = int64(5 * 1024 * 1024 * 1024)
	tenGiB  = int64(10 * 1024 * 1024 * 1024)
	oneGiB  = int64(1024 * 1024 * 1024)
)

// Report is the JSON schema emitted by zdots-storage --json and embedded in capabilities --json.
type Report struct {
	DiskAvailableGB int64   `json:"disk_available_gb"`
	DiskReserveGB   int64   `json:"disk_reserve_gb"`
	RootStatus      string  `json:"root_status"`
	Buckets         Buckets `json:"buckets"`
}

type Buckets struct {
	Models  ModelsBucket  `json:"models"`
	Docker  DockerBucket  `json:"docker"`
	Ingest  IngestBucket  `json:"ingest"`
	Caches  CachesBucket  `json:"caches"`
	Logs    LogsBucket    `json:"logs"`
	Backups BackupsBucket `json:"backups"`
}

type ModelsBucket struct {
	TotalBytes    int64  `json:"total_bytes"`
	InactiveBytes int64  `json:"inactive_bytes"`
	InactiveCount int    `json:"inactive_count"`
	Status        string `json:"status"`
}

type DockerBucket struct {
	ColimaBytes int64  `json:"colima_bytes"`
	Status      string `json:"status"`
}

type IngestBucket struct {
	TotalBytes       int64  `json:"total_bytes"`
	OlderThan7dBytes int64  `json:"older_than_7d_bytes"`
	OlderThan7dCount int    `json:"older_than_7d_count"`
	Status           string `json:"status"`
}

type CachesBucket struct {
	TotalBytes         int64  `json:"total_bytes"`
	UVBytes            int64  `json:"uv_bytes"`
	CodexRuntimesBytes int64  `json:"codex_runtimes_bytes"`
	PNPMBytes          int64  `json:"pnpm_bytes"`
	NPXBytes           int64  `json:"npx_bytes"`
	BrewCacheBytes     int64  `json:"brew_cache_bytes"`
	Status             string `json:"status"`
}

type LogsBucket struct {
	StaleDiagsBytes  int64  `json:"stale_diags_bytes"`
	StaleDiagsCount  int    `json:"stale_diags_count"`
	OpenObserveBytes int64  `json:"openobserve_bytes"`
	Status           string `json:"status"`
}

type BackupsBucket struct {
	TotalBytes int64  `json:"total_bytes"`
	VaultBytes int64  `json:"vault_bytes"`
	Status     string `json:"status"`
}

func usage() string {
	return `zdots-storage — Multi-bucket system storage monitoring & budget attestation

Usage:
  zdots-storage [options]

Options:
  --json      Output machine-readable JSON format
  -h, --help  Show this help message

Context Buckets Monitored:
  root          Main macOS filesystem capacity and available space
  models        Local LLM/audio weights (~/.local/share/llama-cpp, whisper-cpp)
  docker        Docker containers/images/volumes & Colima VM footprint
  ingest        Staged media & document ingestion sources (~/.local/state/zdots/ingest-sources)
  caches        Tool & package manager caches (uv, codex-runtimes, pnpm, npx, brew)
  logs          Diagnostic trace dumps & archived service logs (~/.local/state/zsh)
  backups       Migration, dotfile, and database backups (colima-xdg-backup, adots-backups, my/backups)
`
}

// Run executes the zdots-storage CLI and returns the exit code.
func Run(args []string) int {
	jsonMode := false
	for _, arg := range args {
		switch arg {
		case "--json":
			jsonMode = true
		case "-h", "--help":
			fmt.Print(usage())
			return 0
		default:
			fmt.Fprintf(os.Stderr, "zdots-storage: unknown option: %s\n", arg)
			return 1
		}
	}

	reserveStr := os.Getenv("ZDOTS_STORAGE_RESERVE_GB")
	if reserveStr == "" {
		reserveStr = "45"
	}
	reserveGB, err := parseNonNegInt(reserveStr)
	if err != nil {
		fmt.Fprintln(os.Stderr, "zdots-storage: ZDOTS_STORAGE_RESERVE_GB must be a non-negative integer")
		return 2
	}

	home, _ := os.UserHomeDir()
	zdotdir := os.Getenv("ZDOTDIR")
	if zdotdir == "" && home != "" {
		zdotdir = filepath.Join(home, ".config", "zsh")
	}
	vaultRoot := os.Getenv("ZDOTS_VAULT_ROOT")
	if vaultRoot == "" {
		vaultRoot = os.Getenv("ZDOTS_MY_ROOT")
	}

	tr := otel.New("zdots-storage")
	rootSpan := tr.Start("storage.collect", nil)
	rootSpan.SetAttr("json_mode", jsonMode)
	rootSpan.SetAttr("reserve_gb", reserveGB)

	rep := Collect(home, zdotdir, vaultRoot, reserveGB)
	rootSpan.SetAttr("disk_available_gb", rep.DiskAvailableGB)
	rootSpan.SetAttr("root_status", rep.RootStatus)
	rootSpan.End(true, "")
	tr.Flush(250 * time.Millisecond)

	if jsonMode {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(rep)
		return 0
	}

	b := rep.Buckets
	fmt.Println("━━━ System Storage Buckets ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Printf("  Root Avail:     %-8s  [%s; reserve %dGB]\n", fmt.Sprintf("%dGB", rep.DiskAvailableGB), rep.RootStatus, rep.DiskReserveGB)
	fmt.Printf("  Models:         %-8s  (inactive GGUFs: %s in %d files) [%s]\n",
		fmtBytes(b.Models.TotalBytes), fmtBytes(b.Models.InactiveBytes), b.Models.InactiveCount, b.Models.Status)
	fmt.Printf("  Docker/Colima:  %-8s  [%s]\n", fmtBytes(b.Docker.ColimaBytes), b.Docker.Status)
	fmt.Printf("  Durable Ingest: %-8s  (older than 7d: %d files; retained) [%s]\n",
		fmtBytes(b.Ingest.TotalBytes), b.Ingest.OlderThan7dCount, b.Ingest.Status)
	fmt.Printf("  Tool Caches:    %-8s  (uv: %s, codex: %s, npx: %s, brew: %s) [%s]\n",
		fmtBytes(b.Caches.TotalBytes), fmtBytes(b.Caches.UVBytes), fmtBytes(b.Caches.CodexRuntimesBytes), fmtBytes(b.Caches.NPXBytes), fmtBytes(b.Caches.BrewCacheBytes), b.Caches.Status)
	fmt.Printf("  Logs/Diags:     %-8s  (stale diags >14d: %s) [%s]\n",
		fmtBytes(b.Logs.StaleDiagsBytes+b.Logs.OpenObserveBytes), fmtBytes(b.Logs.StaleDiagsBytes), b.Logs.Status)
	fmt.Printf("  Backups:        %-8s  [%s]\n", fmtBytes(b.Backups.TotalBytes), b.Backups.Status)
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("Run 'zdots-hygiene' to preview or execute safe cleanup actions.")
	return 0
}

// Collect gathers all storage bucket measurements concurrently.
func Collect(home, zdotdir, myRoot string, reserveGB int64) Report {
	var (
		availGB        int64
		llamaBytes     int64
		whisperBytes   int64
		inactiveBytes  int64
		inactiveCount  int
		colimaBytes    int64
		ingestBytes    int64
		older7dBytes   int64
		older7dCount   int
		uvBytes        int64
		codexBytes     int64
		pnpmBytes      int64
		npxBytes       int64
		brewCacheBytes int64
		diagBytes      int64
		diagCount      int
		o2Bytes        int64
		colimaBakBytes int64
		adotsBakBytes  int64
		myBakBytes     int64
	)

	var wg sync.WaitGroup

	// 1. Root volume
	wg.Add(1)
	go func() {
		defer wg.Done()
		availGB = rootAvailGB()
	}()

	// 2. Models
	llamaDir := filepath.Join(home, ".local", "share", "llama-cpp", "models")
	whisperDir := filepath.Join(home, ".local", "share", "whisper-cpp")
	wg.Add(1)
	go func() {
		defer wg.Done()
		llamaBytes = dirDiskBytes(llamaDir)
		activeModel := activeModelFile(filepath.Join(zdotdir, "etc", "ai-models.yaml"))
		entries, err := os.ReadDir(llamaDir)
		if err != nil {
			return
		}
		for _, e := range entries {
			if e.IsDir() || !strings.HasSuffix(e.Name(), ".gguf") {
				continue
			}
			name := e.Name()
			if name != activeModel && name != "nomic-embed-text-v2-moe.Q8_0.gguf" && name != "embed.gguf" {
				if info, err := e.Info(); err == nil {
					inactiveBytes += info.Size()
					inactiveCount++
				}
			}
		}
	}()
	wg.Add(1)
	go func() { defer wg.Done(); whisperBytes = dirDiskBytes(whisperDir) }()

	// 3. Docker/Colima
	wg.Add(1)
	go func() { defer wg.Done(); colimaBytes = dirDiskBytes(filepath.Join(home, ".colima")) }()

	// 4. Ingest (single WalkDir computes both total and >7d)
	ingestDir := filepath.Join(home, ".local", "state", "zdots", "ingest-sources")
	wg.Add(1)
	go func() {
		defer wg.Done()
		cutoff := time.Now().Add(-7 * 24 * time.Hour)
		ingestBytes, older7dBytes, older7dCount = walkSizeAndOlder(ingestDir, cutoff)
	}()

	// 5. Caches
	wg.Add(1)
	go func() { defer wg.Done(); uvBytes = dirDiskBytes(filepath.Join(home, ".cache", "uv")) }()
	wg.Add(1)
	go func() { defer wg.Done(); codexBytes = dirDiskBytes(filepath.Join(home, ".cache", "codex-runtimes")) }()
	wg.Add(1)
	go func() { defer wg.Done(); pnpmBytes = dirDiskBytes(filepath.Join(home, ".local", "share", "pnpm")) }()
	wg.Add(1)
	go func() { defer wg.Done(); npxBytes = dirDiskBytes(filepath.Join(home, ".npm", "_npx")) }()
	wg.Add(1)
	go func() {
		defer wg.Done()
		if _, err := exec.LookPath("brew"); err != nil {
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		out, err := exec.CommandContext(ctx, "brew", "--cache").Output()
		if err == nil {
			bcache := strings.TrimSpace(string(out))
			if bcache != "" {
				brewCacheBytes = dirDiskBytes(bcache)
			}
		}
	}()

	// 6. Logs & Diags
	logStateDir := filepath.Join(home, ".local", "state", "zsh")
	wg.Add(1)
	go func() {
		defer wg.Done()
		cutoff := time.Now().Add(-14 * 24 * time.Hour)
		entries, err := os.ReadDir(logStateDir)
		if err != nil {
			return
		}
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			n := e.Name()
			if strings.HasPrefix(n, "collector-diag-") && strings.HasSuffix(n, ".jsonl") {
				if info, err := e.Info(); err == nil && info.ModTime().Before(cutoff) {
					diagBytes += info.Size()
					diagCount++
				}
			}
		}
	}()
	wg.Add(1)
	go func() { defer wg.Done(); o2Bytes = dirDiskBytes(filepath.Join(home, ".local", "share", "openobserve")) }()

	// 7. Backups
	wg.Add(1)
	go func() {
		defer wg.Done()
		colimaBakBytes = dirDiskBytes(filepath.Join(home, ".local", "state", "zsh", "colima-xdg-backup"))
	}()
	wg.Add(1)
	go func() { defer wg.Done(); adotsBakBytes = dirDiskBytes(filepath.Join(home, ".adots-backups")) }()
	wg.Add(1)
	go func() {
		defer wg.Done()
		var n int64
		n += dirDiskBytes(filepath.Join(home, ".local", "state", "zdots", "backups"))
		if myRoot != "" {
			n += dirDiskBytes(filepath.Join(myRoot, "backups"))
		}
		myBakBytes = n
	}()

	wg.Wait()

	rootStatus := "ok"
	if availGB < reserveGB {
		rootStatus = "warn"
	}
	if availGB < 5 {
		rootStatus = "crit"
	}

	modelsBytes := llamaBytes + whisperBytes
	modelsStatus := "ok"
	if inactiveBytes > fiveGiB {
		modelsStatus = "warn"
	}

	ingestStatus := "ok"
	if ingestBytes > fiveGiB {
		ingestStatus = "warn"
	}

	cachesBytes := uvBytes + codexBytes + pnpmBytes + npxBytes + brewCacheBytes
	cachesStatus := "ok"
	if cachesBytes > tenGiB {
		cachesStatus = "warn"
	}

	backupsBytes := colimaBakBytes + adotsBakBytes + myBakBytes
	backupsStatus := "ok"
	if backupsBytes > oneGiB {
		backupsStatus = "warn"
	}

	return Report{
		DiskAvailableGB: availGB,
		DiskReserveGB:   reserveGB,
		RootStatus:      rootStatus,
		Buckets: Buckets{
			Models: ModelsBucket{
				TotalBytes:    modelsBytes,
				InactiveBytes: inactiveBytes,
				InactiveCount: inactiveCount,
				Status:        modelsStatus,
			},
			Docker: DockerBucket{
				ColimaBytes: colimaBytes,
				Status:      "ok",
			},
			Ingest: IngestBucket{
				TotalBytes:       ingestBytes,
				OlderThan7dBytes: older7dBytes,
				OlderThan7dCount: older7dCount,
				Status:           ingestStatus,
			},
			Caches: CachesBucket{
				TotalBytes:         cachesBytes,
				UVBytes:            uvBytes,
				CodexRuntimesBytes: codexBytes,
				PNPMBytes:          pnpmBytes,
				NPXBytes:           npxBytes,
				BrewCacheBytes:     brewCacheBytes,
				Status:             cachesStatus,
			},
			Logs: LogsBucket{
				StaleDiagsBytes:  diagBytes,
				StaleDiagsCount:  diagCount,
				OpenObserveBytes: o2Bytes,
				Status:           "ok",
			},
			Backups: BackupsBucket{
				TotalBytes: backupsBytes,
				VaultBytes: myBakBytes,
				Status:     backupsStatus,
			},
		},
	}
}

func parseNonNegInt(s string) (int64, error) {
	if s == "" {
		return 0, fmt.Errorf("empty")
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return 0, fmt.Errorf("not a non-negative integer")
		}
	}
	return strconv.ParseInt(s, 10, 64)
}

func rootAvailGB() int64 {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "df", "-k", "/").Output()
	if err != nil {
		return 0
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) < 2 {
		return 0
	}
	fields := strings.Fields(lines[1])
	if len(fields) < 4 {
		return 0
	}
	kb, err := strconv.ParseInt(fields[3], 10, 64)
	if err != nil {
		return 0
	}
	return kb / 1024 / 1024
}

// dirDiskBytes returns allocated bytes under dir (512B blocks * 512, matching du -sk).
func dirDiskBytes(dir string) int64 {
	info, err := os.Stat(dir)
	if err != nil || !info.IsDir() {
		return 0
	}
	var total int64
	_ = filepath.WalkDir(dir, func(_ string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			return nil
		}
		fi, err := d.Info()
		if err != nil {
			return nil
		}
		total += allocatedBytes(fi)
		return nil
	})
	return total
}

func walkSizeAndOlder(dir string, cutoff time.Time) (total int64, olderBytes int64, olderCount int) {
	info, err := os.Stat(dir)
	if err != nil || !info.IsDir() {
		return 0, 0, 0
	}
	_ = filepath.WalkDir(dir, func(_ string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return nil
		}
		fi, err := d.Info()
		if err != nil {
			return nil
		}
		total += allocatedBytes(fi)
		if d.Type().IsRegular() && fi.ModTime().Before(cutoff) {
			olderBytes += fi.Size()
			olderCount++
		}
		return nil
	})
	return total, olderBytes, olderCount
}

func allocatedBytes(fi fs.FileInfo) int64 {
	if st, ok := fi.Sys().(*syscall.Stat_t); ok {
		return st.Blocks * 512
	}
	return fi.Size()
}

// activeModelFile reads default_profile and profiles.<profile>.model_file from etc/ai-models.yaml.
func activeModelFile(yamlPath string) string {
	b, err := os.ReadFile(yamlPath)
	if err != nil {
		return ""
	}
	lines := strings.Split(string(b), "\n")
	profile := "qwen3-8b"
	for _, raw := range lines {
		t := strings.TrimSpace(raw)
		if strings.HasPrefix(t, "default_profile:") {
			val := strings.TrimSpace(strings.TrimPrefix(t, "default_profile:"))
			val = strings.Trim(val, `"'`)
			if val != "" {
				profile = val
			}
			break
		}
	}
	inProfiles := false
	inTarget := false
	for _, raw := range lines {
		if raw == "" || strings.HasPrefix(strings.TrimSpace(raw), "#") {
			continue
		}
		indent := len(raw) - len(strings.TrimLeft(raw, " "))
		t := strings.TrimSpace(raw)
		if indent == 0 {
			inProfiles = t == "profiles:"
			inTarget = false
			continue
		}
		if inProfiles && indent == 2 {
			inTarget = strings.TrimSuffix(t, ":") == profile
			continue
		}
		if inTarget && strings.HasPrefix(t, "model_file:") {
			val := strings.TrimSpace(strings.TrimPrefix(t, "model_file:"))
			return strings.Trim(val, `"'`)
		}
	}
	return ""
}

func fmtBytes(b int64) string {
	switch {
	case b >= 1073741824:
		return fmt.Sprintf("%.1fGB", float64(b)/1073741824)
	case b >= 1048576:
		return fmt.Sprintf("%.1fMB", float64(b)/1048576)
	case b >= 1024:
		return fmt.Sprintf("%.1fKB", float64(b)/1024)
	default:
		return fmt.Sprintf("%dB", b)
	}
}
