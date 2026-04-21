// Package state stores lightweight UI preferences (not system state).
// The sole persisted artifact is last_selection.json — the set of modules
// the selector last pre-checked. Deleting it is harmless.
package state

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
)

type selectionFile struct {
	Modules []string `json:"modules"`
}

// LoadSelection reads the selection JSON at path. A missing file is not an
// error — it returns nil slice + nil error (first run).
func LoadSelection(path string) ([]string, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var s selectionFile
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, err
	}
	return s.Modules, nil
}

func SaveSelection(path string, modules []string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(selectionFile{Modules: modules}, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}

// DefaultPath returns ~/.local/state/quill/last_selection.json.
func DefaultPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "state", "quill", "last_selection.json"), nil
}
