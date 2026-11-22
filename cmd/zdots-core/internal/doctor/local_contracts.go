package doctor

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

func lcIsFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func lcRun(timeout time.Duration, name string, args ...string) ([]byte, int) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	out, err := exec.CommandContext(ctx, name, args...).Output()
	if err != nil {
		return out, 1
	}
	return out, 0
}

// checkLocalContracts evaluates expectations, constraints, and conventions on
// untracked machine-local files and macOS app preferences that zdots depends on
// (machine profile pointer, .zdots.local, git identity/signing, iTerm2 prefs
// & DynamicProfiles, rendered LaunchAgents). Never reads .zdots.secrets or .env.
func checkLocalContracts(cfg envConfig) *sectionResult {
	s := &sectionResult{title: "Local & untracked contracts"}
	xdgConfig := envOr("XDG_CONFIG_HOME", filepath.Join(cfg.home, ".config"))

	checkAdotsProfileContract(s, xdgConfig)
	checkZdotsLocalContract(s, cfg.zdotdir)
	checkGitLocalContract(s, xdgConfig)
	if runtime.GOOS == "darwin" {
		checkITermContract(s, cfg.home)
		checkLogRotatePlistContract(s, cfg.home)
	}
	return s
}

func checkAdotsProfileContract(s *sectionResult, xdgConfig string) {
	adotsDir := filepath.Join(xdgConfig, "adots")
	profilePath := filepath.Join(adotsDir, "profile")
	b, err := os.ReadFile(profilePath)
	if err != nil {
		s.warnLine("adots profile  missing (~/.config/adots/profile)")
		s.fix("echo powerstation > ~/.config/adots/profile  # or: work")
		return
	}
	profile := strings.TrimSpace(string(b))
	if profile == "" || strings.ContainsAny(profile, " \t\r\n/") {
		s.failLine(fmt.Sprintf("adots profile  invalid content in %s", profilePath))
		s.fix("write a single profile name (e.g. powerstation or work) to ~/.config/adots/profile")
		return
	}
	confPath := filepath.Join(adotsDir, "profiles", profile+".conf")
	if !lcIsFile(confPath) {
		s.warnLine(fmt.Sprintf("adots profile  %q has no matching %s", profile, confPath))
		s.fix(fmt.Sprintf("create %s or update ~/.config/adots/profile", confPath))
		return
	}
	s.passLine(fmt.Sprintf("adots profile  %s (%s)", profile, filepath.Base(confPath)))
}

func checkZdotsLocalContract(s *sectionResult, zdotdir string) {
	localPath := filepath.Join(zdotdir, ".zdots.local")
	info, err := os.Stat(localPath)
	if err != nil {
		s.passLine(".zdots.local   absent (optional machine-local override)")
		return
	}
	if info.Mode().Perm()&0o077 != 0 {
		s.warnLine(fmt.Sprintf(".zdots.local   permissions %04o (expected 0600)", info.Mode().Perm()))
		s.fix(fmt.Sprintf("chmod 600 %s", localPath))
	}
	if _, rc := lcRun(2*time.Second, "sh", "-n", localPath); rc != 0 {
		s.failLine(".zdots.local   shell syntax error (sh -n failed)")
		s.fix(fmt.Sprintf("sh -n %s", localPath))
		return
	}
	if b, err := os.ReadFile(localPath); err == nil {
		for _, raw := range strings.Split(string(b), "\n") {
			line := strings.TrimSpace(raw)
			if strings.HasPrefix(line, "#") {
				continue
			}
			line = strings.TrimPrefix(line, "export ")
			if strings.HasPrefix(strings.TrimSpace(line), "DATABASE_URL=") {
				s.failLine(".zdots.local   sets forbidden DATABASE_URL (use ZDOTS_DATABASE_URL)")
				s.fix("replace DATABASE_URL with ZDOTS_DATABASE_URL in .zdots.local")
				return
			}
		}
	}
	s.passLine(".zdots.local   valid syntax and conventions")
}

func checkGitLocalContract(s *sectionResult, xdgConfig string) {
	gitDir := filepath.Join(xdgConfig, "git")
	for _, name := range []string{"config.identity", "config.signing"} {
		p := filepath.Join(gitDir, name)
		if !lcIsFile(p) {
			s.warnLine(fmt.Sprintf("git/%s  missing", name))
			continue
		}
		if _, rc := lcRun(2*time.Second, "git", "config", "--file", p, "--list"); rc != 0 {
			s.failLine(fmt.Sprintf("git/%s  invalid gitconfig syntax", name))
			s.fix(fmt.Sprintf("git config --file %s --list", p))
		} else {
			s.passLine(fmt.Sprintf("git/%s  valid", name))
		}
	}
}

func checkITermContract(s *sectionResult, home string) {
	dpDir := filepath.Join(home, "Library", "Application Support", "iTerm2", "DynamicProfiles")
	zdotsDP := filepath.Join(dpDir, "zdots-kanagawa.json")
	if !lcIsFile(zdotsDP) {
		return // iTerm2 zdots profile not deployed on this host
	}

	// Validate Dynamic Profile JSON contract (Wave/Lotus light+dark, Esc+, Recycle CWD, Shell Integration)
	b, err := os.ReadFile(zdotsDP)
	if err != nil {
		s.failLine("iterm2 profile unreadable: " + zdotsDP)
		return
	}
	var doc struct {
		Profiles []map[string]any `json:"Profiles"`
	}
	if err := json.Unmarshal(b, &doc); err != nil || len(doc.Profiles) == 0 {
		s.failLine("iterm2 profile invalid JSON: " + zdotsDP)
		return
	}
	guids := make(map[string]bool)
	var drifted []string
	for _, prof := range doc.Profiles {
		if g, ok := prof["Guid"].(string); ok && g != "" {
			guids[g] = true
		}
		if prof["Name"] == "zdots (Kanagawa)" {
			if prof["Use Separate Colors for Light and Dark Mode"] != true {
				drifted = append(drifted, "Light/Dark colors off")
			}
			if v, ok := prof["Option Key Sends"].(float64); !ok || int(v) != 2 {
				drifted = append(drifted, "Option!=Esc+")
			}
			if v, ok := prof["Right Option Key Sends"].(float64); !ok || int(v) != 2 {
				drifted = append(drifted, "RightOption!=Esc+")
			}
			if prof["Custom Directory"] != "Recycle" {
				drifted = append(drifted, "CustomDirectory!=Recycle")
			}
			if prof["Load Shell Integration Automatically"] != true {
				drifted = append(drifted, "ShellIntegration!=true")
			}
		}
	}
	if len(drifted) > 0 {
		s.warnLine("iterm2 profile drift: " + strings.Join(drifted, ", "))
	} else {
		s.passLine("iterm2 profile zdots-kanagawa.json meets contract (Wave/Lotus, Esc+, Recycle, ShellIntegration)")
	}

	// Check stale duplicate kanagawa-wave.json
	if lcIsFile(filepath.Join(dpDir, "kanagawa-wave.json")) {
		s.warnLine("iterm2 profile stale duplicate kanagawa-wave.json in DynamicProfiles/")
		s.fix("rm -f ~/Library/Application\\ Support/iTerm2/DynamicProfiles/kanagawa-wave.json")
	}

	// Check global macOS defaults for iTerm2
	if out, rc := lcRun(2*time.Second, "defaults", "read", "com.googlecode.iterm2", "Default Bookmark Guid"); rc == 0 {
		active := strings.TrimSpace(string(out))
		if guids[active] {
			s.passLine("iterm2 default Default Bookmark Guid points to zdots profile")
		} else {
			s.warnLine(fmt.Sprintf("iterm2 default Default Bookmark Guid (%s) is not a zdots profile", active))
			s.fix("defaults write com.googlecode.iterm2 'Default Bookmark Guid' -string '8303DA53-8C0D-446A-B08C-79C326B7FAAB'")
		}
	}
	if out, rc := lcRun(2*time.Second, "defaults", "read", "com.googlecode.iterm2", "AllowClipboardAccess"); rc == 0 {
		if strings.TrimSpace(string(out)) == "1" {
			s.passLine("iterm2 default AllowClipboardAccess=1 (OSC 52 ready)")
		} else {
			s.warnLine("iterm2 default AllowClipboardAccess is off (OSC 52 clipboard disabled)")
			s.fix("defaults write com.googlecode.iterm2 AllowClipboardAccess -bool true")
		}
	}
}

func checkLogRotatePlistContract(s *sectionResult, home string) {
	plist := filepath.Join(home, "Library", "LaunchAgents", "com.zdots.log-rotate.plist")
	if !lcIsFile(plist) {
		s.warnLine("log-rotate     LaunchAgent not installed")
		s.fix("log-rotate --install-agent")
		return
	}
	if b, err := os.ReadFile(plist); err == nil {
		txt := string(b)
		if strings.Contains(txt, "__HOME__") || strings.Contains(txt, "__ZDOTDIR__") || strings.Contains(txt, "__XDG_STATE_HOME__") {
			s.failLine("log-rotate     installed plist contains unrendered template placeholders")
			s.fix("log-rotate --install-agent")
			return
		}
	}
	if _, rc := lcRun(2*time.Second, "plutil", "-lint", plist); rc != 0 {
		s.failLine("log-rotate     installed plist failed plutil -lint")
		s.fix("log-rotate --install-agent")
		return
	}
	s.passLine("log-rotate     installed LaunchAgent valid")
}
