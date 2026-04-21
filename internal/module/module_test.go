package module

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadAll_findsModules(t *testing.T) {
	root := t.TempDir()
	os.MkdirAll(filepath.Join(root, "git"), 0o755)
	os.WriteFile(filepath.Join(root, "git", "module.toml"), []byte(`name = "git"`), 0o644)
	os.MkdirAll(filepath.Join(root, "zsh"), 0o755)
	os.WriteFile(filepath.Join(root, "zsh", "module.toml"), []byte(`name = "zsh"`), 0o644)
	os.MkdirAll(filepath.Join(root, "not-a-module"), 0o755)

	mods, err := LoadAll(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(mods) != 2 {
		t.Fatalf("got %d modules, want 2", len(mods))
	}
}

func TestLoadAll_errorOnDuplicateName(t *testing.T) {
	root := t.TempDir()
	os.MkdirAll(filepath.Join(root, "a"), 0o755)
	os.MkdirAll(filepath.Join(root, "b"), 0o755)
	os.WriteFile(filepath.Join(root, "a", "module.toml"), []byte(`name = "git"`), 0o644)
	os.WriteFile(filepath.Join(root, "b", "module.toml"), []byte(`name = "git"`), 0o644)

	_, err := LoadAll(root)
	if err == nil {
		t.Fatal("expected duplicate-name error")
	}
}

func TestLoadAll_emptyDirIsEmpty(t *testing.T) {
	mods, err := LoadAll(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if len(mods) != 0 {
		t.Errorf("expected zero modules, got %d", len(mods))
	}
}
