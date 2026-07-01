package runner

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/DaltonDayton/dotfiles/internal/action"
	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
	"github.com/DaltonDayton/dotfiles/internal/template"
)

// BuildActions translates a Module's declarative entries into an ordered
// []action.Action filtered to this host and OS.
// Execution order: directories → packages → symlinks → files → commands → services.
func BuildActions(m *module.Module, profile *manifest.Profile, osName string) ([]action.Action, error) {
	var acts []action.Action

	for _, d := range m.Directories {
		if !hostMatch(d.Hosts, profile.Name) {
			continue
		}
		if !osMatch(d.OS, osName) {
			continue
		}
		acts = append(acts, &action.Directory{Path: expandHome(d.Path), Mode: d.Mode})
	}
	for _, p := range m.Packages {
		if !hostMatch(p.Hosts, profile.Name) {
			continue
		}
		// Gate on p.Manager BEFORE normalizing "" / "aur" → "yay" so the
		// manager value still carries its OS signal at decision time.
		if !osAllowsManager(osName, p.Manager) || !osMatch(p.OS, osName) {
			continue
		}
		mgr := p.Manager
		// Empty manager defaults to yay; "aur" is a logical alias for yay
		// (kept so modules can flag AUR-sourced packages explicitly).
		if mgr == "" || mgr == "aur" {
			mgr = "yay"
		}
		acts = append(acts, &action.Packages{Manager: mgr, Names: p.Names})
	}
	for _, s := range m.Symlinks {
		if !hostMatch(s.Hosts, profile.Name) {
			continue
		}
		if !osMatch(s.OS, osName) {
			continue
		}
		src := filepath.Join(m.Dir, s.Src)
		dst := expandHome(s.Dst)
		if strings.HasSuffix(s.Src, ".tmpl") {
			// Render .tmpl to a sibling file with the .tmpl suffix stripped, then
			// symlink the rendered file. Keeps the symlink target a stable on-disk
			// path instead of a temp file.
			raw, err := os.ReadFile(src)
			if err != nil {
				return nil, err
			}
			rendered, err := template.Render(string(raw), profile)
			if err != nil {
				return nil, err
			}
			renderedPath := strings.TrimSuffix(src, ".tmpl")
			if err := os.WriteFile(renderedPath, []byte(rendered), 0o644); err != nil {
				return nil, err
			}
			src = renderedPath
		}
		acts = append(acts, &action.Symlink{Src: src, Dst: dst, ConflictPolicy: action.ConflictBackup})
	}
	for _, f := range m.Files {
		if !hostMatch(f.Hosts, profile.Name) {
			continue
		}
		if !osMatch(f.OS, osName) {
			continue
		}
		content := f.Content
		if f.ContentFrom != "" {
			data, err := os.ReadFile(filepath.Join(m.Dir, f.ContentFrom))
			if err != nil {
				return nil, err
			}
			content = string(data)
		}
		acts = append(acts, &action.File{Dst: expandHome(f.Dst), Content: content, Mode: f.Mode})
	}
	for _, c := range m.Commands {
		if !hostMatch(c.Hosts, profile.Name) {
			continue
		}
		if !osMatch(c.OS, osName) {
			continue
		}
		acts = append(acts, &action.Command{Run: c.Run, CheckCmd: c.Check})
	}
	for _, s := range m.Services {
		if !hostMatch(s.Hosts, profile.Name) {
			continue
		}
		if !osMatch(s.OS, osName) {
			continue
		}
		acts = append(acts, &action.Service{Name: s.Name, Scope: s.Scope, State: s.State})
	}
	return acts, nil
}

func hostMatch(hosts []string, hostName string) bool {
	if len(hosts) == 0 {
		return true
	}
	for _, h := range hosts {
		if h == hostName {
			return true
		}
	}
	return false
}

// osMatch reports whether an action's optional os filter includes the current
// OS. An empty list means "all OSes" — the regression guard that keeps every
// existing module behaving exactly as before.
func osMatch(osList []string, current string) bool {
	if len(osList) == 0 {
		return true
	}
	for _, o := range osList {
		if o == current {
			return true
		}
	}
	return false
}

// osAllowsManager reports whether a package manager applies to the current OS.
// The manager IS the OS signal: pacman/yay/aur are Arch-only, apt is
// Ubuntu-only, flatpak runs anywhere.
func osAllowsManager(osName, manager string) bool {
	switch manager {
	case "pacman", "yay", "aur":
		return osName == "arch"
	case "apt":
		return osName == "ubuntu"
	case "flatpak", "":
		return true
	}
	return true // unknown managers are not OS-gated here
}

func expandHome(p string) string {
	if strings.HasPrefix(p, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, p[2:])
	}
	return p
}
