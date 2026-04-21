package runner

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

func TestRunInstallSh_executesWhenPresent(t *testing.T) {
	dir := t.TempDir()
	marker := filepath.Join(dir, "ran")
	script := "#!/bin/sh\ntouch " + marker + "\n"
	os.WriteFile(filepath.Join(dir, "install.sh"), []byte(script), 0o755)

	m := &module.Module{Dir: dir, Module: &manifest.Module{Name: "t"}}
	if err := RunInstallSh(m); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatalf("install.sh did not run: %v", err)
	}
}

func TestRunInstallSh_noopWhenMissing(t *testing.T) {
	dir := t.TempDir()
	m := &module.Module{Dir: dir, Module: &manifest.Module{Name: "t"}}
	if err := RunInstallSh(m); err != nil {
		t.Fatal(err)
	}
}

func TestRunInstallSh_reportsScriptFailure(t *testing.T) {
	dir := t.TempDir()
	script := "#!/bin/sh\nexit 7\n"
	os.WriteFile(filepath.Join(dir, "install.sh"), []byte(script), 0o755)

	m := &module.Module{Dir: dir, Module: &manifest.Module{Name: "t"}}
	if err := RunInstallSh(m); err == nil {
		t.Fatal("expected error when install.sh exits non-zero")
	}
}
