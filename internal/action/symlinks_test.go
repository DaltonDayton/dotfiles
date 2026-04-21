package action

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSymlink_createsWhenMissing(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src")
	dst := filepath.Join(dir, "dst")
	os.WriteFile(src, []byte("hi"), 0o644)

	s := &Symlink{Src: src, Dst: dst, ConflictPolicy: ConflictBackup}

	ok, err := s.Check()
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("Check should be false before Apply")
	}
	if err := s.Apply(); err != nil {
		t.Fatal(err)
	}
	got, err := os.Readlink(dst)
	if err != nil {
		t.Fatal(err)
	}
	if got != src {
		t.Errorf("readlink = %q, want %q", got, src)
	}
}

func TestSymlink_idempotentWhenCorrect(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src")
	dst := filepath.Join(dir, "dst")
	os.WriteFile(src, []byte("x"), 0o644)
	os.Symlink(src, dst)

	s := &Symlink{Src: src, Dst: dst}
	ok, err := s.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("Check should be true when symlink already points at src")
	}
}

func TestSymlink_backsUpConflictingFile(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src")
	dst := filepath.Join(dir, "dst")
	os.WriteFile(src, []byte("new"), 0o644)
	os.WriteFile(dst, []byte("existing"), 0o644)

	s := &Symlink{Src: src, Dst: dst, ConflictPolicy: ConflictBackup}
	if err := s.Apply(); err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if _, err := os.Lstat(dst + ".bak"); err != nil {
		t.Errorf("expected backup at %s.bak: %v", dst, err)
	}
	got, _ := os.Readlink(dst)
	if got != src {
		t.Errorf("dst does not link to src after backup, got %q", got)
	}
}

func TestSymlink_overwritePolicyReplacesExisting(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src")
	dst := filepath.Join(dir, "dst")
	os.WriteFile(src, []byte("new"), 0o644)
	os.WriteFile(dst, []byte("existing"), 0o644)

	s := &Symlink{Src: src, Dst: dst, ConflictPolicy: ConflictOverwrite}
	if err := s.Apply(); err != nil {
		t.Fatalf("Apply: %v", err)
	}
	got, _ := os.Readlink(dst)
	if got != src {
		t.Errorf("dst does not link to src after overwrite, got %q", got)
	}
	if _, err := os.Lstat(dst + ".bak"); err == nil {
		t.Errorf("overwrite should not create a backup")
	}
}

func TestSymlink_skipPolicyLeavesExisting(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src")
	dst := filepath.Join(dir, "dst")
	os.WriteFile(src, []byte("new"), 0o644)
	os.WriteFile(dst, []byte("existing"), 0o644)

	s := &Symlink{Src: src, Dst: dst, ConflictPolicy: ConflictSkip}
	if err := s.Apply(); err != nil {
		t.Fatalf("Apply: %v", err)
	}
	// dst should still be the original regular file, not a symlink
	info, err := os.Lstat(dst)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode()&os.ModeSymlink != 0 {
		t.Error("skip policy should not replace existing file with a symlink")
	}
}

func TestSymlink_satisfiesActionInterface(t *testing.T) {
	var _ Action = (*Symlink)(nil)
}
