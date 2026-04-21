package action

import (
	"fmt"
	"os"
	"strconv"
)

// Directory ensures a directory exists with the requested mode.
type Directory struct {
	Path string
	Mode string // octal string, e.g. "0755"
}

func (d *Directory) Describe() string {
	return fmt.Sprintf("ensure directory %s (mode %s)", d.Path, d.Mode)
}

func (d *Directory) Check() (bool, error) {
	info, err := os.Stat(d.Path)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if !info.IsDir() {
		return false, fmt.Errorf("%s exists but is not a directory", d.Path)
	}
	want, err := parseMode(d.Mode)
	if err != nil {
		return false, err
	}
	return info.Mode().Perm() == want, nil
}

func (d *Directory) Apply() error {
	want, err := parseMode(d.Mode)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(d.Path, want); err != nil {
		return err
	}
	// why: MkdirAll respects the process umask, so the resulting mode may be
	// narrower than requested. Chmod forces the exact permissions.
	return os.Chmod(d.Path, want)
}

// parseMode converts an octal string like "0755" to an os.FileMode.
// Empty string defaults to 0755.
func parseMode(s string) (os.FileMode, error) {
	if s == "" {
		return 0o755, nil
	}
	n, err := strconv.ParseUint(s, 8, 32)
	if err != nil {
		return 0, fmt.Errorf("invalid mode %q: %w", s, err)
	}
	return os.FileMode(n), nil
}
