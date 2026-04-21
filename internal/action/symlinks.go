package action

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

// ConflictPolicy controls what Apply does when Dst exists as a regular file
// (not a symlink) that would otherwise collide with the symlink we want to
// create.
type ConflictPolicy string

const (
	ConflictBackup    ConflictPolicy = "backup"    // rename existing to <dst>.bak
	ConflictOverwrite ConflictPolicy = "overwrite" // delete existing, then link
	ConflictSkip      ConflictPolicy = "skip"      // leave existing, do nothing
)

// Symlink ensures Dst is a symlink pointing at Src.
//
// A wrong-target symlink (Dst is a symlink but points somewhere else) is
// always replaced — that's considered our own drift to heal, not a user file
// to preserve, regardless of ConflictPolicy.
type Symlink struct {
	Src            string
	Dst            string
	ConflictPolicy ConflictPolicy
}

func (s *Symlink) Describe() string {
	return fmt.Sprintf("symlink %s -> %s", s.Dst, s.Src)
}

func (s *Symlink) Check() (bool, error) {
	info, err := os.Lstat(s.Dst)
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if info.Mode()&os.ModeSymlink == 0 {
		return false, nil // Dst exists but isn't a symlink
	}
	target, err := os.Readlink(s.Dst)
	if err != nil {
		return false, err
	}
	return target == s.Src, nil
}

func (s *Symlink) Apply() error {
	if err := os.MkdirAll(filepath.Dir(s.Dst), 0o755); err != nil {
		return err
	}
	info, err := os.Lstat(s.Dst)
	switch {
	case errors.Is(err, os.ErrNotExist):
		// nothing at Dst — fall through and create the symlink
	case err != nil:
		return err
	case info.Mode()&os.ModeSymlink != 0:
		// existing symlink: keep if target matches, else replace (self-heal)
		if target, _ := os.Readlink(s.Dst); target == s.Src {
			return nil
		}
		if err := os.Remove(s.Dst); err != nil {
			return err
		}
	default:
		// existing regular file or dir — apply conflict policy
		switch s.ConflictPolicy {
		case ConflictOverwrite:
			if err := os.RemoveAll(s.Dst); err != nil {
				return err
			}
		case ConflictSkip:
			return nil
		case ConflictBackup, "":
			if err := os.Rename(s.Dst, s.Dst+".bak"); err != nil {
				return err
			}
		default:
			return fmt.Errorf("unknown conflict policy %q", s.ConflictPolicy)
		}
	}
	return os.Symlink(s.Src, s.Dst)
}
