// Package module walks the modules/ directory and loads each module.toml
// into a Module value that pairs the parsed manifest with its on-disk path.
package module

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

// Module wraps a parsed manifest with its on-disk directory path so callers
// can resolve relative symlink sources and install.sh paths.
type Module struct {
	*manifest.Module
	Dir string
}

// LoadAll walks root looking for <name>/module.toml files. Directories
// without a module.toml are silently skipped (useful during scaffolding).
func LoadAll(root string) ([]*Module, error) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", root, err)
	}
	var mods []*Module
	seen := map[string]string{}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		manifestPath := filepath.Join(root, e.Name(), "module.toml")
		if _, err := os.Stat(manifestPath); err != nil {
			continue
		}
		m, err := manifest.ParseModule(manifestPath)
		if err != nil {
			return nil, err
		}
		if prev, dup := seen[m.Name]; dup {
			return nil, fmt.Errorf("duplicate module name %q in %s and %s", m.Name, prev, manifestPath)
		}
		seen[m.Name] = manifestPath
		abs, _ := filepath.Abs(filepath.Join(root, e.Name()))
		mods = append(mods, &Module{Module: m, Dir: abs})
	}
	return mods, nil
}
