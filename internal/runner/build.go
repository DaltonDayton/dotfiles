package runner

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/DaltonDayton/dotfiles/internal/action"
	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
	"github.com/DaltonDayton/dotfiles/internal/template"
)

// BuildActions translates a Module's declarative entries into an ordered
// []action.Action filtered to this host.
// Execution order: directories → packages → symlinks → files → commands → services.
func BuildActions(m *module.Module, host *manifest.Host) ([]action.Action, error) {
	var acts []action.Action

	for _, d := range m.Directories {
		if !hostMatch(d.Hosts, host.Name) {
			continue
		}
		acts = append(acts, &action.Directory{Path: expandHome(d.Path), Mode: d.Mode})
	}
	for _, p := range m.Packages {
		if !hostMatch(p.Hosts, host.Name) {
			continue
		}
		mgr := p.Manager
		if mgr == "aur" {
			// "aur" is a logical manager — it resolves to whichever AUR
			// helper the host selected (paru or yay). Keeps modules portable
			// across hosts that differ only on AUR helper preference.
			if host.AURHelper == "" {
				return nil, fmt.Errorf("module %q uses manager=\"aur\" but host %q has no aur_helper set", m.Name, host.Name)
			}
			mgr = host.AURHelper
		}
		acts = append(acts, &action.Packages{Manager: mgr, Names: p.Names})
	}
	for _, s := range m.Symlinks {
		if !hostMatch(s.Hosts, host.Name) {
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
			rendered, err := template.Render(string(raw), host)
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
		if !hostMatch(f.Hosts, host.Name) {
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
		if !hostMatch(c.Hosts, host.Name) {
			continue
		}
		acts = append(acts, &action.Command{Run: c.Run, CheckCmd: c.Check})
	}
	for _, s := range m.Services {
		if !hostMatch(s.Hosts, host.Name) {
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

func expandHome(p string) string {
	if strings.HasPrefix(p, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, p[2:])
	}
	return p
}
