package action

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDirectory_createsMissing(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "sub", "nested")
	d := &Directory{Path: target, Mode: "0755"}

	ok, err := d.Check()
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("Check should be false before Apply")
	}
	if err := d.Apply(); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(target)
	if err != nil {
		t.Fatal(err)
	}
	if !info.IsDir() {
		t.Fatal("target is not a directory")
	}
}

func TestDirectory_idempotent(t *testing.T) {
	dir := t.TempDir()
	// t.TempDir creates the dir with the user's default perms; force 0755 to
	// match what Check expects.
	if err := os.Chmod(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	d := &Directory{Path: dir, Mode: "0755"}

	ok, err := d.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("Check should be true when dir already exists with the right mode")
	}
}

func TestDirectory_satisfiesActionInterface(t *testing.T) {
	// Compile-time check: *Directory must satisfy Action.
	var _ Action = (*Directory)(nil)
}
