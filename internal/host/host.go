// Package host resolves which host profile applies on the current machine
// and loads the corresponding hosts/<name>.toml file.
package host

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

// Detect returns the current machine's hostname.
func Detect() (string, error) {
	h, err := os.Hostname()
	if err != nil {
		return "", fmt.Errorf("detect hostname: %w", err)
	}
	return h, nil
}

// Load reads hosts/<name>.toml from hostsDir.
func Load(hostsDir, name string) (*manifest.Host, error) {
	path := filepath.Join(hostsDir, name+".toml")
	if _, err := os.Stat(path); err != nil {
		return nil, fmt.Errorf("host profile %q not found at %s", name, path)
	}
	return manifest.ParseHost(path)
}
