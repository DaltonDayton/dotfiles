package action

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

// File writes Content to Dst with Mode. Idempotent: Check returns true when
// the file already exists with matching content and mode. Apply always
// overwrites — drift on a managed file is healed back to the declared state.
type File struct {
	Dst     string
	Content string
	Mode    string
}

func (f *File) Describe() string {
	return fmt.Sprintf("write file %s", f.Dst)
}

func (f *File) Check() (bool, error) {
	got, err := os.ReadFile(f.Dst)
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if string(got) != f.Content {
		return false, nil
	}
	info, err := os.Stat(f.Dst)
	if err != nil {
		return false, err
	}
	want, err := parseMode(f.Mode)
	if err != nil {
		return false, err
	}
	return info.Mode().Perm() == want, nil
}

func (f *File) Apply() error {
	mode, err := parseMode(f.Mode)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(f.Dst), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(f.Dst, []byte(f.Content), mode); err != nil {
		return err
	}
	// why: WriteFile only sets mode when creating a new file; if Dst already
	// existed, its prior mode is preserved. Chmod forces the declared mode.
	return os.Chmod(f.Dst, mode)
}
