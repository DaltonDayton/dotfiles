// Package profile resolves the (os, machine) pick to a profiles/<name>.toml.
package profile

import (
	"fmt"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

// NormalizeOS maps the user-facing "wsl" label to the internal "ubuntu" id.
func NormalizeOS(s string) string {
	if s == "wsl" {
		return "ubuntu"
	}
	return s
}

// FileName resolves an (os, machine) pick to a profile file base name.
// Arch requires a machine; Ubuntu ignores it (WSL has no machine split).
func FileName(osName, machine string) (string, error) {
	switch osName {
	case "arch":
		switch machine {
		case "desktop":
			return "arch-desktop", nil
		case "laptop":
			return "arch-laptop", nil
		default:
			return "", fmt.Errorf("arch profile requires machine \"desktop\" or \"laptop\", got %q", machine)
		}
	case "ubuntu":
		return "wsl", nil
	default:
		return "", fmt.Errorf("unknown os %q (want \"arch\" or \"ubuntu\")", osName)
	}
}

func Load(profilesDir, osName, machine string) (*manifest.Profile, error) {
	base, err := FileName(osName, machine)
	if err != nil {
		return nil, err
	}
	p, err := manifest.ParseProfile(filepath.Join(profilesDir, base+".toml"))
	if err != nil {
		return nil, fmt.Errorf("load profile %q: %w", base, err)
	}
	return p, nil
}
