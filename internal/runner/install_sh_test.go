package runner

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

// The script writes $QUILL_OS/$QUILL_HOST and "$0"-style proof-of-bash to a
// file we then read back. Bashisms ([[ ]]) confirm we did NOT run under dash.
func TestRunInstallSh_ExportsOSAndUsesBash(t *testing.T) {
	dir := t.TempDir()
	out := filepath.Join(dir, "out.txt")
	script := "#!/usr/bin/env bash\n" +
		"if [[ -n \"$QUILL_OS\" ]]; then echo \"os=$QUILL_OS host=$QUILL_HOST bash=yes\" > \"" + out + "\"; fi\n"
	if err := os.WriteFile(filepath.Join(dir, "install.sh"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}

	m := &module.Module{Dir: dir, Module: &manifest.Module{Name: "x"}}
	if err := RunInstallSh(m, "ubuntu", "Dalton"); err != nil {
		t.Fatal(err)
	}

	got, err := os.ReadFile(out)
	if err != nil {
		t.Fatalf("script did not run as bash with env: %v", err)
	}
	want := "os=ubuntu host=Dalton bash=yes\n"
	if string(got) != want {
		t.Fatalf("got %q, want %q", string(got), want)
	}
}

func TestRunInstallSh_AbsentScriptIsNoError(t *testing.T) {
	m := &module.Module{Dir: t.TempDir(), Module: &manifest.Module{Name: "x"}}
	if err := RunInstallSh(m, "arch", "h"); err != nil {
		t.Fatalf("absent install.sh should be nil, got %v", err)
	}
}

func TestRunInstallSh_reportsScriptFailure(t *testing.T) {
	dir := t.TempDir()
	script := "#!/bin/sh\nexit 7\n"
	if err := os.WriteFile(filepath.Join(dir, "install.sh"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}

	m := &module.Module{Dir: dir, Module: &manifest.Module{Name: "t"}}
	if err := RunInstallSh(m, "arch", "h"); err == nil {
		t.Fatal("expected error when install.sh exits non-zero")
	}
}

func TestInstallShNeedsSudo(t *testing.T) {
	cases := []struct {
		name   string
		script string // empty means "no install.sh present"
		want   bool
	}{
		{name: "missing", script: "", want: false},
		{name: "no sudo", script: "#!/bin/sh\necho hi\n", want: false},
		{name: "sudo invocation", script: "#!/bin/sh\nsudo cp a b\n", want: true},
		{name: "sudo only in comment", script: "#!/bin/sh\n# sudo here is fine\necho hi\n", want: false},
		{name: "indented sudo", script: "#!/bin/sh\nif x; then\n    sudo cp a b\nfi\n", want: true},
		{name: "inline comment after sudo", script: "#!/bin/sh\nsudo cp a b # needs root\n", want: true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			dir := t.TempDir()
			if c.script != "" {
				if err := os.WriteFile(filepath.Join(dir, "install.sh"), []byte(c.script), 0o755); err != nil {
					t.Fatal(err)
				}
			}
			m := &module.Module{Dir: dir, Module: &manifest.Module{Name: "t"}}
			if got := InstallShNeedsSudo(m); got != c.want {
				t.Errorf("InstallShNeedsSudo() = %v, want %v", got, c.want)
			}
		})
	}
}

func TestPlanInstallShNeedsSudo(t *testing.T) {
	dir1 := t.TempDir()
	dir2 := t.TempDir()
	os.WriteFile(filepath.Join(dir2, "install.sh"), []byte("#!/bin/sh\nsudo cp a b\n"), 0o755)

	plan := []ModulePlan{
		{Module: &module.Module{Dir: dir1, Module: &manifest.Module{Name: "a"}}},
		{Module: &module.Module{Dir: dir2, Module: &manifest.Module{Name: "b"}}},
	}
	if !PlanInstallShNeedsSudo(plan) {
		t.Errorf("expected true when one module's install.sh uses sudo")
	}

	plan = plan[:1]
	if PlanInstallShNeedsSudo(plan) {
		t.Errorf("expected false when no module has install.sh")
	}
}
