package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/host"
	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
	"github.com/DaltonDayton/dotfiles/internal/profile"
	"github.com/DaltonDayton/dotfiles/internal/state"
)

type appCtx struct {
	RepoRoot string
	Modules  []*module.Module
	OS       string
}

func loadCtx() (*appCtx, error) {
	root, err := resolveRepoRoot()
	if err != nil {
		return nil, err
	}
	mods, err := module.LoadAll(filepath.Join(root, "modules"))
	if err != nil {
		return nil, fmt.Errorf("load modules: %w", err)
	}
	osName := host.DetectOS()
	if osName == "unknown" {
		fmt.Fprintln(os.Stderr, "warning: could not determine OS from /etc/os-release; OS-specific actions will be skipped")
	}
	return &appCtx{RepoRoot: root, Modules: mods, OS: osName}, nil
}

// resolveProfileNonInteractive picks the profile without prompting: saved state
// if present, else the detected OS with a default machine (arch → desktop).
// Used by status (always) and by apply when it has saved state.
func resolveProfileNonInteractive(root string, saved *state.Selection) (*manifest.Profile, string, string, error) {
	osName, machine := host.DetectOS(), ""
	if saved != nil && saved.OS != "" {
		osName, machine = saved.OS, saved.Machine
	}
	if osName == "arch" && machine == "" {
		machine = "desktop"
	}
	p, err := profile.Load(filepath.Join(root, "profiles"), osName, machine)
	return p, osName, machine, err
}

// resolveRepoRoot prefers --repo, then the directory that contains the running
// binary's parent (so `<repo>/bin/quill` finds `<repo>`), then `~/.dotfiles`.
func resolveRepoRoot() (string, error) {
	if flagRepoRoot != "" {
		return flagRepoRoot, nil
	}
	exe, err := os.Executable()
	if err == nil {
		candidate := filepath.Dir(filepath.Dir(exe))
		if _, err := os.Stat(filepath.Join(candidate, "modules")); err == nil {
			return candidate, nil
		}
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".dotfiles"), nil
}
