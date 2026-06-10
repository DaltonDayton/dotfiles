# WSL/Ubuntu Foundation + Shell Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add WSL/Ubuntu 24.04 support to quill — OS detection, an `apt` package driver, manager→OS package gating, a general `os=[]` action gate, `$QUILL_OS` for install.sh, the `sh`→shebang fix, a `bootstrap.sh` ubuntu branch, a `Dalton` host, and the `shell` module made Ubuntu-ready.

**Architecture:** Additive only — the Arch path must behave identically. A single detected `os` value (`arch`|`ubuntu`) is computed once in `cmd/quill` and threaded into `BuildActions`/`BuildPlan`/`RunInstallSh`. Package blocks gate by their manager's OS; other actions gate by an optional `os=[]` field (empty = all OSes, so existing modules are untouched). Imperative per-distro work lives in `install.sh` behind `case "$QUILL_OS"`.

**Tech Stack:** Go 1.26, cobra, TOML (BurntSushi via `internal/manifest`), bash install.sh scripts. Tests are standard `go test` with the existing `pkgDrivers`/fake-swap pattern.

**Branch:** `wsl-foundation-shell` (off `startover`). Repo-local git identity is set (`Dalton Dayton` / `50755420+DaltonDayton@users.noreply.github.com`).

**Per-task hygiene:** run `gofmt -w .` and `go test ./...` before every commit. Arch behavior is protected by a regression test in Task 3 — keep it green.

---

## File structure

| File | Responsibility | Task |
|---|---|---|
| `internal/host/os.go` (new) | `DetectOS()` — parse `/etc/os-release` → `arch`/`ubuntu` | 1 |
| `internal/host/os_test.go` (new) | fixture-driven detection tests | 1 |
| `internal/action/packages.go` (modify) | register `apt`, add `aptDriver` | 2 |
| `internal/action/packages_test.go` (modify) | `aptDriver` Check/Apply tests | 2 |
| `internal/manifest/schema.go` (modify) | add `OS []string` to every action struct | 3 |
| `internal/manifest/parse_test.go` (modify) | parse the new `os` field | 3 |
| `internal/runner/build.go` (modify) | `osMatch`, `osAllowsManager`, `os` param | 3 |
| `internal/runner/build_test.go` (modify) | gating + Arch regression tests | 3 |
| `internal/runner/plan.go` (modify) | thread `os` into `BuildPlan` | 3 |
| `cmd/quill/context.go` (modify) | `appCtx.OS`, call `DetectOS()` | 3 |
| `cmd/quill/status.go` (modify) | pass `ctx.OS` to `BuildActions` | 3 |
| `cmd/quill/apply.go` / `install.go` (modify) | pass `ctx.OS` to `BuildPlan`/`RunInstallSh` | 3, 4 |
| `internal/runner/install_sh.go` (modify) | `$QUILL_OS`/`$QUILL_HOST` env + shebang invoke | 4 |
| `internal/runner/install_sh_test.go` (new) | env + invocation tests | 4 |
| `bootstrap.sh` (modify) | ubuntu prerequisite branch | 5 |
| `hosts/Dalton.toml` (new) | WSL host profile | 6 |
| `modules/shell/module.toml` (modify) | add `apt` packages block | 7 |
| `modules/shell/install.sh` (modify) | `$QUILL_OS` branch for non-apt tools | 7 |
| `modules/shell/files/.zshrc` (modify) | `command -v` guards on starship/atuin | 7 |
| `CLAUDE.md` (modify) | update scope/user-context lines | 8 |

---

## Task 1: OS detection

**Files:**
- Create: `internal/host/os.go`
- Test: `internal/host/os_test.go`

- [ ] **Step 1: Write the failing test**

```go
package host

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDetectOSFromFile(t *testing.T) {
	cases := []struct {
		name    string
		content string
		want    string
	}{
		{"arch", "NAME=\"Arch Linux\"\nID=arch\n", "arch"},
		{"ubuntu", "NAME=\"Ubuntu\"\nID=ubuntu\nVERSION_ID=\"24.04\"\n", "ubuntu"},
		{"ubuntu derivative via ID_LIKE", "ID=pop\nID_LIKE=ubuntu debian\n", "ubuntu"},
		{"debian via ID_LIKE only", "ID=somedeb\nID_LIKE=debian\n", "ubuntu"},
		{"quoted id", "ID=\"ubuntu\"\n", "ubuntu"},
		{"unknown returns raw id", "ID=void\n", "void"},
		{"empty returns unknown", "", "unknown"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := filepath.Join(t.TempDir(), "os-release")
			if err := os.WriteFile(p, []byte(c.content), 0o644); err != nil {
				t.Fatal(err)
			}
			if got := detectOSFromFile(p); got != c.want {
				t.Fatalf("detectOSFromFile = %q, want %q", got, c.want)
			}
		})
	}
}

func TestDetectOSMissingFile(t *testing.T) {
	if got := detectOSFromFile(filepath.Join(t.TempDir(), "nope")); got != "unknown" {
		t.Fatalf("missing file = %q, want unknown", got)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/host/ -run TestDetectOS -v`
Expected: FAIL — `undefined: detectOSFromFile`.

- [ ] **Step 3: Write minimal implementation**

Create `internal/host/os.go`:

```go
package host

import (
	"bufio"
	"os"
	"strings"
)

// DetectOS returns a normalized OS id for the current machine: "arch",
// "ubuntu", or the raw /etc/os-release ID for anything else ("unknown" if
// the file is missing/empty). Detection is runtime-only — host profiles
// declare nothing about the OS, mirroring how the package manager is already
// abstracted per-action.
func DetectOS() string {
	return detectOSFromFile("/etc/os-release")
}

// detectOSFromFile is the testable core. ID wins; if ID is not one we
// recognize, ID_LIKE is consulted so close relatives (e.g. Pop!_OS reporting
// ID_LIKE="ubuntu debian") still resolve to "ubuntu".
func detectOSFromFile(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return "unknown"
	}
	defer f.Close()

	var id, idLike string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		switch {
		case strings.HasPrefix(line, "ID="):
			id = unquote(strings.TrimPrefix(line, "ID="))
		case strings.HasPrefix(line, "ID_LIKE="):
			idLike = unquote(strings.TrimPrefix(line, "ID_LIKE="))
		}
	}

	switch id {
	case "arch", "ubuntu":
		return id
	}
	for _, like := range strings.Fields(idLike) {
		if like == "ubuntu" || like == "debian" {
			return "ubuntu"
		}
		if like == "arch" {
			return "arch"
		}
	}
	if id == "" {
		return "unknown"
	}
	return id
}

func unquote(s string) string {
	return strings.Trim(strings.TrimSpace(s), `"`)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/host/ -v`
Expected: PASS (all cases).

- [ ] **Step 5: Commit**

```bash
gofmt -w internal/host/
go test ./...
git add internal/host/os.go internal/host/os_test.go
git commit -m "host: detect OS from /etc/os-release"
```

---

## Task 2: apt package driver

**Files:**
- Modify: `internal/action/packages.go`
- Test: `internal/action/packages_test.go`

- [ ] **Step 1: Write the failing test**

Append to `internal/action/packages_test.go` (it already exercises `pkgDrivers` swapping — reuse that style; if a fake driver type already exists in that file, do not redeclare it):

```go
func TestAptDriverRegistered(t *testing.T) {
	if _, ok := pkgDrivers["apt"]; !ok {
		t.Fatal(`pkgDrivers missing "apt"`)
	}
}

func TestPackagesNeedsSudoApt(t *testing.T) {
	p := &Packages{Manager: "apt", Names: []string{"zsh"}}
	if !p.NeedsSudo() {
		t.Fatal("apt Packages should need sudo")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/action/ -run 'TestAptDriverRegistered|TestPackagesNeedsSudoApt' -v`
Expected: FAIL — `pkgDrivers missing "apt"` and the NeedsSudo assertion fails (apt not yet in the `NeedsSudo` switch).

- [ ] **Step 3: Write minimal implementation**

In `internal/action/packages.go`:

1. Add `"apt": &aptDriver{},` to the `pkgDrivers` map literal.
2. Add `apt` to the `NeedsSudo` switch:

```go
func (p *Packages) NeedsSudo() bool {
	switch p.Manager {
	case "pacman", "yay", "apt":
		return true
	}
	return false
}
```

3. Add the driver near the other drivers:

```go
type aptDriver struct{}

func (aptDriver) IsInstalled(name string) (bool, error) {
	// dpkg -s exits 0 for an installed package, non-zero otherwise.
	err := exec.Command("dpkg", "-s", name).Run()
	if err == nil {
		return true, nil
	}
	if _, ok := err.(*exec.ExitError); ok {
		return false, nil
	}
	return false, err
}

func (aptDriver) Install(names []string) error {
	args := append([]string{"apt-get", "install", "-y"}, names...)
	return runSudo(args...)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/action/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
gofmt -w internal/action/
go test ./...
git add internal/action/packages.go internal/action/packages_test.go
git commit -m "action: add apt package driver"
```

---

## Task 3: OS gating in BuildActions (schema, mapping, threading)

This task changes `BuildActions`'s signature, so every caller is updated in the
same commit to keep the build green.

**Files:**
- Modify: `internal/manifest/schema.go`
- Modify: `internal/manifest/parse_test.go`
- Modify: `internal/runner/build.go`
- Modify: `internal/runner/build_test.go`
- Modify: `internal/runner/plan.go`
- Modify: `cmd/quill/context.go`
- Modify: `cmd/quill/status.go`
- Modify: `cmd/quill/apply.go`, `cmd/quill/install.go` (BuildPlan call only)

- [ ] **Step 1: Write the failing tests (runner)**

Append to `internal/runner/build_test.go`. Construct modules with the file's
existing nested pattern — `module.Module` embeds `*manifest.Module`, so the
declarative fields go inside `Module: &manifest.Module{...}` (Name/Packages/
Commands are NOT settable at the top level). Use the action types' exported
fields to assert what got built.

```go
func TestBuildActions_PackageManagerGatedByOS(t *testing.T) {
	m := &module.Module{
		Dir: t.TempDir(),
		Module: &manifest.Module{
			Name: "x",
			Packages: []manifest.Packages{
				{Manager: "pacman", Names: []string{"fd"}},
				{Manager: "apt", Names: []string{"fd-find"}},
			},
		},
	}
	host := &manifest.Host{Name: "h"}

	arch, err := BuildActions(m, host, "arch")
	if err != nil {
		t.Fatal(err)
	}
	if got := pkgManagers(arch); len(got) != 1 || got[0] != "pacman" {
		t.Fatalf("arch managers = %v, want [pacman]", got)
	}

	ubuntu, err := BuildActions(m, host, "ubuntu")
	if err != nil {
		t.Fatal(err)
	}
	if got := pkgManagers(ubuntu); len(got) != 1 || got[0] != "apt" {
		t.Fatalf("ubuntu managers = %v, want [apt]", got)
	}
}

func TestBuildActions_OSGateOnNonPackageActions(t *testing.T) {
	m := &module.Module{
		Dir: t.TempDir(),
		Module: &manifest.Module{
			Name: "x",
			Commands: []manifest.Command{
				{Run: "echo arch", OS: []string{"arch"}},
				{Run: "echo ubuntu", OS: []string{"ubuntu"}},
				{Run: "echo both"},
			},
		},
	}
	host := &manifest.Host{Name: "h"}

	got, err := BuildActions(m, host, "ubuntu")
	if err != nil {
		t.Fatal(err)
	}
	var runs []string
	for _, a := range got {
		if c, ok := a.(*action.Command); ok {
			runs = append(runs, c.Run)
		}
	}
	want := []string{"echo ubuntu", "echo both"}
	if len(runs) != len(want) || runs[0] != want[0] || runs[1] != want[1] {
		t.Fatalf("commands = %v, want %v", runs, want)
	}
}

// Regression: an Arch-only module (no os fields, only pacman) must produce the
// exact same actions on os="arch" as before OS gating existed.
func TestBuildActions_ArchRegression(t *testing.T) {
	m := &module.Module{
		Dir: t.TempDir(),
		Module: &manifest.Module{
			Name:     "x",
			Packages: []manifest.Packages{{Manager: "pacman", Names: []string{"git"}}},
			Commands: []manifest.Command{{Run: "echo hi"}},
		},
	}
	got, err := BuildActions(m, &manifest.Host{Name: "h"}, "arch")
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 {
		t.Fatalf("want 2 actions, got %d", len(got))
	}
}

// pkgManagers extracts the Manager of every Packages action, in order.
func pkgManagers(acts []action.Action) []string {
	var out []string
	for _, a := range acts {
		if p, ok := a.(*action.Packages); ok {
			out = append(out, p.Manager)
		}
	}
	return out
}
```

Ensure the test file imports `action`, `manifest`, and `module` (add to the import block if missing).

- [ ] **Step 2: Write the failing test (manifest parse)**

Append to `internal/manifest/parse_test.go` a case asserting the `os` field decodes. Match the file's existing style (it likely parses a TOML string into `Module`). Minimal standalone test:

```go
func TestParseModule_OSField(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "module.toml")
	if err := os.WriteFile(p, []byte(`
name = "x"
[[commands]]
run = "echo hi"
os = ["ubuntu"]
`), 0o644); err != nil {
		t.Fatal(err)
	}
	m, err := ParseModule(p)
	if err != nil {
		t.Fatal(err)
	}
	if len(m.Commands) != 1 || len(m.Commands[0].OS) != 1 || m.Commands[0].OS[0] != "ubuntu" {
		t.Fatalf("OS not parsed: %+v", m.Commands)
	}
}
```

If `ParseModule`'s name/signature differs, use the actual parser entry point from the file. Add `os`, `path/filepath`, `testing` imports as needed.

- [ ] **Step 3: Run tests to verify they fail**

Run: `go test ./internal/runner/ ./internal/manifest/ -run 'OS|Gated|Regression' -v`
Expected: FAIL — `BuildActions` takes 2 args not 3; `manifest.Command` has no field `OS`.

- [ ] **Step 4: Add `OS` to every action struct**

In `internal/manifest/schema.go`, add `OS []string \`toml:"os"\`` to `Packages`, `Symlink`, `Command`, `File`, `Service`, and `Directory` (alongside their existing `Hosts []string`). Example for `Command`:

```go
type Command struct {
	Run   string   `toml:"run"`
	Check string   `toml:"check"`
	Hosts []string `toml:"hosts"`
	OS    []string `toml:"os"`
}
```

Do the same for the other five structs.

- [ ] **Step 5: Add gating helpers + `os` param in `build.go`**

In `internal/runner/build.go`:

1. Change the signature and thread `os` through every loop:

```go
func BuildActions(m *module.Module, host *manifest.Host, os string) ([]action.Action, error) {
```

2. Add the two helpers at the bottom (next to `hostMatch`):

```go
// osMatch reports whether an action's optional os filter includes the current
// OS. An empty list means "all OSes" — the regression guard that keeps every
// existing module behaving exactly as before.
func osMatch(osList []string, current string) bool {
	if len(osList) == 0 {
		return true
	}
	for _, o := range osList {
		if o == current {
			return true
		}
	}
	return false
}

// osAllowsManager reports whether a package manager applies to the current OS.
// The manager IS the OS signal: pacman/yay/aur are Arch-only, apt is
// Ubuntu-only, flatpak runs anywhere.
func osAllowsManager(current, manager string) bool {
	switch manager {
	case "pacman", "yay", "aur":
		return current == "arch"
	case "apt":
		return current == "ubuntu"
	case "flatpak", "":
		return true
	}
	return true // unknown managers are not OS-gated here
}
```

3. Gate each action. For packages, check both the manager rule and `osMatch`
   (note: gate on `p.Manager` BEFORE the empty→yay normalization, so `aur`/``
   are classified correctly):

```go
	for _, p := range m.Packages {
		if !hostMatch(p.Hosts, host.Name) {
			continue
		}
		if !osAllowsManager(os, p.Manager) || !osMatch(p.OS, os) {
			continue
		}
		mgr := p.Manager
		if mgr == "" || mgr == "aur" {
			mgr = "yay"
		}
		acts = append(acts, &action.Packages{Manager: mgr, Names: p.Names})
	}
```

   For `Directories`, `Symlinks`, `Files`, `Commands`, `Services`: add
   `if !osMatch(<entry>.OS, os) { continue }` directly after each existing
   `hostMatch` guard.

   **Also update the existing tests in `build_test.go`:** the three pre-existing
   `BuildActions(m, host)` calls (in `TestBuildActions_filtersByHostAndExpandsSymlinks`,
   `TestBuildActions_rendersTemplateSymlink`, `TestBuildActions_managerDefaultsToYay`)
   now need the third arg — change each to `BuildActions(m, host, "arch")`.

- [ ] **Step 6: Thread `os` through `plan.go` and the cmd callers**

`internal/runner/plan.go`:

```go
func BuildPlan(mods []*module.Module, host *manifest.Host, os string) []ModulePlan {
	out := make([]ModulePlan, len(mods))
	for i, m := range mods {
		acts, err := BuildActions(m, host, os)
		out[i] = ModulePlan{Module: m, Actions: acts, BuildErr: err}
	}
	return out
}
```

`cmd/quill/context.go` — add the field and populate it (import already has `host`):

```go
type appCtx struct {
	RepoRoot string
	Modules  []*module.Module
	Host     *manifest.Host
	OS       string
}
```

In `loadCtx`, after host load:

```go
	return &appCtx{RepoRoot: root, Modules: mods, Host: h, OS: host.DetectOS()}, nil
```

`cmd/quill/status.go`: change `runner.BuildActions(m, ctx.Host)` →
`runner.BuildActions(m, ctx.Host, ctx.OS)`.

`cmd/quill/apply.go` and `cmd/quill/install.go`: change
`runner.BuildPlan(ordered, ctx.Host)` → `runner.BuildPlan(ordered, ctx.Host, ctx.OS)`.

- [ ] **Step 7: Run tests to verify they pass**

Run: `go test ./...`
Expected: PASS — including the Arch regression test. Build is green.

- [ ] **Step 8: Commit**

```bash
gofmt -w .
go test ./...
git add internal/manifest/ internal/runner/build.go internal/runner/build_test.go internal/runner/plan.go cmd/quill/context.go cmd/quill/status.go cmd/quill/apply.go cmd/quill/install.go
git commit -m "runner: gate actions by detected OS (manager-implies-os + os=[] field)"
```

---

## Task 4: `$QUILL_OS` env + shebang invocation for install.sh

**Files:**
- Modify: `internal/runner/install_sh.go`
- Modify: `cmd/quill/apply.go`, `cmd/quill/install.go` (RunInstallSh call sites)
- Test: `internal/runner/install_sh_test.go` (new)

- [ ] **Step 1: Write the failing test**

Create `internal/runner/install_sh_test.go`:

```go
package runner

import (
	"os"
	"path/filepath"
	"testing"

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

	m := &module.Module{Name: "x", Dir: dir}
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
	if err := RunInstallSh(&module.Module{Name: "x", Dir: t.TempDir()}, "arch", "h"); err != nil {
		t.Fatalf("absent install.sh should be nil, got %v", err)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/runner/ -run TestRunInstallSh -v`
Expected: FAIL — `RunInstallSh` currently takes 1 arg; also it runs under `sh`, so `[[ ]]` would not behave on a dash system.

- [ ] **Step 3: Implement**

In `internal/runner/install_sh.go`, change `RunInstallSh`:

```go
func RunInstallSh(m *module.Module, osName, hostName string) error {
	script := filepath.Join(m.Dir, "install.sh")
	if _, err := os.Stat(script); err != nil {
		return nil
	}
	// Invoke the script directly so its #!/usr/bin/env bash shebang governs.
	// (Previously this ran `sh script`, which is bash on Arch but dash on
	// Ubuntu — silently breaking the scripts' [[ ]] / array bashisms.)
	cmd := exec.Command(script)
	cmd.Dir = m.Dir
	cmd.Env = append(os.Environ(),
		"QUILL_OS="+osName,
		"QUILL_HOST="+hostName,
	)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("install.sh for %s failed: %w", m.Name, err)
	}
	return nil
}
```

- [ ] **Step 4: Update the two call sites**

`cmd/quill/apply.go` (~line 71) and `cmd/quill/install.go` (~line 106):

```go
				if err := runner.RunInstallSh(p.Module, ctx.OS, ctx.Host.Name); err != nil {
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `go test ./...`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
gofmt -w .
go test ./...
git add internal/runner/install_sh.go internal/runner/install_sh_test.go cmd/quill/apply.go cmd/quill/install.go
git commit -m "runner: export \$QUILL_OS to install.sh and honor its shebang"
```

---

## Task 5: bootstrap.sh ubuntu branch

**Files:**
- Modify: `bootstrap.sh`

- [ ] **Step 1: Edit the prerequisite line**

Replace the single `echo "==> Installing prerequisites..."` + `sudo pacman ...`
pair (currently lines 10–11) with an OS branch. `bootstrap.sh` runs before quill
is built, so it self-detects from `/etc/os-release`:

```sh
echo "==> Installing prerequisites"
case "$(. /etc/os-release && echo "$ID")" in
  arch)
    sudo pacman -Sy --needed --noconfirm git go base-devel
    ;;
  ubuntu)
    sudo apt-get update
    sudo apt-get install -y git golang-go build-essential curl
    ;;
  *)
    echo "unsupported distro (need arch or ubuntu)" >&2
    exit 1
    ;;
esac
```

Leave the clone/build/launch tail unchanged.

- [ ] **Step 2: Lint the script**

Run: `bash -n bootstrap.sh`
Expected: no output (syntax OK).

- [ ] **Step 3: Commit**

```bash
git add bootstrap.sh
git commit -m "bootstrap: add ubuntu prerequisite branch"
```

---

## Task 6: Dalton host profile

**Files:**
- Create: `hosts/Dalton.toml`

- [ ] **Step 1: Write the host file**

```toml
name    = "Dalton"
modules = ["git", "shell", "tmux", "neovim", "ai", "python", "asdf"]

[vars]
git_email       = "50755420+DaltonDayton@users.noreply.github.com"
git_signing_key = "~/.ssh/id_ed25519"
```

> Only `shell` is made Ubuntu-ready in this slice. The others are listed so the
> host is complete; running full `quill apply` on Dalton before later slices
> land may no-op or partially apply them. Use `quill apply shell` to stay
> scoped.

- [ ] **Step 2: Verify it parses**

Run: `go build -o ./bin/quill ./cmd/quill && ./bin/quill status 2>&1 | head`
Expected: on this machine (hostname `Dalton`) status loads the profile and lists
modules without a "host profile not found" error. (Modules other than `shell`
may show PENDING — expected.)

- [ ] **Step 3: Commit**

```bash
git add hosts/Dalton.toml
git commit -m "hosts: add Dalton (WSL/Ubuntu) profile"
```

---

## Task 7: shell module — Ubuntu support

**Files:**
- Modify: `modules/shell/module.toml`
- Modify: `modules/shell/install.sh`
- Modify: `modules/shell/files/.zshrc`

- [ ] **Step 1: Add the apt packages block**

In `modules/shell/module.toml`, after the existing `[[packages]] manager = "pacman"` block, add:

```toml
[[packages]]
manager = "apt"
names = ["zsh", "less", "fzf", "nvtop", "bat"]
```

(`starship`, `eza`, `zoxide`, `atuin`, `yazi` are not in apt — handled in
install.sh. `bat` installs as the `batcat` binary on Ubuntu; install.sh adds a
`bat` shim.)

- [ ] **Step 2: Add the `$QUILL_OS` branch to install.sh**

`modules/shell/install.sh` currently only sets the login shell. Insert the
ubuntu tool install BEFORE the existing chsh logic (so the chsh tail still runs
on both OSes). Every installer is idempotent via a `command -v` guard and targets
`~/.local/bin` to avoid sudo. eza/yazi use prebuilt GitHub release binaries (no
rust toolchain — keeps this slice independent of the asdf slice):

```sh
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Download the latest GitHub release asset whose name matches $2 (a grep -E
# pattern) from repo $1, into $LOCAL_BIN. Extracts tar.gz or zip; copies the
# named binaries ($3...) out. Idempotent callers guard with `command -v`.
fetch_gh_release() {
  repo="$1"; asset_re="$2"; shift 2
  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -oE "https://[^\"]*$asset_re" | head -n1)"
  [ -n "$url" ] || { echo "no release asset for $repo matching $asset_re" >&2; return 1; }
  tmp="$(mktemp -d)"
  file="$tmp/$(basename "$url")"
  curl -fsSL "$url" -o "$file"
  case "$file" in
    *.tar.gz|*.tgz) tar -xzf "$file" -C "$tmp" ;;
    *.zip)          unzip -q "$file" -d "$tmp" ;;
  esac
  for bin in "$@"; do
    found="$(find "$tmp" -type f -name "$bin" -perm -u+x | head -n1)"
    [ -n "$found" ] || found="$(find "$tmp" -type f -name "$bin" | head -n1)"
    [ -n "$found" ] && install -m755 "$found" "$LOCAL_BIN/$bin"
  done
  rm -rf "$tmp"
}

case "$QUILL_OS" in
  arch)
    : # pacman block installed everything
    ;;
  ubuntu)
    command -v unzip >/dev/null || sudo apt-get install -y unzip

    command -v starship >/dev/null || \
      curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN"

    command -v zoxide >/dev/null || \
      curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

    command -v atuin >/dev/null || \
      curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

    command -v eza >/dev/null || \
      fetch_gh_release "eza-community/eza" 'eza_x86_64-unknown-linux-gnu\.tar\.gz' eza

    command -v yazi >/dev/null || \
      fetch_gh_release "sxyazi/yazi" 'yazi-x86_64-unknown-linux-gnu\.zip' yazi ya

    # bat ships as `batcat` on Ubuntu; expose it under the expected name.
    if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
      ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
    fi
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac
```

Keep the existing login-shell block (`current=...; target=...; chsh`) below this,
unchanged.

> Note: `atuin`/`zoxide` official installers place binaries in `~/.local/bin`,
> which the `.zshrc` already adds to `PATH`. `starship -b "$LOCAL_BIN"` pins the
> same dir so no sudo is needed.

- [ ] **Step 3: Guard the unconditional eval lines in .zshrc**

In `modules/shell/files/.zshrc`, make starship/atuin init resilient when a tool
is briefly missing (e.g. a fresh shell opened mid-install). Change:

```sh
eval "$(starship init zsh)"
eval "$(atuin init zsh)"
```

to:

```sh
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v atuin    >/dev/null && eval "$(atuin init zsh)"
```

(Leave `eval "$(fzf --zsh)"` and the already-guarded `uv`/`sesh` lines as they
are.)

- [ ] **Step 4: Lint the script**

Run: `bash -n modules/shell/install.sh`
Expected: no output.

- [ ] **Step 5: Smoke-test on this Ubuntu box**

Run: `go build -o ./bin/quill ./cmd/quill && ./bin/quill apply shell`
Expected: apt block installs zsh/less/fzf/nvtop/bat; install.sh installs the
long-tail tools into `~/.local/bin`; the `.zshrc`/`starship.toml`/`yazi` symlinks
are created. Re-run `./bin/quill apply shell` and confirm it is idempotent
(packages already installed, `command -v` guards skip installers, symlinks
report OK/skip).

Verify: `command -v starship zoxide atuin eza yazi bat` all resolve.

- [ ] **Step 6: Commit**

```bash
git add modules/shell/module.toml modules/shell/install.sh modules/shell/files/.zshrc
git commit -m "shell: ubuntu support (apt block + install.sh long-tail + resilient zshrc)"
```

---

## Task 8: Documentation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the scope + user-context lines**

In `CLAUDE.md`:

1. In **User context**, change the first bullet from "v1 doesn't target WSL but
   the architecture should not preclude it" to reflect that WSL/Ubuntu is now a
   supported (in-progress) target managed by the same module/host model.
2. In **Things that are explicitly out of scope (v1)**, remove the
   "WSL / non-Arch Linux / macOS support" bullet and replace with
   "macOS / non-Arch-non-Ubuntu distros" (Ubuntu is now in scope; macOS and
   other distros remain out).
3. Add a row to the **Specs and plans** table:

```markdown
| WSL/Ubuntu foundation + shell module | `docs/superpowers/specs/2026-06-08-wsl-ubuntu-foundation-shell-design.md` | `docs/superpowers/plans/2026-06-08-wsl-ubuntu-foundation-shell.md` |
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: mark WSL/Ubuntu as in-scope; link foundation+shell spec/plan"
```

---

## Done criteria

- [ ] `go test ./...` passes.
- [ ] `gofmt -w .` leaves no diff.
- [ ] On Arch, `quill status`/`apply` for existing hosts produce identical action sets (Task 3 regression test green).
- [ ] On this Ubuntu box, `quill apply shell` installs all shell tooling and is idempotent on re-run.
- [ ] `~/.zshrc` (startover shell module) loads cleanly — the rough-terminal problem is resolved.
```
