package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/host"
	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

type appCtx struct {
	RepoRoot string
	Modules  []*module.Module
	Host     *manifest.Host
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
	hostname, err := host.Detect()
	if err != nil {
		return nil, err
	}
	h, err := host.Load(filepath.Join(root, "hosts"), hostname)
	if err != nil {
		return nil, err
	}
	osName := host.DetectOS()
	if osName == "unknown" {
		fmt.Fprintln(os.Stderr, "warning: could not determine OS from /etc/os-release; OS-specific actions will be skipped")
	}
	return &appCtx{RepoRoot: root, Modules: mods, Host: h, OS: osName}, nil
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
