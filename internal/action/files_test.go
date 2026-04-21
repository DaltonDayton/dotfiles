package action

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFile_writesMissing(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "out.conf")
	f := &File{Dst: dst, Content: "hello\n", Mode: "0644"}

	ok, err := f.Check()
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("Check should be false before Apply")
	}
	if err := f.Apply(); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(dst)
	if string(got) != "hello\n" {
		t.Errorf("content = %q", got)
	}
}

func TestFile_idempotentWhenContentMatches(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "out.conf")
	os.WriteFile(dst, []byte("hello\n"), 0o644)

	f := &File{Dst: dst, Content: "hello\n", Mode: "0644"}
	ok, err := f.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("Check should be true when content+mode match")
	}
}

func TestFile_rewritesWhenContentDiffers(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "out.conf")
	os.WriteFile(dst, []byte("old\n"), 0o644)

	f := &File{Dst: dst, Content: "new\n", Mode: "0644"}
	ok, err := f.Check()
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("Check should be false when content differs")
	}
	if err := f.Apply(); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(dst)
	if string(got) != "new\n" {
		t.Errorf("content = %q", got)
	}
}

func TestFile_rewritesWhenModeDiffers(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "out.conf")
	os.WriteFile(dst, []byte("x"), 0o600) // correct content, wrong mode

	f := &File{Dst: dst, Content: "x", Mode: "0644"}
	ok, err := f.Check()
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("Check should be false when mode differs")
	}
	if err := f.Apply(); err != nil {
		t.Fatal(err)
	}
	info, _ := os.Stat(dst)
	if info.Mode().Perm() != 0o644 {
		t.Errorf("mode = %v, want 0644", info.Mode().Perm())
	}
}

func TestFile_createsParentDirectories(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "nested", "deeper", "out.conf")

	f := &File{Dst: dst, Content: "y", Mode: "0644"}
	if err := f.Apply(); err != nil {
		t.Fatalf("Apply: %v", err)
	}
	if _, err := os.Stat(dst); err != nil {
		t.Fatal(err)
	}
}

func TestFile_satisfiesActionInterface(t *testing.T) {
	var _ Action = (*File)(nil)
}
