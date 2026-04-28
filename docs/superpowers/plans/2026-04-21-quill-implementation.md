# `quill` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Status (2026-04-28):** Quill is built and shipping on `startover`. All action types from this plan exist in `internal/action/`; the runner, manifest parser, host detection, template renderer, TUI, and CLI commands (`list`/`status`/`apply`/`install`/`path`) all work. `flatpak` and `paru` from the original spec were not implemented (only `pacman` and `yay` are wired up in `internal/action/packages.go`). Real modules (`git`, `shell`, `tmux`, `fonts`, `asdf`, `neovim`, `hyprland`, `ai`) live under `modules/`. Plan retained as historical record of the design phase.

**Goal:** Build a Go CLI (`quill`) that declaratively installs and manages an Arch Linux workstation setup (packages, dotfiles, services, host-specific config) via a Charm-powered TUI.

**Architecture:** Single binary. Each "module" is a directory under `modules/` containing a `module.toml` manifest plus files. The binary parses manifests, filters by host, resolves dependencies, then runs idempotent **actions** (`packages`, `symlinks`, `commands`, `files`, `services`, `directories`). A Charm TUI (Huh for forms, Bubble Tea for progress, Lip Gloss for styling) drives `quill install`; non-interactive `apply`/`list`/`status` commands cover scripted re-runs. Stateless idempotency — every action has a `Check()` that determines whether `Apply()` needs to run.

**Tech Stack:** Go 1.22+, `github.com/BurntSushi/toml`, `github.com/charmbracelet/bubbletea`, `github.com/charmbracelet/huh`, `github.com/charmbracelet/lipgloss`, `github.com/spf13/cobra`.

**Spec:** `docs/superpowers/specs/2026-04-21-quill-design.md`

---

## File Structure

```
.dotfiles/
├── bootstrap.sh
├── go.mod / go.sum
├── cmd/quill/main.go                    # cobra entry + subcommand wiring
├── internal/
│   ├── manifest/
│   │   ├── schema.go                     # TOML structs
│   │   ├── parse.go                      # load module.toml / host.toml
│   │   └── parse_test.go
│   ├── module/
│   │   ├── module.go                     # Module type, loader (walks modules/)
│   │   └── module_test.go
│   ├── host/
│   │   ├── host.go                       # hostname detection, Host struct
│   │   └── host_test.go
│   ├── template/
│   │   ├── render.go                     # text/template wrapper
│   │   └── render_test.go
│   ├── action/
│   │   ├── action.go                     # Action interface
│   │   ├── directories.go                # simplest — establishes pattern
│   │   ├── directories_test.go
│   │   ├── symlinks.go
│   │   ├── symlinks_test.go
│   │   ├── files.go
│   │   ├── files_test.go
│   │   ├── commands.go
│   │   ├── commands_test.go
│   │   ├── services.go
│   │   ├── services_test.go
│   │   ├── packages.go                   # pacman + paru + yay + flatpak
│   │   └── packages_test.go
│   ├── runner/
│   │   ├── runner.go                     # dep resolution, host filtering, Apply loop
│   │   └── runner_test.go
│   ├── state/
│   │   └── selection.go                  # last_selection.json read/write
│   └── tui/
│       ├── styles.go                     # lipgloss styles
│       ├── selector.go                   # huh multi-select grouped by tag
│       ├── progress.go                   # bubbletea progress model
│       └── banner.go                     # host-detection banner
├── modules/                              # real modules (git, zsh, etc. later)
├── hosts/                                # desktop.toml / laptop.toml
└── docs/superpowers/
    ├── specs/2026-04-21-quill-design.md
    └── plans/2026-04-21-quill-implementation.md
```

**Design rules the plan enforces:**
- Every action type implements the same `Action` interface (`Check()`, `Apply()`, `Describe()`) — pattern introduced in Task 6 and reused.
- Every `internal/` package ships with a `_test.go` in the same task that introduces it.
- No package imports `cmd/` or `tui/` — TUI is a presentation layer over `runner`.
- Action executors never shell out to `sudo` interactively without a TTY check (details in Task 12).

---

## Phase 0 — Scaffolding

### Task 0: Initialize Go module and repo layout

**Files:**
- Create: `go.mod`
- Create: `cmd/quill/main.go`
- Create: `.gitignore`
- Create: `README.md`

- [ ] **Step 1: Initialize the Go module**

Run:
```bash
cd /home/dalton/Development/.dotfiles
go mod init github.com/DaltonDayton/dotfiles
```
Expected: creates `go.mod` with module path.

- [ ] **Step 2: Create minimal main.go**

Create `cmd/quill/main.go`:
```go
package main

import "fmt"

func main() {
	fmt.Println("quill: not yet implemented")
}
```

- [ ] **Step 3: Create .gitignore**

Create `.gitignore`:
```
/bin/
*.test
/coverage.out
.DS_Store
```

- [ ] **Step 4: Create placeholder README**

Create `README.md`:
```markdown
# dotfiles

Arch Linux machine setup managed by `quill`.

See `docs/superpowers/specs/2026-04-21-quill-design.md` for the design.
Bootstrap: `curl -fsSL <url>/bootstrap.sh | bash` (once published).
```

- [ ] **Step 5: Verify the build**

Run:
```bash
go build -o ./bin/quill ./cmd/quill && ./bin/quill
```
Expected: prints `quill: not yet implemented`.

- [ ] **Step 6: Commit**

```bash
git add go.mod cmd/ .gitignore README.md
git commit -m "scaffold: initialize Go module and minimal quill binary"
```

---

## Phase 1 — Foundation: parsing, hosts, templates

### Task 1: Manifest schema and parser

**Files:**
- Create: `internal/manifest/schema.go`
- Create: `internal/manifest/parse.go`
- Create: `internal/manifest/parse_test.go`

- [ ] **Step 1: Add TOML dependency**

Run:
```bash
go get github.com/BurntSushi/toml
```

- [ ] **Step 2: Write the schema**

Create `internal/manifest/schema.go`:
```go
package manifest

// Module mirrors the on-disk module.toml structure.
type Module struct {
	Name        string   `toml:"name"`
	Description string   `toml:"description"`
	Tags        []string `toml:"tags"`
	DependsOn   []string `toml:"depends_on"`
	Hosts       []string `toml:"hosts"`

	Packages    []Packages    `toml:"packages"`
	Symlinks    []Symlink     `toml:"symlinks"`
	Commands    []Command     `toml:"commands"`
	Files       []File        `toml:"files"`
	Services    []Service     `toml:"services"`
	Directories []Directory   `toml:"directories"`
}

type Packages struct {
	Manager string   `toml:"manager"` // "pacman" | "paru" | "yay" | "flatpak"
	Names   []string `toml:"names"`
	Hosts   []string `toml:"hosts"`
}

type Symlink struct {
	Src   string   `toml:"src"`
	Dst   string   `toml:"dst"`
	Hosts []string `toml:"hosts"`
}

type Command struct {
	Run   string   `toml:"run"`
	Check string   `toml:"check"`
	Hosts []string `toml:"hosts"`
}

type File struct {
	Dst         string   `toml:"dst"`
	Content     string   `toml:"content"`
	ContentFrom string   `toml:"content_from"`
	Mode        string   `toml:"mode"`
	Hosts       []string `toml:"hosts"`
}

type Service struct {
	Name  string   `toml:"name"`
	Scope string   `toml:"scope"` // "user" | "system"
	State string   `toml:"state"` // "enabled" | "started" | "enabled+started"
	Hosts []string `toml:"hosts"`
}

type Directory struct {
	Path  string   `toml:"path"`
	Mode  string   `toml:"mode"`
	Hosts []string `toml:"hosts"`
}

// Host mirrors hosts/<name>.toml.
type Host struct {
	Name      string            `toml:"name"`
	AURHelper string            `toml:"aur_helper"`
	Modules   []string          `toml:"modules"`
	Vars      map[string]string `toml:"vars"`
}
```

- [ ] **Step 3: Write the failing parser test**

Create `internal/manifest/parse_test.go`:
```go
package manifest

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseModule_happyPath(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "module.toml")
	content := `
name = "git"
description = "Git + global gitconfig"
tags = ["essential"]
depends_on = []

[[packages]]
manager = "pacman"
names = ["git"]

[[symlinks]]
src = "files/.gitconfig"
dst = "~/.gitconfig"
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	m, err := ParseModule(path)
	if err != nil {
		t.Fatalf("ParseModule: %v", err)
	}
	if m.Name != "git" {
		t.Errorf("Name = %q, want git", m.Name)
	}
	if len(m.Packages) != 1 || m.Packages[0].Manager != "pacman" {
		t.Errorf("Packages = %+v", m.Packages)
	}
	if len(m.Symlinks) != 1 || m.Symlinks[0].Dst != "~/.gitconfig" {
		t.Errorf("Symlinks = %+v", m.Symlinks)
	}
}

func TestParseHost_happyPath(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "laptop.toml")
	content := `
name = "laptop"
aur_helper = "paru"
modules = ["git", "zsh"]

[vars]
monitor = "eDP-1,preferred,auto,1.0"
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	h, err := ParseHost(path)
	if err != nil {
		t.Fatalf("ParseHost: %v", err)
	}
	if h.Name != "laptop" {
		t.Errorf("Name = %q, want laptop", h.Name)
	}
	if h.AURHelper != "paru" {
		t.Errorf("AURHelper = %q, want paru", h.AURHelper)
	}
	if h.Vars["monitor"] == "" {
		t.Errorf("Vars = %+v", h.Vars)
	}
}
```

- [ ] **Step 4: Run the test to confirm it fails**

Run: `go test ./internal/manifest/...`
Expected: FAIL — `ParseModule` and `ParseHost` undefined.

- [ ] **Step 5: Implement the parser**

Create `internal/manifest/parse.go`:
```go
package manifest

import (
	"fmt"

	"github.com/BurntSushi/toml"
)

// ParseModule reads and decodes a module.toml file.
func ParseModule(path string) (*Module, error) {
	var m Module
	if _, err := toml.DecodeFile(path, &m); err != nil {
		return nil, fmt.Errorf("decode %s: %w", path, err)
	}
	if m.Name == "" {
		return nil, fmt.Errorf("%s: module is missing required field 'name'", path)
	}
	return &m, nil
}

// ParseHost reads and decodes a hosts/<name>.toml file.
func ParseHost(path string) (*Host, error) {
	var h Host
	if _, err := toml.DecodeFile(path, &h); err != nil {
		return nil, fmt.Errorf("decode %s: %w", path, err)
	}
	if h.Name == "" {
		return nil, fmt.Errorf("%s: host is missing required field 'name'", path)
	}
	if h.Vars == nil {
		h.Vars = map[string]string{}
	}
	return &h, nil
}
```

- [ ] **Step 6: Run tests**

Run: `go test ./internal/manifest/...`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add go.mod go.sum internal/manifest/
git commit -m "manifest: TOML schema and parsers for modules and hosts"
```

---

### Task 2: Host detection

**Files:**
- Create: `internal/host/host.go`
- Create: `internal/host/host_test.go`

- [ ] **Step 1: Write the failing test**

Create `internal/host/host_test.go`:
```go
package host

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoad_byHostname(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "laptop.toml"), []byte(`
name = "laptop"
aur_helper = "paru"
modules = ["git"]
`), 0o644)

	h, err := Load(dir, "laptop")
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if h.Name != "laptop" {
		t.Errorf("Name = %q, want laptop", h.Name)
	}
}

func TestLoad_missingHostFile(t *testing.T) {
	dir := t.TempDir()
	_, err := Load(dir, "unknown")
	if err == nil {
		t.Fatal("expected error for missing host file")
	}
}
```

- [ ] **Step 2: Run the test**

Run: `go test ./internal/host/...`
Expected: FAIL — `Load` undefined.

- [ ] **Step 3: Implement host loading**

Create `internal/host/host.go`:
```go
package host

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

// Detect returns the current machine's hostname.
func Detect() (string, error) {
	h, err := os.Hostname()
	if err != nil {
		return "", fmt.Errorf("detect hostname: %w", err)
	}
	return h, nil
}

// Load reads hosts/<name>.toml from hostsDir.
func Load(hostsDir, name string) (*manifest.Host, error) {
	path := filepath.Join(hostsDir, name+".toml")
	if _, err := os.Stat(path); err != nil {
		return nil, fmt.Errorf("host profile %q not found at %s", name, path)
	}
	return manifest.ParseHost(path)
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/host/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/host/
git commit -m "host: hostname detection and profile loader"
```

---

### Task 3: Template renderer

**Files:**
- Create: `internal/template/render.go`
- Create: `internal/template/render_test.go`

- [ ] **Step 1: Write the failing test**

Create `internal/template/render_test.go`:
```go
package template

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

func TestRender_substitutesHostVars(t *testing.T) {
	h := &manifest.Host{
		Name: "laptop",
		Vars: map[string]string{"monitor": "eDP-1,preferred,auto,1.0"},
	}
	got, err := Render("monitor = {{ .Vars.monitor }}", h)
	if err != nil {
		t.Fatalf("Render: %v", err)
	}
	want := "monitor = eDP-1,preferred,auto,1.0"
	if got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestRender_exposesHostName(t *testing.T) {
	h := &manifest.Host{Name: "desktop"}
	got, err := Render("host={{ .Name }}", h)
	if err != nil {
		t.Fatalf("Render: %v", err)
	}
	if got != "host=desktop" {
		t.Errorf("got %q", got)
	}
}

func TestRender_missingVarIsError(t *testing.T) {
	h := &manifest.Host{Name: "laptop", Vars: map[string]string{}}
	_, err := Render("{{ .Vars.nope }}", h)
	if err == nil {
		t.Fatal("expected error for missing var")
	}
}
```

- [ ] **Step 2: Run the test**

Run: `go test ./internal/template/...`
Expected: FAIL — `Render` undefined.

- [ ] **Step 3: Implement the renderer**

Create `internal/template/render.go`:
```go
package template

import (
	"bytes"
	"fmt"
	"text/template"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

// Render executes a text/template string against a Host. Missing map keys
// cause an error (missingkey=error) so typos in .tmpl files fail loudly.
func Render(src string, h *manifest.Host) (string, error) {
	tmpl, err := template.New("render").Option("missingkey=error").Parse(src)
	if err != nil {
		return "", fmt.Errorf("parse template: %w", err)
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, h); err != nil {
		return "", fmt.Errorf("execute template: %w", err)
	}
	return buf.String(), nil
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/template/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/template/
git commit -m "template: render host vars into template strings"
```

---

## Phase 2 — Action executors

### Task 4: Action interface and directories executor

**Files:**
- Create: `internal/action/action.go`
- Create: `internal/action/directories.go`
- Create: `internal/action/directories_test.go`

- [ ] **Step 1: Define the Action interface**

Create `internal/action/action.go`:
```go
// Package action holds idempotent executors for each declarative action type.
//
// Every action implements the same three-method contract:
//
//   Describe() string   // short human-readable label ("symlink ~/.zshrc")
//   Check() (bool, error)   // true => already applied; Apply will no-op
//   Apply() error           // bring system to desired state
//
// Callers (the runner) invoke Check before Apply and report skipped/applied.
package action

type Status string

const (
	StatusApplied Status = "applied"
	StatusSkipped Status = "skipped"
	StatusFailed  Status = "failed"
)

type Action interface {
	Describe() string
	Check() (bool, error)
	Apply() error
}
```

- [ ] **Step 2: Write failing tests for directories**

Create `internal/action/directories_test.go`:
```go
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
		t.Fatal("Check should be false before apply")
	}
	if err := d.Apply(); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(target)
	if err != nil {
		t.Fatal(err)
	}
	if !info.IsDir() {
		t.Fatal("not a directory")
	}
}

func TestDirectory_idempotent(t *testing.T) {
	dir := t.TempDir()
	d := &Directory{Path: dir, Mode: "0755"}

	ok, err := d.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("Check should be true when directory already exists with correct mode")
	}
}
```

- [ ] **Step 3: Run test**

Run: `go test ./internal/action/...`
Expected: FAIL — `Directory` undefined.

- [ ] **Step 4: Implement directories**

Create `internal/action/directories.go`:
```go
package action

import (
	"fmt"
	"os"
	"strconv"
)

// Directory ensures a directory exists with the requested mode.
type Directory struct {
	Path string
	Mode string // octal string like "0755"
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
	// MkdirAll respects umask; force the mode explicitly.
	return os.Chmod(d.Path, want)
}

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
```

- [ ] **Step 5: Run tests**

Run: `go test ./internal/action/...`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/action/
git commit -m "action: define Action interface and directories executor"
```

---

### Task 5: Symlinks executor

**Files:**
- Create: `internal/action/symlinks.go`
- Create: `internal/action/symlinks_test.go`

- [ ] **Step 1: Write failing tests**

Create `internal/action/symlinks_test.go`:
```go
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
		t.Fatal("Check should be false before apply")
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
		t.Errorf("expected backup at %s.bak", dst)
	}
	got, _ := os.Readlink(dst)
	if got != src {
		t.Errorf("dst does not link to src after backup")
	}
}
```

- [ ] **Step 2: Run tests**

Run: `go test ./internal/action/...`
Expected: FAIL — `Symlink` undefined.

- [ ] **Step 3: Implement symlinks**

Create `internal/action/symlinks.go`:
```go
package action

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

type ConflictPolicy string

const (
	ConflictBackup    ConflictPolicy = "backup"    // rename existing to .bak
	ConflictOverwrite ConflictPolicy = "overwrite" // delete existing
	ConflictSkip      ConflictPolicy = "skip"      // leave existing, don't link
)

// Symlink ensures Dst is a symlink pointing to Src.
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
		return false, nil // dst exists but isn't a symlink
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
	if err == nil {
		// dst exists — resolve conflict
		isLink := info.Mode()&os.ModeSymlink != 0
		if isLink {
			if target, _ := os.Readlink(s.Dst); target == s.Src {
				return nil
			}
			// wrong-target symlink: safe to remove
			if err := os.Remove(s.Dst); err != nil {
				return err
			}
		} else {
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
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return os.Symlink(s.Src, s.Dst)
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/action/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/action/symlinks.go internal/action/symlinks_test.go
git commit -m "action: symlinks executor with conflict policies"
```

---

### Task 6: Files executor

**Files:**
- Create: `internal/action/files.go`
- Create: `internal/action/files_test.go`

- [ ] **Step 1: Write failing tests**

Create `internal/action/files_test.go`:
```go
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
		t.Fatal("Check should be false before apply")
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
		t.Fatal("Check should be true when content matches")
	}
}

func TestFile_rewritesWhenContentDiffers(t *testing.T) {
	dir := t.TempDir()
	dst := filepath.Join(dir, "out.conf")
	os.WriteFile(dst, []byte("old\n"), 0o644)

	f := &File{Dst: dst, Content: "new\n", Mode: "0644"}
	if err := f.Apply(); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(dst)
	if string(got) != "new\n" {
		t.Errorf("content = %q", got)
	}
}
```

- [ ] **Step 2: Run tests**

Run: `go test ./internal/action/...`
Expected: FAIL.

- [ ] **Step 3: Implement files**

Create `internal/action/files.go`:
```go
package action

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

// File writes a fixed string to disk.
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
	return os.WriteFile(f.Dst, []byte(f.Content), mode)
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/action/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/action/files.go internal/action/files_test.go
git commit -m "action: files executor writes content with mode"
```

---

### Task 7: Commands executor

**Files:**
- Create: `internal/action/commands.go`
- Create: `internal/action/commands_test.go`

- [ ] **Step 1: Write failing tests**

Create `internal/action/commands_test.go`:
```go
package action

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCommand_skipsWhenCheckPasses(t *testing.T) {
	c := &Command{Run: "false", Check: "true"}
	ok, err := c.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("Check should be true when check command exits 0")
	}
}

func TestCommand_runsWhenCheckFails(t *testing.T) {
	dir := t.TempDir()
	marker := filepath.Join(dir, "touched")
	c := &Command{
		Run:   "touch " + marker,
		Check: "test -f " + marker,
	}

	ok, err := c.Check()
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("Check should be false before run")
	}
	if err := c.Apply(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatalf("marker not created: %v", err)
	}
}

func TestCommand_noCheckAlwaysRuns(t *testing.T) {
	c := &Command{Run: "true"}
	ok, err := c.Check()
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("Check should be false when no check command supplied")
	}
}
```

- [ ] **Step 2: Run tests**

Run: `go test ./internal/action/...`
Expected: FAIL.

- [ ] **Step 3: Implement commands**

Create `internal/action/commands.go`:
```go
package action

import (
	"fmt"
	"os/exec"
)

// Command runs a shell command, gated by an optional Check command.
type Command struct {
	Run   string
	Check string
}

func (c *Command) Describe() string {
	return fmt.Sprintf("run %q", c.Run)
}

func (c *Command) Check_() (bool, error) { return c.Check__() }

func (c *Command) Check__() (bool, error) {
	if c.Check == "" {
		return false, nil
	}
	cmd := exec.Command("sh", "-c", c.Check)
	if err := cmd.Run(); err != nil {
		if _, ok := err.(*exec.ExitError); ok {
			return false, nil
		}
		return false, fmt.Errorf("check failed: %w", err)
	}
	return true, nil
}

// Check exposes the idempotency gate.
func (c *Command) Check_exported() (bool, error) { return c.Check__() }
```

Wait — that's overcomplicated. Replace with:

```go
package action

import (
	"fmt"
	"os/exec"
)

// Command runs a shell command, gated by an optional check.
type Command struct {
	Run   string
	Check string
}

func (c *Command) Describe() string {
	return fmt.Sprintf("run %q", c.Run)
}

// Check returns true when the check command exits 0 (already applied).
// Empty check => always run (returns false).
func (c *Command) Check_() (bool, error) { panic("use CheckState") }

func (c *Command) CheckState() (bool, error) {
	if c.Check == "" {
		return false, nil
	}
	err := exec.Command("sh", "-c", c.Check).Run()
	if err == nil {
		return true, nil
	}
	if _, ok := err.(*exec.ExitError); ok {
		return false, nil
	}
	return false, fmt.Errorf("check command failed to execute: %w", err)
}

func (c *Command) Apply() error {
	out, err := exec.Command("sh", "-c", c.Run).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s: %w (output: %s)", c.Run, err, string(out))
	}
	return nil
}
```

Note: the `Action` interface declares `Check()` but `Command` has a field named `Check`. Rename the field to avoid the clash. Final version:

```go
package action

import (
	"fmt"
	"os/exec"
)

// Command runs a shell command, gated by an optional idempotency gate.
type Command struct {
	Run       string
	CheckCmd  string // if exits 0, Apply is skipped
}

func (c *Command) Describe() string {
	return fmt.Sprintf("run %q", c.Run)
}

func (c *Command) Check() (bool, error) {
	if c.CheckCmd == "" {
		return false, nil
	}
	err := exec.Command("sh", "-c", c.CheckCmd).Run()
	if err == nil {
		return true, nil
	}
	if _, ok := err.(*exec.ExitError); ok {
		return false, nil
	}
	return false, fmt.Errorf("check command failed to execute: %w", err)
}

func (c *Command) Apply() error {
	out, err := exec.Command("sh", "-c", c.Run).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s: %w (output: %s)", c.Run, err, string(out))
	}
	return nil
}
```

- [ ] **Step 4: Update the test to use CheckCmd**

Update `internal/action/commands_test.go` by replacing every `Check:` field literal with `CheckCmd:`:
```go
c := &Command{Run: "false", CheckCmd: "true"}
// and
c := &Command{Run: "touch " + marker, CheckCmd: "test -f " + marker}
```

- [ ] **Step 5: Run tests**

Run: `go test ./internal/action/...`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/action/commands.go internal/action/commands_test.go
git commit -m "action: commands executor with idempotency check gate"
```

---

### Task 8: Services executor

**Files:**
- Create: `internal/action/services.go`
- Create: `internal/action/services_test.go`

- [ ] **Step 1: Introduce a runner indirection for testing**

Shell-out calls to `systemctl` would make this hard to test. Add a package-level variable so tests can substitute a fake.

Create `internal/action/services.go`:
```go
package action

import (
	"fmt"
	"os/exec"
	"strings"
)

// systemctl is overridable for tests.
var systemctl = func(args ...string) (string, error) {
	out, err := exec.Command("systemctl", args...).CombinedOutput()
	return string(out), err
}

// Service ensures a systemd unit reaches a desired state.
type Service struct {
	Name  string
	Scope string // "user" | "system"
	State string // "enabled" | "started" | "enabled+started"
}

func (s *Service) Describe() string {
	return fmt.Sprintf("systemd %s unit %s -> %s", s.Scope, s.Name, s.State)
}

func (s *Service) scopeArgs() []string {
	if s.Scope == "user" {
		return []string{"--user"}
	}
	return nil
}

func (s *Service) isEnabled() (bool, error) {
	args := append(s.scopeArgs(), "is-enabled", s.Name)
	out, err := systemctl(args...)
	out = strings.TrimSpace(out)
	if err != nil {
		// systemctl returns nonzero for "disabled" etc. Check stdout.
		if out == "disabled" || out == "masked" || out == "static" {
			return false, nil
		}
		return false, fmt.Errorf("is-enabled: %w (output: %s)", err, out)
	}
	return out == "enabled" || out == "alias", nil
}

func (s *Service) isActive() (bool, error) {
	args := append(s.scopeArgs(), "is-active", s.Name)
	out, err := systemctl(args...)
	out = strings.TrimSpace(out)
	if err != nil {
		if out == "inactive" || out == "failed" {
			return false, nil
		}
		return false, fmt.Errorf("is-active: %w (output: %s)", err, out)
	}
	return out == "active", nil
}

func (s *Service) Check() (bool, error) {
	needEnabled := strings.Contains(s.State, "enabled")
	needStarted := strings.Contains(s.State, "started")
	if needEnabled {
		ok, err := s.isEnabled()
		if err != nil || !ok {
			return false, err
		}
	}
	if needStarted {
		ok, err := s.isActive()
		if err != nil || !ok {
			return false, err
		}
	}
	return true, nil
}

func (s *Service) Apply() error {
	needEnabled := strings.Contains(s.State, "enabled")
	needStarted := strings.Contains(s.State, "started")
	if needEnabled {
		args := append(s.scopeArgs(), "enable", s.Name)
		if out, err := systemctl(args...); err != nil {
			return fmt.Errorf("enable: %w (%s)", err, out)
		}
	}
	if needStarted {
		args := append(s.scopeArgs(), "start", s.Name)
		if out, err := systemctl(args...); err != nil {
			return fmt.Errorf("start: %w (%s)", err, out)
		}
	}
	return nil
}
```

- [ ] **Step 2: Write tests using the injected fake**

Create `internal/action/services_test.go`:
```go
package action

import "testing"

type fakeSystemctl struct {
	responses map[string]struct {
		out string
		err error
	}
	calls [][]string
}

func (f *fakeSystemctl) fn(args ...string) (string, error) {
	f.calls = append(f.calls, args)
	key := ""
	for _, a := range args {
		key += a + " "
	}
	if r, ok := f.responses[key]; ok {
		return r.out, r.err
	}
	return "", nil
}

func withFake(t *testing.T, f *fakeSystemctl) {
	t.Helper()
	orig := systemctl
	systemctl = f.fn
	t.Cleanup(func() { systemctl = orig })
}

func TestService_checkAlreadyEnabled(t *testing.T) {
	f := &fakeSystemctl{responses: map[string]struct {
		out string
		err error
	}{
		"--user is-enabled hyprpaper.service ": {out: "enabled\n"},
	}}
	withFake(t, f)

	s := &Service{Name: "hyprpaper.service", Scope: "user", State: "enabled"}
	ok, err := s.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("expected Check=true for enabled service")
	}
}

func TestService_applyEnablesAndStarts(t *testing.T) {
	f := &fakeSystemctl{}
	withFake(t, f)

	s := &Service{Name: "foo.service", Scope: "system", State: "enabled+started"}
	if err := s.Apply(); err != nil {
		t.Fatal(err)
	}
	if len(f.calls) != 2 {
		t.Fatalf("expected 2 systemctl calls, got %d", len(f.calls))
	}
	if f.calls[0][0] != "enable" || f.calls[1][0] != "start" {
		t.Errorf("calls = %v", f.calls)
	}
}
```

- [ ] **Step 3: Run tests**

Run: `go test ./internal/action/...`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add internal/action/services.go internal/action/services_test.go
git commit -m "action: services executor with injectable systemctl"
```

---

### Task 9: Packages executor

**Files:**
- Create: `internal/action/packages.go`
- Create: `internal/action/packages_test.go`

- [ ] **Step 1: Design the package manager abstraction**

Each supported manager (`pacman`, `paru`, `yay`, `flatpak`) shares the same shape: `isInstalled(name) bool`, `install([]string) error`. Inject a map from manager name to driver so tests can swap them.

- [ ] **Step 2: Write failing tests**

Create `internal/action/packages_test.go`:
```go
package action

import "testing"

type fakeDriver struct {
	installed map[string]bool
	installed_hist []string
}

func (d *fakeDriver) IsInstalled(name string) (bool, error) {
	return d.installed[name], nil
}

func (d *fakeDriver) Install(names []string) error {
	for _, n := range names {
		d.installed_hist = append(d.installed_hist, n)
		if d.installed == nil {
			d.installed = map[string]bool{}
		}
		d.installed[n] = true
	}
	return nil
}

func TestPackages_checkAllInstalled(t *testing.T) {
	d := &fakeDriver{installed: map[string]bool{"git": true, "zsh": true}}
	pkgDrivers = map[string]PackageDriver{"pacman": d}

	p := &Packages{Manager: "pacman", Names: []string{"git", "zsh"}}
	ok, err := p.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("expected Check=true when all installed")
	}
}

func TestPackages_applyInstallsMissingOnly(t *testing.T) {
	d := &fakeDriver{installed: map[string]bool{"git": true}}
	pkgDrivers = map[string]PackageDriver{"pacman": d}

	p := &Packages{Manager: "pacman", Names: []string{"git", "zsh"}}
	if err := p.Apply(); err != nil {
		t.Fatal(err)
	}
	if len(d.installed_hist) != 1 || d.installed_hist[0] != "zsh" {
		t.Errorf("installed history = %v, want [zsh]", d.installed_hist)
	}
}

func TestPackages_unknownManager(t *testing.T) {
	pkgDrivers = map[string]PackageDriver{}
	p := &Packages{Manager: "nope", Names: []string{"x"}}
	_, err := p.Check()
	if err == nil {
		t.Fatal("expected error for unknown manager")
	}
}
```

- [ ] **Step 3: Implement packages + drivers**

Create `internal/action/packages.go`:
```go
package action

import (
	"fmt"
	"os/exec"
	"strings"
)

type PackageDriver interface {
	IsInstalled(name string) (bool, error)
	Install(names []string) error
}

// pkgDrivers is overridable for tests.
var pkgDrivers = map[string]PackageDriver{
	"pacman":  &pacmanDriver{},
	"paru":    &paruDriver{},
	"yay":     &yayDriver{},
	"flatpak": &flatpakDriver{},
}

type Packages struct {
	Manager string
	Names   []string
}

func (p *Packages) Describe() string {
	return fmt.Sprintf("%s: install %s", p.Manager, strings.Join(p.Names, ", "))
}

func (p *Packages) driver() (PackageDriver, error) {
	d, ok := pkgDrivers[p.Manager]
	if !ok {
		return nil, fmt.Errorf("unknown package manager %q", p.Manager)
	}
	return d, nil
}

func (p *Packages) Check() (bool, error) {
	d, err := p.driver()
	if err != nil {
		return false, err
	}
	for _, n := range p.Names {
		ok, err := d.IsInstalled(n)
		if err != nil {
			return false, err
		}
		if !ok {
			return false, nil
		}
	}
	return true, nil
}

func (p *Packages) Apply() error {
	d, err := p.driver()
	if err != nil {
		return err
	}
	var missing []string
	for _, n := range p.Names {
		ok, err := d.IsInstalled(n)
		if err != nil {
			return err
		}
		if !ok {
			missing = append(missing, n)
		}
	}
	if len(missing) == 0 {
		return nil
	}
	return d.Install(missing)
}

// --- drivers -----------------------------------------------------

type pacmanDriver struct{}

func (pacmanDriver) IsInstalled(name string) (bool, error) {
	err := exec.Command("pacman", "-Q", name).Run()
	if err == nil {
		return true, nil
	}
	if _, ok := err.(*exec.ExitError); ok {
		return false, nil
	}
	return false, err
}

func (pacmanDriver) Install(names []string) error {
	args := append([]string{"pacman", "-S", "--needed", "--noconfirm"}, names...)
	return runSudo(args...)
}

type paruDriver struct{}

func (paruDriver) IsInstalled(name string) (bool, error) {
	return pacmanDriver{}.IsInstalled(name) // paru uses the pacman DB
}
func (paruDriver) Install(names []string) error {
	args := append([]string{"-S", "--needed", "--noconfirm"}, names...)
	return exec.Command("paru", args...).Run()
}

type yayDriver struct{}

func (yayDriver) IsInstalled(name string) (bool, error) {
	return pacmanDriver{}.IsInstalled(name)
}
func (yayDriver) Install(names []string) error {
	args := append([]string{"-S", "--needed", "--noconfirm"}, names...)
	return exec.Command("yay", args...).Run()
}

type flatpakDriver struct{}

func (flatpakDriver) IsInstalled(name string) (bool, error) {
	err := exec.Command("flatpak", "info", name).Run()
	if err == nil {
		return true, nil
	}
	if _, ok := err.(*exec.ExitError); ok {
		return false, nil
	}
	return false, err
}
func (flatpakDriver) Install(names []string) error {
	args := append([]string{"install", "-y"}, names...)
	return exec.Command("flatpak", args...).Run()
}

func runSudo(args ...string) error {
	full := append([]string{"-n", "--"}, args...) // -n: non-interactive; errors out if password prompt would appear
	out, err := exec.Command("sudo", full...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("sudo %s: %w (%s)", strings.Join(args, " "), err, string(out))
	}
	return nil
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/action/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/action/packages.go internal/action/packages_test.go
git commit -m "action: packages executor with pacman/paru/yay/flatpak drivers"
```

---

## Phase 3 — Module loader and runner

### Task 10: Module loader (walks modules/)

**Files:**
- Create: `internal/module/module.go`
- Create: `internal/module/module_test.go`

- [ ] **Step 1: Write failing tests**

Create `internal/module/module_test.go`:
```go
package module

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadAll_findsModules(t *testing.T) {
	root := t.TempDir()
	// module A
	os.MkdirAll(filepath.Join(root, "git"), 0o755)
	os.WriteFile(filepath.Join(root, "git", "module.toml"), []byte(`name = "git"`), 0o644)
	// module B
	os.MkdirAll(filepath.Join(root, "zsh"), 0o755)
	os.WriteFile(filepath.Join(root, "zsh", "module.toml"), []byte(`name = "zsh"`), 0o644)
	// decoy (no module.toml)
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
```

- [ ] **Step 2: Run test**

Run: `go test ./internal/module/...`
Expected: FAIL.

- [ ] **Step 3: Implement the loader**

Create `internal/module/module.go`:
```go
package module

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

// Module wraps a parsed manifest with its on-disk directory path.
type Module struct {
	*manifest.Module
	Dir string // absolute path to the module's directory
}

// LoadAll walks root looking for <name>/module.toml files.
func LoadAll(root string) ([]*Module, error) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", root, err)
	}
	var mods []*Module
	seen := map[string]string{}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		manifestPath := filepath.Join(root, e.Name(), "module.toml")
		if _, err := os.Stat(manifestPath); err != nil {
			continue
		}
		m, err := manifest.ParseModule(manifestPath)
		if err != nil {
			return nil, err
		}
		if prev, dup := seen[m.Name]; dup {
			return nil, fmt.Errorf("duplicate module name %q in %s and %s", m.Name, prev, manifestPath)
		}
		seen[m.Name] = manifestPath
		abs, _ := filepath.Abs(filepath.Join(root, e.Name()))
		mods = append(mods, &Module{Module: m, Dir: abs})
	}
	return mods, nil
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/module/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/module/
git commit -m "module: loader that walks modules/ and parses module.toml"
```

---

### Task 11: Selection state (last_selection.json)

**Files:**
- Create: `internal/state/selection.go`
- Create: `internal/state/selection_test.go`

- [ ] **Step 1: Write failing tests**

Create `internal/state/selection_test.go`:
```go
package state

import (
	"path/filepath"
	"testing"
)

func TestLoadSelection_missingFileReturnsEmpty(t *testing.T) {
	dir := t.TempDir()
	got, err := LoadSelection(filepath.Join(dir, "selection.json"))
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 0 {
		t.Errorf("expected empty, got %v", got)
	}
}

func TestSaveAndLoadRoundtrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "selection.json")
	want := []string{"git", "zsh", "hyprland"}
	if err := SaveSelection(path, want); err != nil {
		t.Fatal(err)
	}
	got, err := LoadSelection(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != len(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}
```

- [ ] **Step 2: Implement**

Create `internal/state/selection.go`:
```go
// Package state stores lightweight UI preferences (not system state).
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
```

- [ ] **Step 3: Run tests**

Run: `go test ./internal/state/...`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add internal/state/
git commit -m "state: last_selection.json read/write"
```

---

### Task 12: Runner — orchestrates deps, host filter, apply loop

**Files:**
- Create: `internal/runner/runner.go`
- Create: `internal/runner/runner_test.go`

- [ ] **Step 1: Write failing tests for dependency resolution**

Create `internal/runner/runner_test.go`:
```go
package runner

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

func mod(name string, deps ...string) *module.Module {
	return &module.Module{
		Module: &manifest.Module{Name: name, DependsOn: deps},
		Dir:    "/tmp/" + name,
	}
}

func TestResolveDeps_transitive(t *testing.T) {
	all := []*module.Module{mod("a"), mod("b", "a"), mod("c", "b")}
	got, err := ResolveDeps(all, []string{"c"})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 3 {
		t.Fatalf("got %d, want 3", len(got))
	}
	// topological: a, b, c
	want := []string{"a", "b", "c"}
	for i, m := range got {
		if m.Name != want[i] {
			t.Errorf("got[%d] = %s, want %s", i, m.Name, want[i])
		}
	}
}

func TestResolveDeps_cycle(t *testing.T) {
	all := []*module.Module{mod("a", "b"), mod("b", "a")}
	_, err := ResolveDeps(all, []string{"a"})
	if err == nil {
		t.Fatal("expected cycle error")
	}
}

func TestResolveDeps_unknownModule(t *testing.T) {
	all := []*module.Module{mod("a")}
	_, err := ResolveDeps(all, []string{"ghost"})
	if err == nil {
		t.Fatal("expected error for unknown module")
	}
}

func TestFilterByHost(t *testing.T) {
	all := []*module.Module{
		{Module: &manifest.Module{Name: "only-desktop", Hosts: []string{"desktop"}}},
		{Module: &manifest.Module{Name: "both"}}, // empty = all hosts
	}
	got := FilterByHost(all, "laptop")
	if len(got) != 1 || got[0].Name != "both" {
		t.Errorf("got %v", got)
	}
}
```

- [ ] **Step 2: Run test**

Run: `go test ./internal/runner/...`
Expected: FAIL.

- [ ] **Step 3: Implement deps + host filter**

Create `internal/runner/runner.go`:
```go
// Package runner orchestrates dependency resolution, host filtering,
// action construction, and the apply loop.
package runner

import (
	"fmt"

	"github.com/DaltonDayton/dotfiles/internal/module"
)

// ResolveDeps returns the transitive closure of selected modules, in
// topological (dependency-first) order. Errors on unknown names or cycles.
func ResolveDeps(all []*module.Module, selected []string) ([]*module.Module, error) {
	byName := map[string]*module.Module{}
	for _, m := range all {
		byName[m.Name] = m
	}
	var order []*module.Module
	visited := map[string]bool{}
	onStack := map[string]bool{}

	var visit func(name string) error
	visit = func(name string) error {
		if visited[name] {
			return nil
		}
		if onStack[name] {
			return fmt.Errorf("dependency cycle involving %q", name)
		}
		m, ok := byName[name]
		if !ok {
			return fmt.Errorf("unknown module %q", name)
		}
		onStack[name] = true
		for _, dep := range m.DependsOn {
			if err := visit(dep); err != nil {
				return err
			}
		}
		onStack[name] = false
		visited[name] = true
		order = append(order, m)
		return nil
	}
	for _, name := range selected {
		if err := visit(name); err != nil {
			return nil, err
		}
	}
	return order, nil
}

// FilterByHost removes modules whose `hosts` list excludes hostName.
// An empty `hosts` list means "any host".
func FilterByHost(mods []*module.Module, hostName string) []*module.Module {
	var kept []*module.Module
	for _, m := range mods {
		if len(m.Hosts) == 0 {
			kept = append(kept, m)
			continue
		}
		for _, h := range m.Hosts {
			if h == hostName {
				kept = append(kept, m)
				break
			}
		}
	}
	return kept
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/runner/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/runner/
git commit -m "runner: dependency resolution and host filtering"
```

---

### Task 13: Runner — build Actions from a Module

**Files:**
- Modify: `internal/runner/runner.go`
- Modify: `internal/runner/runner_test.go`

- [ ] **Step 1: Write a test for action construction**

Append to `internal/runner/runner_test.go`:
```go
import (
	"os"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/action"
)

func TestBuildActions_filtersByHostAndExpandsSymlinks(t *testing.T) {
	dir := t.TempDir()
	os.MkdirAll(filepath.Join(dir, "files"), 0o755)
	os.WriteFile(filepath.Join(dir, "files", "a.conf"), []byte("x"), 0o644)

	m := &module.Module{
		Dir: dir,
		Module: &manifest.Module{
			Name: "ex",
			Symlinks: []manifest.Symlink{
				{Src: "files/a.conf", Dst: "/tmp/a"},                       // always
				{Src: "files/a.conf", Dst: "/tmp/d", Hosts: []string{"desktop"}},
			},
		},
	}
	host := &manifest.Host{Name: "laptop"}
	acts, err := BuildActions(m, host)
	if err != nil {
		t.Fatal(err)
	}
	// only the host-agnostic symlink survives on laptop
	if len(acts) != 1 {
		t.Fatalf("got %d actions, want 1", len(acts))
	}
	if _, ok := acts[0].(*action.Symlink); !ok {
		t.Errorf("got %T, want *action.Symlink", acts[0])
	}
}
```

- [ ] **Step 2: Run test**

Run: `go test ./internal/runner/...`
Expected: FAIL.

- [ ] **Step 3: Implement BuildActions**

Append to `internal/runner/runner.go`:
```go
import (
	"os"
	"path/filepath"
	"strings"

	"github.com/DaltonDayton/dotfiles/internal/action"
	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/template"
)

func hostMatch(hosts []string, hostName string) bool {
	if len(hosts) == 0 {
		return true
	}
	for _, h := range hosts {
		if h == hostName {
			return true
		}
	}
	return false
}

func expandHome(p string) string {
	if strings.HasPrefix(p, "~/") {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, p[2:])
	}
	return p
}

// BuildActions constructs Action values for every declarative entry in m
// that applies to host, returning them in the intended execution order:
// directories → packages → symlinks → files → commands → services.
func BuildActions(m *module.Module, host *manifest.Host) ([]action.Action, error) {
	var acts []action.Action

	for _, d := range m.Directories {
		if !hostMatch(d.Hosts, host.Name) {
			continue
		}
		acts = append(acts, &action.Directory{Path: expandHome(d.Path), Mode: d.Mode})
	}
	for _, p := range m.Packages {
		if !hostMatch(p.Hosts, host.Name) {
			continue
		}
		acts = append(acts, &action.Packages{Manager: p.Manager, Names: p.Names})
	}
	for _, s := range m.Symlinks {
		if !hostMatch(s.Hosts, host.Name) {
			continue
		}
		src := filepath.Join(m.Dir, s.Src)
		dst := expandHome(s.Dst)
		if strings.HasSuffix(s.Src, ".tmpl") {
			// render to a sibling file (stripped suffix), then symlink that
			raw, err := os.ReadFile(src)
			if err != nil {
				return nil, err
			}
			rendered, err := template.Render(string(raw), host)
			if err != nil {
				return nil, err
			}
			renderedPath := strings.TrimSuffix(src, ".tmpl")
			if err := os.WriteFile(renderedPath, []byte(rendered), 0o644); err != nil {
				return nil, err
			}
			src = renderedPath
		}
		acts = append(acts, &action.Symlink{Src: src, Dst: dst, ConflictPolicy: action.ConflictBackup})
	}
	for _, f := range m.Files {
		if !hostMatch(f.Hosts, host.Name) {
			continue
		}
		content := f.Content
		if f.ContentFrom != "" {
			data, err := os.ReadFile(filepath.Join(m.Dir, f.ContentFrom))
			if err != nil {
				return nil, err
			}
			content = string(data)
		}
		acts = append(acts, &action.File{Dst: expandHome(f.Dst), Content: content, Mode: f.Mode})
	}
	for _, c := range m.Commands {
		if !hostMatch(c.Hosts, host.Name) {
			continue
		}
		acts = append(acts, &action.Command{Run: c.Run, CheckCmd: c.Check})
	}
	for _, s := range m.Services {
		if !hostMatch(s.Hosts, host.Name) {
			continue
		}
		acts = append(acts, &action.Service{Name: s.Name, Scope: s.Scope, State: s.State})
	}
	return acts, nil
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/runner/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/runner/
git commit -m "runner: build actions from a Module, honoring host filters and templates"
```

---

### Task 14: Runner — Apply loop with status reporting

**Files:**
- Modify: `internal/runner/runner.go`
- Create: `internal/runner/apply_test.go`

- [ ] **Step 1: Define the progress channel shape**

The TUI (Task 18) subscribes to updates. The runner is TUI-agnostic — it publishes events on a channel.

- [ ] **Step 2: Write a test**

Create `internal/runner/apply_test.go`:
```go
package runner

import (
	"errors"
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/action"
)

type fakeAction struct {
	desc    string
	checked bool
	applied bool
	err     error
}

func (f *fakeAction) Describe() string       { return f.desc }
func (f *fakeAction) Check() (bool, error)   { return f.checked, nil }
func (f *fakeAction) Apply() error           { f.applied = true; return f.err }

func TestApplyActions_skipsAlreadyApplied(t *testing.T) {
	a := &fakeAction{desc: "a", checked: true}
	b := &fakeAction{desc: "b", checked: false}
	events := make(chan Event, 16)
	results := ApplyActions([]action.Action{a, b}, events)
	close(events)

	if a.applied {
		t.Error("a should have been skipped")
	}
	if !b.applied {
		t.Error("b should have been applied")
	}
	if results[0].Status != action.StatusSkipped {
		t.Errorf("results[0] = %+v", results[0])
	}
	if results[1].Status != action.StatusApplied {
		t.Errorf("results[1] = %+v", results[1])
	}
}

func TestApplyActions_reportsFailure(t *testing.T) {
	a := &fakeAction{desc: "a", err: errors.New("nope")}
	events := make(chan Event, 8)
	results := ApplyActions([]action.Action{a}, events)
	close(events)
	if results[0].Status != action.StatusFailed {
		t.Errorf("got %+v", results[0])
	}
}
```

- [ ] **Step 3: Run test**

Run: `go test ./internal/runner/...`
Expected: FAIL.

- [ ] **Step 4: Implement ApplyActions + events**

Append to `internal/runner/runner.go`:
```go
type EventKind string

const (
	EventStart   EventKind = "start"
	EventDone    EventKind = "done"
	EventSkipped EventKind = "skipped"
	EventError   EventKind = "error"
)

type Event struct {
	Kind    EventKind
	Module  string
	Action  string
	Err     error
}

type Result struct {
	Action string
	Status action.Status
	Err    error
}

// ApplyActions runs Check+Apply for each action in order. It publishes Events
// to the channel (non-blocking: caller must drain or provide a buffered chan).
func ApplyActions(acts []action.Action, events chan<- Event) []Result {
	out := make([]Result, 0, len(acts))
	for _, a := range acts {
		send(events, Event{Kind: EventStart, Action: a.Describe()})
		ok, err := a.Check()
		if err != nil {
			out = append(out, Result{Action: a.Describe(), Status: action.StatusFailed, Err: err})
			send(events, Event{Kind: EventError, Action: a.Describe(), Err: err})
			continue
		}
		if ok {
			out = append(out, Result{Action: a.Describe(), Status: action.StatusSkipped})
			send(events, Event{Kind: EventSkipped, Action: a.Describe()})
			continue
		}
		if err := a.Apply(); err != nil {
			out = append(out, Result{Action: a.Describe(), Status: action.StatusFailed, Err: err})
			send(events, Event{Kind: EventError, Action: a.Describe(), Err: err})
			continue
		}
		out = append(out, Result{Action: a.Describe(), Status: action.StatusApplied})
		send(events, Event{Kind: EventDone, Action: a.Describe()})
	}
	return out
}

func send(ch chan<- Event, e Event) {
	if ch == nil {
		return
	}
	select {
	case ch <- e:
	default:
	}
}
```

- [ ] **Step 5: Run tests**

Run: `go test ./internal/runner/...`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/runner/
git commit -m "runner: ApplyActions loop with check+apply+events"
```

---

### Task 15: Runner — orchestrate install.sh escape hatch

**Files:**
- Modify: `internal/runner/runner.go`
- Create: `internal/runner/install_sh_test.go`

- [ ] **Step 1: Write a test**

Create `internal/runner/install_sh_test.go`:
```go
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
```

- [ ] **Step 2: Run test**

Run: `go test ./internal/runner/...`
Expected: FAIL.

- [ ] **Step 3: Implement**

Append to `internal/runner/runner.go`:
```go
import "os/exec"

// RunInstallSh runs <moduleDir>/install.sh if present. Expected exit code 0.
// The script is responsible for its own idempotency.
func RunInstallSh(m *module.Module) error {
	script := filepath.Join(m.Dir, "install.sh")
	if _, err := os.Stat(script); err != nil {
		return nil
	}
	cmd := exec.Command("sh", script)
	cmd.Dir = m.Dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("install.sh for %s failed: %w (output: %s)", m.Name, err, string(out))
	}
	return nil
}
```

- [ ] **Step 4: Run tests**

Run: `go test ./internal/runner/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/runner/
git commit -m "runner: run install.sh escape hatch per module"
```

---

## Phase 4 — CLI commands

### Task 16: Cobra CLI skeleton + `list` + `status`

**Files:**
- Modify: `cmd/quill/main.go`
- Create: `cmd/quill/list.go`
- Create: `cmd/quill/status.go`
- Create: `cmd/quill/context.go`

- [ ] **Step 1: Add cobra dependency**

Run:
```bash
go get github.com/spf13/cobra@latest
```

- [ ] **Step 2: Wire up the root command**

Replace `cmd/quill/main.go`:
```go
package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var (
	flagRepoRoot string
)

func main() {
	root := &cobra.Command{
		Use:   "quill",
		Short: "Manage dotfiles and machine setup declaratively",
	}
	root.PersistentFlags().StringVar(&flagRepoRoot, "repo", "", "path to the dotfiles repo (default: containing dir of binary, else ~/.dotfiles)")
	root.AddCommand(newListCmd(), newStatusCmd(), newApplyCmd(), newInstallCmd(), newPathCmd())
	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
```

- [ ] **Step 3: Shared context helper**

Create `cmd/quill/context.go`:
```go
package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/host"
	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

type appCtx struct {
	RepoRoot string
	Modules  []*module.Module
	Host     *manifest.Host
}

func loadCtx() (*appCtx, error) {
	root, err := resolveRepoRoot()
	if err != nil {
		return nil, err
	}
	mods, err := module.LoadAll(filepath.Join(root, "modules"))
	if err != nil {
		return nil, fmt.Errorf("load modules: %w", err)
	}
	hostname, err := host.Detect()
	if err != nil {
		return nil, err
	}
	h, err := host.Load(filepath.Join(root, "hosts"), hostname)
	if err != nil {
		return nil, err
	}
	return &appCtx{RepoRoot: root, Modules: mods, Host: h}, nil
}

func resolveRepoRoot() (string, error) {
	if flagRepoRoot != "" {
		return flagRepoRoot, nil
	}
	// binary location: .../<repo>/bin/quill → repo root is two dirs up
	exe, err := os.Executable()
	if err == nil {
		candidate := filepath.Dir(filepath.Dir(exe))
		if _, err := os.Stat(filepath.Join(candidate, "modules")); err == nil {
			return candidate, nil
		}
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".dotfiles"), nil
}
```

- [ ] **Step 4: Implement `list`**

Create `cmd/quill/list.go`:
```go
package main

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List all discovered modules",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, err := loadCtx()
			if err != nil {
				return err
			}
			for _, m := range ctx.Modules {
				fmt.Printf("%-20s %s\n", m.Name, m.Description)
			}
			return nil
		},
	}
}
```

- [ ] **Step 5: Implement `status`**

Create `cmd/quill/status.go`:
```go
package main

import (
	"fmt"

	"github.com/DaltonDayton/dotfiles/internal/runner"
	"github.com/spf13/cobra"
)

func newStatusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show applied / pending status for every module in this host's profile",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, err := loadCtx()
			if err != nil {
				return err
			}
			ordered, err := runner.ResolveDeps(ctx.Modules, ctx.Host.Modules)
			if err != nil {
				return err
			}
			ordered = runner.FilterByHost(ordered, ctx.Host.Name)
			for _, m := range ordered {
				acts, err := runner.BuildActions(m, ctx.Host)
				if err != nil {
					fmt.Printf("%-20s ERROR: %v\n", m.Name, err)
					continue
				}
				var pending, total int
				for _, a := range acts {
					total++
					ok, err := a.Check()
					if err != nil || !ok {
						pending++
					}
				}
				marker := "OK"
				if pending > 0 {
					marker = fmt.Sprintf("PENDING (%d/%d)", pending, total)
				}
				fmt.Printf("%-20s %s\n", m.Name, marker)
			}
			return nil
		},
	}
}
```

- [ ] **Step 6: Add placeholder install/apply/path commands**

Create stubs returning `fmt.Errorf("not yet implemented")` to satisfy the compiler. They'll be fleshed out in Tasks 19–20.

In a new file `cmd/quill/stubs.go`:
```go
package main

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newInstallCmd() *cobra.Command {
	return &cobra.Command{Use: "install", Short: "interactive installer (TBD)", RunE: func(_ *cobra.Command, _ []string) error {
		return fmt.Errorf("install: not yet implemented (see Task 19)")
	}}
}

func newApplyCmd() *cobra.Command {
	return &cobra.Command{Use: "apply [modules...]", Short: "non-interactive apply (TBD)", RunE: func(_ *cobra.Command, _ []string) error {
		return fmt.Errorf("apply: not yet implemented (see Task 20)")
	}}
}

func newPathCmd() *cobra.Command {
	return &cobra.Command{Use: "path", Short: "install binary to ~/.local/bin (TBD)", RunE: func(_ *cobra.Command, _ []string) error {
		return fmt.Errorf("path: not yet implemented (see Task 21)")
	}}
}
```

- [ ] **Step 7: Build and sanity-check**

Run:
```bash
go build -o ./bin/quill ./cmd/quill
./bin/quill --help
./bin/quill list   # expect: no modules yet, clean exit when no hosts/ either — OK to get "host profile not found" here
```

If `list` errors on host lookup, that's fine — we don't have hosts/ yet. Alternative: temporarily create `hosts/$(hostname).toml` with `name = "$(hostname)"` for manual smoke.

- [ ] **Step 8: Commit**

```bash
git add go.mod go.sum cmd/quill/
git commit -m "cmd: cobra skeleton with list and status; stubs for install/apply/path"
```

---

## Phase 5 — TUI

### Task 17: Lip Gloss styles and banner

**Files:**
- Create: `internal/tui/styles.go`
- Create: `internal/tui/banner.go`

- [ ] **Step 1: Add Charm deps**

Run:
```bash
go get github.com/charmbracelet/lipgloss
go get github.com/charmbracelet/bubbletea
go get github.com/charmbracelet/huh
```

- [ ] **Step 2: Create styles**

Create `internal/tui/styles.go`:
```go
package tui

import "github.com/charmbracelet/lipgloss"

var (
	Title = lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("#7AA2F7"))
	Subtle = lipgloss.NewStyle().
		Foreground(lipgloss.Color("#565F89"))
	Success = lipgloss.NewStyle().Foreground(lipgloss.Color("#9ECE6A"))
	Warn    = lipgloss.NewStyle().Foreground(lipgloss.Color("#E0AF68"))
	Error   = lipgloss.NewStyle().Foreground(lipgloss.Color("#F7768E"))
)
```

- [ ] **Step 3: Banner**

Create `internal/tui/banner.go`:
```go
package tui

import "fmt"

func Banner(hostName, profilePath string) string {
	title := Title.Render("quill")
	line := fmt.Sprintf("%s  %s %s", title, Subtle.Render("detected host:"), Success.Render(hostName))
	return line + "\n" + Subtle.Render("using profile: "+profilePath)
}
```

- [ ] **Step 4: Verify compiles**

Run: `go build ./...`
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add go.mod go.sum internal/tui/
git commit -m "tui: lipgloss styles and host-detection banner"
```

---

### Task 18: Huh module selector (grouped by tag)

**Files:**
- Create: `internal/tui/selector.go`
- Create: `internal/tui/selector_test.go`

- [ ] **Step 1: Write a test for the pure grouping logic**

The `huh.Form` call is hard to unit-test directly (it renders a TUI). Extract a pure helper.

Create `internal/tui/selector_test.go`:
```go
package tui

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

func mkMod(name string, tags ...string) *module.Module {
	return &module.Module{Module: &manifest.Module{Name: name, Tags: tags}}
}

func TestGroupByTag(t *testing.T) {
	mods := []*module.Module{
		mkMod("git", "essential"),
		mkMod("zsh", "essential"),
		mkMod("neovim", "dev"),
		mkMod("misc"), // no tags → "uncategorized"
	}
	groups := GroupByTag(mods)
	if len(groups["essential"]) != 2 {
		t.Errorf("essential has %d", len(groups["essential"]))
	}
	if len(groups["dev"]) != 1 {
		t.Errorf("dev has %d", len(groups["dev"]))
	}
	if len(groups["uncategorized"]) != 1 {
		t.Errorf("uncategorized has %d", len(groups["uncategorized"]))
	}
}
```

- [ ] **Step 2: Implement**

Create `internal/tui/selector.go`:
```go
package tui

import (
	"fmt"
	"sort"

	"github.com/charmbracelet/huh"
	"github.com/DaltonDayton/dotfiles/internal/module"
)

// GroupByTag buckets modules by their first tag ("uncategorized" if none).
func GroupByTag(mods []*module.Module) map[string][]*module.Module {
	out := map[string][]*module.Module{}
	for _, m := range mods {
		tag := "uncategorized"
		if len(m.Tags) > 0 {
			tag = m.Tags[0]
		}
		out[tag] = append(out[tag], m)
	}
	return out
}

// SelectModules renders a multi-select grouped by tag.
// `preselected` names are checked by default.
// Returns the names chosen by the user, in no particular order.
func SelectModules(mods []*module.Module, preselected map[string]bool) ([]string, error) {
	groups := GroupByTag(mods)
	tags := make([]string, 0, len(groups))
	for t := range groups {
		tags = append(tags, t)
	}
	sort.Strings(tags)

	var chosen []string
	fields := []huh.Field{}
	for _, tag := range tags {
		tag := tag
		items := groups[tag]
		sort.Slice(items, func(i, j int) bool { return items[i].Name < items[j].Name })
		var options []huh.Option[string]
		var defaults []string
		for _, m := range items {
			label := m.Name
			if m.Description != "" {
				label = fmt.Sprintf("%s — %s", m.Name, m.Description)
			}
			options = append(options, huh.NewOption(label, m.Name))
			if preselected[m.Name] {
				defaults = append(defaults, m.Name)
			}
		}
		field := huh.NewMultiSelect[string]().
			Title(Title.Render(tag)).
			Options(options...).
			Value(&chosen).
			Filtering(true)
		if len(defaults) > 0 {
			// huh's MultiSelect defaults come from the pointer's current value,
			// so pre-seed chosen.
			chosen = append(chosen, defaults...)
		}
		_ = field // keep the field name; see form below
		fields = append(fields, field)
	}
	form := huh.NewForm(huh.NewGroup(fields...))
	if err := form.Run(); err != nil {
		return nil, err
	}
	return unique(chosen), nil
}

func unique(xs []string) []string {
	seen := map[string]bool{}
	out := xs[:0]
	for _, x := range xs {
		if !seen[x] {
			seen[x] = true
			out = append(out, x)
		}
	}
	return out
}
```

- [ ] **Step 3: Run tests**

Run: `go test ./internal/tui/...`
Expected: PASS (only `GroupByTag` is tested; `SelectModules` requires a TTY).

- [ ] **Step 4: Commit**

```bash
git add internal/tui/selector.go internal/tui/selector_test.go
git commit -m "tui: huh-based multi-select grouped by tag"
```

---

### Task 19: Bubble Tea progress view + `install` command

**Files:**
- Create: `internal/tui/progress.go`
- Modify: `cmd/quill/stubs.go` → delete; replace the install stub
- Create: `cmd/quill/install.go`

- [ ] **Step 1: Implement the progress model**

Create `internal/tui/progress.go`:
```go
package tui

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/DaltonDayton/dotfiles/internal/runner"
)

type moduleLine struct {
	name    string
	actions []string // describe strings observed so far
	status  string   // "pending" | "running" | "done" | "failed" | "skipped"
	err     error
}

type Model struct {
	order   []string            // module names in execution order
	byName  map[string]*moduleLine
	events  <-chan runner.Event
	done    bool
}

type eventMsg runner.Event
type doneMsg struct{}

func NewProgress(order []string, events <-chan runner.Event) *Model {
	m := &Model{
		order:  order,
		byName: map[string]*moduleLine{},
		events: events,
	}
	for _, n := range order {
		m.byName[n] = &moduleLine{name: n, status: "pending"}
	}
	return m
}

func (m *Model) Init() tea.Cmd { return waitEvent(m.events) }

func waitEvent(ch <-chan runner.Event) tea.Cmd {
	return func() tea.Msg {
		e, ok := <-ch
		if !ok {
			return doneMsg{}
		}
		return eventMsg(e)
	}
}

func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case eventMsg:
		line := m.byName[msg.Module]
		if line == nil {
			// events without an associated module (e.g., install.sh) — skip
			return m, waitEvent(m.events)
		}
		switch msg.Kind {
		case runner.EventStart:
			line.status = "running"
			line.actions = append(line.actions, msg.Action)
		case runner.EventDone:
			line.status = "done"
		case runner.EventSkipped:
			line.status = "skipped"
		case runner.EventError:
			line.status = "failed"
			line.err = msg.Err
		}
		return m, waitEvent(m.events)
	case doneMsg:
		m.done = true
		return m, tea.Quit
	}
	return m, nil
}

func (m *Model) View() string {
	var b strings.Builder
	for _, name := range m.order {
		l := m.byName[name]
		icon := "⏸"
		switch l.status {
		case "running":
			icon = "⏳"
		case "done":
			icon = Success.Render("✓")
		case "skipped":
			icon = Subtle.Render("⏭")
		case "failed":
			icon = Error.Render("✗")
		}
		fmt.Fprintf(&b, "%s %-20s %s\n", icon, l.name, Subtle.Render(strings.Join(l.actions, " · ")))
		if l.err != nil {
			fmt.Fprintf(&b, "   %s\n", Error.Render(l.err.Error()))
		}
	}
	return b.String()
}
```

- [ ] **Step 2: Wire up `install` command**

Create `cmd/quill/install.go` (and delete the install stub from `stubs.go`):
```go
package main

import (
	"fmt"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/DaltonDayton/dotfiles/internal/action"
	"github.com/DaltonDayton/dotfiles/internal/runner"
	"github.com/DaltonDayton/dotfiles/internal/state"
	"github.com/DaltonDayton/dotfiles/internal/tui"
	"github.com/spf13/cobra"
)

func newInstallCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "install",
		Short: "Interactive installer",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, err := loadCtx()
			if err != nil {
				return err
			}

			// Banner
			profilePath := filepath.Join(ctx.RepoRoot, "hosts", ctx.Host.Name+".toml")
			fmt.Println(tui.Banner(ctx.Host.Name, profilePath))

			// Default selection: last saved → fall back to host manifest
			statePath, _ := state.DefaultPath()
			preselectedNames, _ := state.LoadSelection(statePath)
			if len(preselectedNames) == 0 {
				preselectedNames = ctx.Host.Modules
			}
			preselected := map[string]bool{}
			for _, n := range preselectedNames {
				preselected[n] = true
			}

			selected, err := tui.SelectModules(ctx.Modules, preselected)
			if err != nil {
				return err
			}
			if len(selected) == 0 {
				fmt.Println("Nothing selected.")
				return nil
			}

			// Resolve deps + filter by host
			ordered, err := runner.ResolveDeps(ctx.Modules, selected)
			if err != nil {
				return err
			}
			ordered = runner.FilterByHost(ordered, ctx.Host.Name)

			// Build action plan and launch progress view concurrently
			events := make(chan runner.Event, 64)
			names := make([]string, 0, len(ordered))
			for _, m := range ordered {
				names = append(names, m.Name)
			}
			prog := tea.NewProgram(tui.NewProgress(names, events))

			go func() {
				defer close(events)
				for _, m := range ordered {
					acts, err := runner.BuildActions(m, ctx.Host)
					if err != nil {
						events <- runner.Event{Kind: runner.EventError, Module: m.Name, Err: err}
						continue
					}
					wrapped := wrapForModule(m.Name, acts, events)
					runner.ApplyActions(wrapped, events)
					if err := runner.RunInstallSh(m); err != nil {
						events <- runner.Event{Kind: runner.EventError, Module: m.Name, Err: err}
					}
				}
			}()

			if _, err := prog.Run(); err != nil {
				return err
			}

			// Persist last selection
			_ = state.SaveSelection(statePath, selected)
			return nil
		},
	}
}

// wrapForModule tags each action's events with the owning module so the TUI
// can group lines by module.
func wrapForModule(name string, acts []action.Action, events chan<- runner.Event) []action.Action {
	out := make([]action.Action, len(acts))
	for i, a := range acts {
		out[i] = &taggedAction{Action: a, module: name, events: events}
	}
	return out
}

type taggedAction struct {
	action.Action
	module string
	events chan<- runner.Event
}

func (t *taggedAction) Apply() error {
	err := t.Action.Apply()
	// events are already emitted by ApplyActions — this wrapper exists so the
	// Module field can be filled in via a shim if we ever need per-action module
	// attribution. For now the goroutine in install.go sets Module on each event.
	return err
}
```

Note: the simpler approach — and the one we'll ship — is for `ApplyActions` to accept a `module` string parameter and set it on emitted events, instead of wrapping actions. Refactor:

- [ ] **Step 3: Refactor `ApplyActions` to accept moduleName**

Edit `internal/runner/runner.go` — change signature:
```go
func ApplyActions(moduleName string, acts []action.Action, events chan<- Event) []Result {
    // ... same body, but every `Event{...}` literal sets Module: moduleName.
```

Update the test (`internal/runner/apply_test.go`) to pass `""` as the first arg.

Update `cmd/quill/install.go`: drop `wrapForModule` / `taggedAction` and call `runner.ApplyActions(m.Name, acts, events)` directly.

- [ ] **Step 4: Run all tests**

Run: `go test ./...`
Expected: PASS.

- [ ] **Step 5: Remove obsolete stub**

In `cmd/quill/stubs.go`, delete `newInstallCmd`. Leave `newApplyCmd` and `newPathCmd` stubs (Tasks 20, 21).

- [ ] **Step 6: Commit**

```bash
git add internal/tui/progress.go internal/runner/runner.go internal/runner/apply_test.go cmd/quill/install.go cmd/quill/stubs.go
git commit -m "tui: bubbletea progress view and install command"
```

---

### Task 20: Non-interactive `apply` + confirm step for `install`

**Files:**
- Create: `cmd/quill/apply.go`
- Modify: `cmd/quill/install.go` (add huh.Confirm step)
- Modify: `cmd/quill/stubs.go` (remove `newApplyCmd`)

- [ ] **Step 1: Implement apply**

Create `cmd/quill/apply.go`:
```go
package main

import (
	"fmt"

	"github.com/DaltonDayton/dotfiles/internal/runner"
	"github.com/spf13/cobra"
)

func newApplyCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "apply [modules...]",
		Short: "Apply host profile (or listed modules) without prompts",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, err := loadCtx()
			if err != nil {
				return err
			}
			names := args
			if len(names) == 0 {
				names = ctx.Host.Modules
			}
			ordered, err := runner.ResolveDeps(ctx.Modules, names)
			if err != nil {
				return err
			}
			ordered = runner.FilterByHost(ordered, ctx.Host.Name)

			events := make(chan runner.Event, 64)
			go func() {
				defer close(events)
				for _, m := range ordered {
					acts, err := runner.BuildActions(m, ctx.Host)
					if err != nil {
						events <- runner.Event{Kind: runner.EventError, Module: m.Name, Err: err}
						continue
					}
					runner.ApplyActions(m.Name, acts, events)
					if err := runner.RunInstallSh(m); err != nil {
						events <- runner.Event{Kind: runner.EventError, Module: m.Name, Err: err}
					}
				}
			}()
			// Drain events to stdout (no TUI)
			applied, skipped, failed := 0, 0, 0
			for e := range events {
				switch e.Kind {
				case runner.EventDone:
					applied++
					fmt.Printf("  ✓ %s: %s\n", e.Module, e.Action)
				case runner.EventSkipped:
					skipped++
				case runner.EventError:
					failed++
					fmt.Printf("  ✗ %s: %s (%v)\n", e.Module, e.Action, e.Err)
				}
			}
			fmt.Printf("\nApplied: %d  Skipped: %d  Failed: %d\n", applied, skipped, failed)
			if failed > 0 {
				return fmt.Errorf("%d actions failed", failed)
			}
			return nil
		},
	}
}
```

- [ ] **Step 2: Add confirm to `install`**

In `cmd/quill/install.go`, after dep resolution and before the progress view, insert:
```go
import "github.com/charmbracelet/huh"

// ...
var proceed bool
summary := fmt.Sprintf("Will apply %d modules on host %s. Proceed?", len(ordered), ctx.Host.Name)
if err := huh.NewConfirm().Title(summary).Value(&proceed).Run(); err != nil {
    return err
}
if !proceed {
    fmt.Println("Aborted.")
    return nil
}
```

- [ ] **Step 3: Remove `newApplyCmd` stub**

Delete `newApplyCmd` from `cmd/quill/stubs.go`.

- [ ] **Step 4: Build and run self-check**

Run:
```bash
go build -o ./bin/quill ./cmd/quill
./bin/quill --help
```
Expected: `install`, `apply`, `list`, `status` all appear.

- [ ] **Step 5: Commit**

```bash
git add cmd/quill/
git commit -m "cmd: non-interactive apply and confirm step in install"
```

---

### Task 21: `path` command (install binary to ~/.local/bin)

**Files:**
- Create: `cmd/quill/path.go`
- Create: `cmd/quill/path_test.go`
- Modify: `cmd/quill/stubs.go` (remove newPathCmd → delete file if empty)

- [ ] **Step 1: Extract the pure helper (for testing)**

Create `cmd/quill/path_helpers.go`:
```go
package main

import (
	"bufio"
	"bytes"
	"os"
	"strings"
)

const pathExport = `export PATH="$HOME/.local/bin:$PATH"`

// ensurePathLine appends pathExport to rcPath if no existing line already adds
// ~/.local/bin to PATH. Returns true if the file was modified.
func ensurePathLine(rcPath string) (bool, error) {
	data, err := os.ReadFile(rcPath)
	if os.IsNotExist(err) {
		data = nil
	} else if err != nil {
		return false, err
	}
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, ".local/bin") && strings.Contains(line, "PATH") && !strings.HasPrefix(strings.TrimSpace(line), "#") {
			return false, nil
		}
	}
	if len(data) > 0 && data[len(data)-1] != '\n' {
		data = append(data, '\n')
	}
	data = append(data, []byte("\n# Added by quill\n"+pathExport+"\n")...)
	return true, os.WriteFile(rcPath, data, 0o644)
}
```

- [ ] **Step 2: Test the helper**

Create `cmd/quill/path_test.go`:
```go
package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEnsurePathLine_appendsWhenMissing(t *testing.T) {
	rc := filepath.Join(t.TempDir(), ".zshrc")
	os.WriteFile(rc, []byte("# zshrc\nalias ls=eza\n"), 0o644)

	modified, err := ensurePathLine(rc)
	if err != nil {
		t.Fatal(err)
	}
	if !modified {
		t.Fatal("expected file to be modified")
	}
	out, _ := os.ReadFile(rc)
	if !strings.Contains(string(out), ".local/bin") {
		t.Errorf("expected .local/bin in output, got %q", out)
	}
}

func TestEnsurePathLine_skipsWhenPresent(t *testing.T) {
	rc := filepath.Join(t.TempDir(), ".zshrc")
	os.WriteFile(rc, []byte(`export PATH="$HOME/.local/bin:$PATH"`+"\n"), 0o644)

	modified, err := ensurePathLine(rc)
	if err != nil {
		t.Fatal(err)
	}
	if modified {
		t.Fatal("expected idempotent no-op when line already present")
	}
}

func TestEnsurePathLine_createsWhenMissing(t *testing.T) {
	rc := filepath.Join(t.TempDir(), ".zshrc") // does not exist
	modified, err := ensurePathLine(rc)
	if err != nil {
		t.Fatal(err)
	}
	if !modified {
		t.Fatal("expected modified=true for new file")
	}
	if _, err := os.Stat(rc); err != nil {
		t.Fatal(err)
	}
}
```

- [ ] **Step 3: Implement the command**

Create `cmd/quill/path.go`:
```go
package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
)

func newPathCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "path",
		Short: "Symlink quill to ~/.local/bin and ensure PATH in .zshrc",
		RunE: func(cmd *cobra.Command, args []string) error {
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			exe, err := os.Executable()
			if err != nil {
				return err
			}
			localBin := filepath.Join(home, ".local", "bin")
			if err := os.MkdirAll(localBin, 0o755); err != nil {
				return err
			}
			link := filepath.Join(localBin, "quill")
			_ = os.Remove(link) // overwrite any prior link
			if err := os.Symlink(exe, link); err != nil {
				return err
			}
			rc := filepath.Join(home, ".zshrc")
			modified, err := ensurePathLine(rc)
			if err != nil {
				return err
			}
			fmt.Printf("Symlinked %s → %s\n", link, exe)
			if modified {
				fmt.Println("Added ~/.local/bin to PATH in ~/.zshrc (open a new shell to pick it up)")
			} else {
				fmt.Println("~/.local/bin already on PATH in ~/.zshrc")
			}
			return nil
		},
	}
}
```

- [ ] **Step 4: Remove stub**

In `cmd/quill/stubs.go`, delete `newPathCmd`. If the file is now empty, delete it and remove the reference.

- [ ] **Step 5: Run tests**

Run: `go test ./...`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add cmd/quill/
git commit -m "cmd: path command installs binary to ~/.local/bin and patches .zshrc"
```

---

## Phase 6 — Bootstrap + smoke test

### Task 22: Bootstrap script

**Files:**
- Create: `bootstrap.sh`

- [ ] **Step 1: Write the script**

Create `bootstrap.sh`:
```sh
#!/usr/bin/env bash
# Fresh-install entry point for quill.
# Designed to be piped via: curl -fsSL <url>/bootstrap.sh | bash
set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/DaltonDayton/dotfiles.git}"
REPO_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

echo "==> Installing prerequisites (git, go, base-devel)"
sudo pacman -Sy --needed --noconfirm git go base-devel

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "==> Cloning $REPO_URL into $REPO_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
else
    echo "==> Updating existing clone at $REPO_DIR"
    git -C "$REPO_DIR" pull --ff-only
fi

echo "==> Building quill"
cd "$REPO_DIR"
go build -o ./bin/quill ./cmd/quill

echo "==> Launching interactive installer"
exec ./bin/quill install
```

- [ ] **Step 2: Make executable**

Run: `chmod +x bootstrap.sh`

- [ ] **Step 3: Commit**

```bash
git add bootstrap.sh
git commit -m "bootstrap: fresh-install shell entry point"
```

---

### Task 23: First real module + host profile (smoke test)

**Files:**
- Create: `modules/git/module.toml`
- Create: `modules/git/files/.gitconfig.tmpl`
- Create: `hosts/<your-hostname>.toml` (run `hostname` to find name)

- [ ] **Step 1: Determine current hostname**

Run: `hostname`
Note the output (e.g., `archdesktop`) — replace `<HOST>` below.

- [ ] **Step 2: Create the git module**

Create `modules/git/module.toml`:
```toml
name = "git"
description = "Git + global gitconfig"
tags = ["essential"]

[[packages]]
manager = "pacman"
names = ["git"]

[[symlinks]]
src = "files/.gitconfig.tmpl"
dst = "~/.gitconfig"
```

Create `modules/git/files/.gitconfig.tmpl`:
```
[user]
    name = Dalton Dayton
    email = {{ .Vars.git_email }}
[init]
    defaultBranch = main
[pull]
    rebase = true
```

- [ ] **Step 3: Create a host profile**

Create `hosts/<HOST>.toml`:
```toml
name = "<HOST>"
aur_helper = "paru"
modules = ["git"]

[vars]
git_email = "daltondayton1@gmail.com"
```

- [ ] **Step 4: Run status end-to-end**

Run:
```bash
./bin/quill status
```
Expected: one line, `git  PENDING (2/2)` (or `OK` if git was already installed and `.gitconfig` already exists with matching content).

- [ ] **Step 5: Run apply (non-interactive)**

Run:
```bash
./bin/quill apply git
```
Expected: packages action runs (or is skipped if `git` is installed), symlink action creates `~/.gitconfig` (or backs up existing). Re-run to confirm idempotency — second run should report everything skipped.

- [ ] **Step 6: Manually verify**

- `readlink ~/.gitconfig` points into `~/.dotfiles/modules/git/files/` (or the rendered `.gitconfig` next to the `.tmpl`)
- `git config --global user.email` returns `daltondayton1@gmail.com`

- [ ] **Step 7: Commit**

```bash
git add modules/ hosts/
git commit -m "modules: add git module and host profile; smoke-tested end-to-end"
```

---

### Task 24: Interactive smoke test

- [ ] **Step 1: Run the interactive installer**

Run: `./bin/quill install`

Walk through:
1. Banner shows correct hostname
2. Selector shows `essential` group with `git` checked
3. Confirm prompt appears
4. Progress view shows each action's status
5. After exit, `~/.local/state/quill/last_selection.json` exists and contains `["git"]`

- [ ] **Step 2: Re-run to verify preselection persistence**

Run: `./bin/quill install` again. `git` should be preselected.

- [ ] **Step 3: Run path**

Run: `./bin/quill path`

Verify `quill` is on PATH in a fresh shell: `zsh -i -c 'which quill'`.

- [ ] **Step 4: Commit nothing** (this is a verification-only task).

---

## Phase 7 — Polish (optional, add tasks as needed)

Potential follow-up tasks beyond the MVP, each its own mini-plan when the need arises:

- **`quill bootstrap`** subcommand that re-runs `bootstrap.sh`-equivalent steps for updating clones.
- **Secrets**: integrate `sops`/`age` for files with sensitive content.
- **Uninstall paths**: `quill remove <module>` that reverses symlinks/services/etc.
- **Flatpak verb in real module**: add first flatpak-backed module to exercise that driver in anger.
- **Dry-run flag**: `quill apply --dry-run` — runs Check() for every action, prints what would change, never calls Apply().
- **Additional hosts**: add a second host profile for the other machine (laptop or desktop, whichever was not the smoke-test host).

---

## Verification Summary

After Phase 6:

1. `go test ./...` — all green
2. `./bin/quill list` — prints `git  Git + global gitconfig`
3. `./bin/quill status` — reports per-module applied/pending
4. `./bin/quill apply git` — installs & symlinks; rerun reports fully skipped (idempotency)
5. `rm ~/.gitconfig && ./bin/quill apply git` — symlink is restored (drift repair)
6. `./bin/quill install` — interactive flow runs selector, confirm, progress, summary
7. `./bin/quill path && zsh -i -c 'which quill'` — prints the symlink path
8. A fresh Arch VM: `curl ...bootstrap.sh | bash` succeeds end-to-end
