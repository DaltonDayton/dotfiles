# OS/Machine Install Profile Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hostname-based host selection in `quill install`/`apply` with an explicit two-axis profile pick (OS = Arch/WSL, Machine = Desktop/Laptop, Arch-only), rendered as a single flat module list that hides OS/machine-invalid modules and persists the choice.

**Architecture:** Add module-level `os`/`machine` validity fields and profile-level `os`/`machine` fields to the manifest; rename `Host`→`Profile` and `hosts/`→`profiles/`. Pure, table-tested functions do validity filtering, preselect, and `(os,machine)→profile` resolution; the huh TUI is a thin renderer over them. `install` runs a nested picker; `apply` resolves the profile from flags → persisted state → first-run prompt. State persists `{os, machine, modules}`.

**Tech Stack:** Go, BurntSushi/toml, charmbracelet/huh (selects + multiselect), cobra. TDD with `t.TempDir()` and pure functions; huh wiring stays thin and is covered by the live check.

## Global Constraints

- Additive to the existing per-action OS gating (`pacman/aur ⇒ arch`, `apt ⇒ ubuntu`, action `os = [...]`). Do NOT change `osMatch`/`osAllowsManager`.
- OS values internally: `"arch"` and `"ubuntu"`. The picker/flag label "WSL" maps to `"ubuntu"`. `wsl.toml` sets `os = "ubuntu"`.
- Machine values: `"desktop"`, `"laptop"`. WSL leaves machine `""` (empty). Machine filter is skipped when machine is `""`.
- Module validity: `os` empty = any OS; `machine` empty = any machine. A module is hidden iff (os set and excludes pick) OR (machine non-empty pick and module.machine set and excludes it).
- Run `gofmt -w .` before every commit. Run `go test ./...` before every commit.
- Module tagging (verbatim, from the current module scan): `os=["arch"]` on `fonts`, `hyprland`, `obsidian`, `solaar`; `os=["arch"]` + `machine=["desktop"]` on `gaming`, `razer`. All others untouched (cross-platform).
- Profiles (verbatim module lists, migrated from current host TOMLs):
  - `arch-desktop` (os=arch, machine=desktop): `git shell tmux fonts asdf python neovim hyprland ai obsidian solaar gaming razer`
  - `arch-laptop` (os=arch, machine=laptop): `git shell tmux fonts asdf python neovim hyprland ai obsidian solaar`
  - `wsl` (os=ubuntu, no machine): `git shell tmux neovim ai python asdf`

**Branch:** `install-profile-picker` (off `startover`, already checked out).

**Spec:** `docs/superpowers/specs/2026-07-01-install-profile-picker-design.md`.

> **Shell note:** this repo's zsh aliases `cd` to zoxide and bare globs can trip `set -e`. Use absolute paths and `git -C /home/dalton/.dotfiles ...`. Avoid `cd module/...`.

---

## File structure

| File | Change | Task |
|---|---|---|
| `internal/manifest/schema.go` | `Module` gains `OS`/`Machine`; `Host`→`Profile` gains `OS`/`Machine` | 1 |
| `internal/manifest/parse.go` | `ParseHost`→`ParseProfile` | 1 |
| `internal/manifest/parse_test.go` | parse tests for new fields | 1 |
| `internal/template/render.go` | `Render(src, *manifest.Profile)` | 1 |
| `internal/runner/build.go`, `plan.go` | `*manifest.Host`→`*manifest.Profile` params | 1 |
| `internal/host/host.go` | delete hostname `Detect`/`Load`; keep `DetectOS` (os.go) | 1 |
| `cmd/quill/context.go`, `install.go`, `apply.go`, `status.go` | drop hostname load; `appCtx.Host`→`Profile` type; temporary wiring | 1 |
| `hosts/` → `profiles/` (git mv 3 files) | rename dir | 1 |
| `internal/module/validity.go` (+`_test.go`) | `ValidFor`, `FilterValid`, `Preselect` pure funcs | 2 |
| `internal/profile/profile.go` (+`_test.go`) | `NormalizeOS`, `FileName`, `Load` | 3 |
| `profiles/arch-desktop.toml`, `arch-laptop.toml`, `wsl.toml` | new combo files | 3 |
| `modules/{fonts,hyprland,obsidian,solaar,gaming,razer}/module.toml` | add `os`/`machine` | 3 |
| `internal/state/selection.go` (+`_test.go`) | `Selection{OS,Machine,Modules}`, `LoadState`/`SaveState` | 4 |
| `internal/tui/selector.go` (+ `picker.go`) | flat multiselect; `PickProfile` nested select | 5 |
| `cmd/quill/install.go` | nested picker + validity filter + persist | 6 |
| `cmd/quill/apply.go` | `--os`/`--machine` flags + state/prompt resolution | 7 |

---

## Task 1: manifest data model + Host→Profile rename + profiles/ dir

Foundational, mechanical. Adds the new fields and renames the type/dir so every later task uses the final names. Build + tests stay green; behavior is unchanged (new fields are optional and unused until later tasks; profile is still loaded by hostname for now).

**Files:**
- Modify: `internal/manifest/schema.go`, `internal/manifest/parse.go`, `internal/manifest/parse_test.go`
- Modify: `internal/template/render.go`, `internal/runner/build.go`, `internal/runner/plan.go`
- Modify: `internal/host/host.go`
- Modify: `cmd/quill/context.go`, `cmd/quill/install.go`, `cmd/quill/apply.go`, `cmd/quill/status.go`
- Rename: `hosts/Dalton.toml`, `hosts/archlinux.toml`, `hosts/archlaptop.toml` → `profiles/`

**Interfaces:**
- Produces: `manifest.Profile{Name, OS, Machine, Modules, Vars}`; `manifest.Module` fields `OS []string`, `Machine []string`; `manifest.ParseProfile(path) (*manifest.Profile, error)`.

- [ ] **Step 1: Add fields to schema.go**

In `internal/manifest/schema.go`, add to the `Module` struct (after `Hosts`):
```go
	OS      []string `toml:"os"`
	Machine []string `toml:"machine"`
```
Rename the `Host` struct to `Profile` and add fields:
```go
// Profile mirrors profiles/<name>.toml — the OS/machine combo the user picks.
type Profile struct {
	Name    string            `toml:"name"`
	OS      string            `toml:"os"`      // "arch" | "ubuntu"
	Machine string            `toml:"machine"` // "desktop" | "laptop" | "" (WSL)
	Modules []string          `toml:"modules"`
	Vars    map[string]string `toml:"vars"`
}
```

- [ ] **Step 2: Rename the parser**

In `internal/manifest/parse.go`, rename `ParseHost`→`ParseProfile`, returning `*Profile`, error message `"%s: profile is missing required field 'name'"`. Body otherwise identical (still defaults `Vars` to `map[string]string{}`).

- [ ] **Step 3: Update parse_test.go for new fields**

In `internal/manifest/parse_test.go`, update any `ParseHost` calls to `ParseProfile`. Add a test writing a profile TOML with `os`, `machine`, `modules` and asserting they decode; and a module TOML with `os = ["arch"]`, `machine = ["desktop"]` asserting `m.OS`/`m.Machine` decode:
```go
func TestParseProfile_osMachine(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "wsl.toml")
	os.WriteFile(p, []byte("name=\"wsl\"\nos=\"ubuntu\"\nmodules=[\"git\"]\n"), 0o644)
	prof, err := ParseProfile(p)
	if err != nil { t.Fatal(err) }
	if prof.OS != "ubuntu" || len(prof.Modules) != 1 { t.Fatalf("got %+v", prof) }
	if prof.Machine != "" { t.Fatalf("machine should be empty, got %q", prof.Machine) }
}
```

- [ ] **Step 4: Update every `manifest.Host` reference to `manifest.Profile`**

Mechanical. `git -C /home/dalton/.dotfiles grep -l 'manifest.Host'` lists them. Update:
- `internal/template/render.go`: `func Render(src string, h *manifest.Host)` → `p *manifest.Profile` (rename the param and its `.Name`/`.Vars` uses).
- `internal/runner/build.go`: `BuildActions(m *module.Module, host *manifest.Host, osName string)` → `profile *manifest.Profile`; update the `host.Name` uses to `profile.Name` and the `template.Render(..., host)` call to `profile`.
- `internal/runner/plan.go`: `BuildPlan(mods, host *manifest.Host, osName)` → `profile *manifest.Profile`, pass through.
- Any `_test.go` constructing `manifest.Host{...}` → `manifest.Profile{...}`.

- [ ] **Step 5: Retire hostname Detect/Load, keep DetectOS**

Delete `Detect` and `Load` from `internal/host/host.go` (the hostname functions). Keep `internal/host/os.go` (`DetectOS`) untouched. If `host.go` becomes empty of funcs, leave the package doc comment + the file with just the package clause, or delete `host.go` and keep `os.go`. Update `internal/host/host_test.go` — remove the `TestLoad_byHostname` test (hostname loading is gone).

- [ ] **Step 6: Rewire context.go to drop the hostname load (temporary profile plumbing)**

In `cmd/quill/context.go`: remove the `host.Detect()` + `host.Load()` block. `appCtx` becomes:
```go
type appCtx struct {
	RepoRoot string
	Modules  []*module.Module
	Profile  *manifest.Profile
	OS       string
}
```
`loadCtx` no longer loads a profile (later tasks resolve it). Set `Profile: nil`, keep `OS: host.DetectOS()` + the unknown-OS warning. Callers that dereference `ctx.Profile` are fixed in this step to keep the build green: in `install.go` and `apply.go`, temporarily load a profile inline from `profiles/` by `DetectOS()`-derived name so the build compiles and existing behavior on this box is preserved. Add this helper in `context.go`:
```go
// loadProfileByOS is temporary scaffolding for Task 1 so install/apply still
// resolve a profile before the picker (Tasks 6-7) lands. Arch → arch-desktop.
func loadProfileByOS(root, osName string) (*manifest.Profile, error) {
	name := "wsl"
	if osName == "arch" {
		name = "arch-desktop"
	}
	return manifest.ParseProfile(filepath.Join(root, "profiles", name+".toml"))
}
```
In `install.go`/`apply.go`, replace `ctx.Host` usages with a local `prof, err := loadProfileByOS(ctx.RepoRoot, ctx.OS)` and use `prof.Name`/`prof.Modules`; pass `prof` to `BuildPlan`/`FilterByHost`/`RunInstallSh`. Update `status.go` similarly if it references `ctx.Host`. (This scaffolding is replaced in Tasks 6-7.)

- [ ] **Step 7: git mv the host TOMLs to profiles/ and give them os/machine**

```bash
git -C /home/dalton/.dotfiles mv hosts profiles
git -C /home/dalton/.dotfiles mv profiles/archlinux.toml profiles/arch-desktop.toml
git -C /home/dalton/.dotfiles mv profiles/archlaptop.toml profiles/arch-laptop.toml
git -C /home/dalton/.dotfiles mv profiles/Dalton.toml profiles/wsl.toml
```
Then edit each to add `os`/`machine` and rename `name`:
- `arch-desktop.toml`: `name="arch-desktop"`, `os="arch"`, `machine="desktop"` (keep its `modules`/`vars`).
- `arch-laptop.toml`: `name="arch-laptop"`, `os="arch"`, `machine="laptop"`.
- `wsl.toml`: `name="wsl"`, `os="ubuntu"` (no machine line), keep `modules`/`vars`.

- [ ] **Step 8: Build, format, test**

```bash
cd /home/dalton/.dotfiles && gofmt -w . && go build ./... && go test ./...
```
Expected: builds, all tests pass. `./bin/quill status` still runs (uses the temporary `loadProfileByOS`).

- [ ] **Step 9: Commit**

```bash
git -C /home/dalton/.dotfiles add -A
git -C /home/dalton/.dotfiles commit -m "manifest: add module os/machine + rename Host->Profile, hosts/->profiles/"
```

---

## Task 2: module validity pure functions

**Files:**
- Create: `internal/module/validity.go`, `internal/module/validity_test.go`

**Interfaces:**
- Consumes: `module.Module` (embeds `*manifest.Module`, so `.OS`/`.Machine` are reachable).
- Produces: `module.ValidFor(m *Module, osName, machine string) bool`; `module.FilterValid(mods []*Module, osName, machine string) []*Module`; `module.Preselect(valid []*Module, candidates []string) map[string]bool`.

- [ ] **Step 1: Write failing tests**

`internal/module/validity_test.go`:
```go
package module

import (
	"testing"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

func mod(name string, os, machine []string) *Module {
	return &Module{Module: &manifest.Module{Name: name, OS: os, Machine: machine}}
}

func TestValidFor(t *testing.T) {
	cases := []struct {
		name           string
		os, machine    []string
		pickOS, pickMc string
		want           bool
	}{
		{"cross-platform on ubuntu", nil, nil, "ubuntu", "", true},
		{"arch-only on ubuntu", []string{"arch"}, nil, "ubuntu", "", false},
		{"arch-only on arch", []string{"arch"}, nil, "arch", "desktop", true},
		{"desktop-only on laptop", []string{"arch"}, []string{"desktop"}, "arch", "laptop", false},
		{"desktop-only on desktop", []string{"arch"}, []string{"desktop"}, "arch", "desktop", true},
		{"machine skipped when pick empty (wsl)", nil, []string{"desktop"}, "ubuntu", "", true},
	}
	for _, c := range cases {
		if got := ValidFor(mod(c.name, c.os, c.machine), c.pickOS, c.pickMc); got != c.want {
			t.Errorf("%s: ValidFor=%v want %v", c.name, got, c.want)
		}
	}
}

func TestFilterValidAndPreselect(t *testing.T) {
	mods := []*Module{
		mod("git", nil, nil),
		mod("hyprland", []string{"arch"}, nil),
		mod("gaming", []string{"arch"}, []string{"desktop"}),
	}
	got := FilterValid(mods, "ubuntu", "")
	if len(got) != 1 || got[0].Name != "git" {
		t.Fatalf("FilterValid ubuntu = %v", names(got))
	}
	pre := Preselect(got, []string{"git", "hyprland"})
	if !pre["git"] || pre["hyprland"] {
		t.Fatalf("Preselect = %v (want git only; hyprland not in valid set)", pre)
	}
}

func names(ms []*Module) []string {
	out := []string{}
	for _, m := range ms {
		out = append(out, m.Name)
	}
	return out
}
```

- [ ] **Step 2: Run, verify fail**

`go test ./internal/module/ -run 'ValidFor|FilterValid' -v` → FAIL (undefined ValidFor).

- [ ] **Step 3: Implement validity.go**

```go
package module

// ValidFor reports whether a module may be installed under the picked profile.
// os empty on the module = any OS; machine empty = any machine. When the pick's
// machine is "" (WSL), the machine axis is not applied.
func ValidFor(m *Module, osName, machine string) bool {
	if !listAllows(m.OS, osName) {
		return false
	}
	if machine != "" && !listAllows(m.Machine, machine) {
		return false
	}
	return true
}

// listAllows returns true if list is empty (any) or contains want.
func listAllows(list []string, want string) bool {
	if len(list) == 0 {
		return true
	}
	for _, v := range list {
		if v == want {
			return true
		}
	}
	return false
}

func FilterValid(mods []*Module, osName, machine string) []*Module {
	var out []*Module
	for _, m := range mods {
		if ValidFor(m, osName, machine) {
			out = append(out, m)
		}
	}
	return out
}

// Preselect returns which of candidates are present in valid (checked-by-default
// set), silently dropping candidates that are not valid for the profile.
func Preselect(valid []*Module, candidates []string) map[string]bool {
	validSet := map[string]bool{}
	for _, m := range valid {
		validSet[m.Name] = true
	}
	out := map[string]bool{}
	for _, name := range candidates {
		if validSet[name] {
			out[name] = true
		}
	}
	return out
}
```

- [ ] **Step 4: Run, verify pass**

`go test ./internal/module/ -v` → PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/dalton/.dotfiles && gofmt -w .
git -C /home/dalton/.dotfiles add internal/module/validity.go internal/module/validity_test.go
git -C /home/dalton/.dotfiles commit -m "module: os/machine validity + preselect pure functions"
```

---

## Task 3: profile resolution + combo files + module tagging

**Files:**
- Create: `internal/profile/profile.go`, `internal/profile/profile_test.go`
- Create: `profiles/arch-desktop.toml`, `profiles/arch-laptop.toml`, `profiles/wsl.toml` (already renamed in Task 1 — here verify contents match spec exactly)
- Modify: `modules/{fonts,hyprland,obsidian,solaar,gaming,razer}/module.toml`

**Interfaces:**
- Consumes: `manifest.ParseProfile`, `manifest.Profile`.
- Produces: `profile.NormalizeOS(s string) string`; `profile.FileName(osName, machine string) (string, error)`; `profile.Load(profilesDir, osName, machine string) (*manifest.Profile, error)`.

- [ ] **Step 1: Write failing tests**

`internal/profile/profile_test.go`:
```go
package profile

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNormalizeOS(t *testing.T) {
	for in, want := range map[string]string{"wsl": "ubuntu", "ubuntu": "ubuntu", "arch": "arch"} {
		if got := NormalizeOS(in); got != want {
			t.Errorf("NormalizeOS(%q)=%q want %q", in, got, want)
		}
	}
}

func TestFileName(t *testing.T) {
	cases := []struct{ os, mc, want string; err bool }{
		{"arch", "desktop", "arch-desktop", false},
		{"arch", "laptop", "arch-laptop", false},
		{"ubuntu", "", "wsl", false},
		{"ubuntu", "desktop", "wsl", false}, // machine ignored for ubuntu
		{"arch", "", "", true},              // arch needs a machine
		{"plan9", "", "", true},
	}
	for _, c := range cases {
		got, err := FileName(c.os, c.mc)
		if c.err && err == nil {
			t.Errorf("FileName(%q,%q) expected error", c.os, c.mc)
		}
		if !c.err && got != c.want {
			t.Errorf("FileName(%q,%q)=%q want %q", c.os, c.mc, got, c.want)
		}
	}
}

func TestLoad(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "wsl.toml"),
		[]byte("name=\"wsl\"\nos=\"ubuntu\"\nmodules=[\"git\"]\n"), 0o644)
	p, err := Load(dir, "ubuntu", "")
	if err != nil { t.Fatal(err) }
	if p.Name != "wsl" || p.OS != "ubuntu" { t.Fatalf("got %+v", p) }
}
```

- [ ] **Step 2: Run, verify fail**

`go test ./internal/profile/ -v` → FAIL (no such package / undefined).

- [ ] **Step 3: Implement profile.go**

```go
// Package profile resolves the (os, machine) pick to a profiles/<name>.toml.
package profile

import (
	"fmt"
	"path/filepath"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

// NormalizeOS maps the user-facing "wsl" label to the internal "ubuntu" id.
func NormalizeOS(s string) string {
	if s == "wsl" {
		return "ubuntu"
	}
	return s
}

// FileName resolves an (os, machine) pick to a profile file base name.
// Arch requires a machine; Ubuntu ignores it (WSL has no machine split).
func FileName(osName, machine string) (string, error) {
	switch osName {
	case "arch":
		switch machine {
		case "desktop":
			return "arch-desktop", nil
		case "laptop":
			return "arch-laptop", nil
		default:
			return "", fmt.Errorf("arch profile requires machine \"desktop\" or \"laptop\", got %q", machine)
		}
	case "ubuntu":
		return "wsl", nil
	default:
		return "", fmt.Errorf("unknown os %q (want \"arch\" or \"ubuntu\")", osName)
	}
}

func Load(profilesDir, osName, machine string) (*manifest.Profile, error) {
	base, err := FileName(osName, machine)
	if err != nil {
		return nil, err
	}
	return manifest.ParseProfile(filepath.Join(profilesDir, base+".toml"))
}
```

- [ ] **Step 4: Run, verify pass**

`go test ./internal/profile/ -v` → PASS.

- [ ] **Step 5: Verify the three profile files match spec**

Confirm (from Task 1 rename) the files exist with exact contents:
```bash
cat /home/dalton/.dotfiles/profiles/arch-desktop.toml /home/dalton/.dotfiles/profiles/arch-laptop.toml /home/dalton/.dotfiles/profiles/wsl.toml
```
`arch-desktop`: os="arch" machine="desktop" modules=`["git","shell","tmux","fonts","asdf","python","neovim","hyprland","ai","obsidian","solaar","gaming","razer"]`. `arch-laptop`: os="arch" machine="laptop", same minus `gaming`,`razer`. `wsl`: os="ubuntu", no machine, modules=`["git","shell","tmux","neovim","ai","python","asdf"]`. Fix any drift.

- [ ] **Step 6: Tag the arch-only / desktop modules**

Add fields to each `module.toml` header block (after `tags`):
- `modules/fonts/module.toml`, `modules/hyprland/module.toml`, `modules/obsidian/module.toml`, `modules/solaar/module.toml`: add `os = ["arch"]`.
- `modules/gaming/module.toml`, `modules/razer/module.toml`: add `os = ["arch"]` and `machine = ["desktop"]`.

- [ ] **Step 7: Verify parse + build**

```bash
cd /home/dalton/.dotfiles && go build ./... && ./bin/quill status 2>&1 | head -20
```
Expected: builds; status lists modules without parse errors.

- [ ] **Step 8: Commit**

```bash
cd /home/dalton/.dotfiles && gofmt -w .
git -C /home/dalton/.dotfiles add -A
git -C /home/dalton/.dotfiles commit -m "profile: (os,machine)->file resolver + combo files + module os/machine tags"
```

---

## Task 4: state persistence of {os, machine, modules}

**Files:**
- Modify: `internal/state/selection.go`, `internal/state/selection_test.go` (create if absent)

**Interfaces:**
- Produces: `state.Selection{OS, Machine string; Modules []string}`; `state.LoadState(path) (*Selection, error)` (nil,nil if missing); `state.SaveState(path, *Selection) error`. Keep `DefaultPath()`.

- [ ] **Step 1: Write failing test**

`internal/state/selection_test.go`:
```go
package state

import (
	"path/filepath"
	"testing"
)

func TestStateRoundTrip(t *testing.T) {
	p := filepath.Join(t.TempDir(), "sel.json")
	if s, err := LoadState(p); err != nil || s != nil {
		t.Fatalf("missing file: got %v,%v want nil,nil", s, err)
	}
	want := &Selection{OS: "ubuntu", Machine: "", Modules: []string{"git", "shell"}}
	if err := SaveState(p, want); err != nil {
		t.Fatal(err)
	}
	got, err := LoadState(p)
	if err != nil {
		t.Fatal(err)
	}
	if got.OS != "ubuntu" || len(got.Modules) != 2 || got.Machine != "" {
		t.Fatalf("got %+v", got)
	}
}
```

- [ ] **Step 2: Run, verify fail**

`go test ./internal/state/ -v` → FAIL (undefined Selection/LoadState).

- [ ] **Step 3: Rewrite selection.go**

Replace `selectionFile`/`LoadSelection`/`SaveSelection` with:
```go
type Selection struct {
	OS      string   `json:"os"`
	Machine string   `json:"machine"`
	Modules []string `json:"modules"`
}

// LoadState reads the selection JSON at path. A missing file returns
// (nil, nil) — first run.
func LoadState(path string) (*Selection, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var s Selection
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, err
	}
	return &s, nil
}

func SaveState(path string, s *Selection) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}
```
Keep `DefaultPath()`. (Callers in install/apply are updated in Tasks 6-7; the build may not reference the old names after this step — grep and fix any lingering `LoadSelection`/`SaveSelection` in cmd to keep the build green, temporarily passing `&Selection{Modules: ...}`.)

- [ ] **Step 4: Run, verify pass + build**

```bash
cd /home/dalton/.dotfiles && go build ./... && go test ./internal/state/ -v
```
Expected: PASS. If `cmd/quill` fails to build on old `LoadSelection` names, minimally adapt those call sites to `LoadState`/`SaveState` now.

- [ ] **Step 5: Commit**

```bash
cd /home/dalton/.dotfiles && gofmt -w .
git -C /home/dalton/.dotfiles add -A
git -C /home/dalton/.dotfiles commit -m "state: persist {os, machine, modules} selection"
```

---

## Task 5: flat selector + nested profile picker (TUI)

**Files:**
- Modify: `internal/tui/selector.go`
- Create: `internal/tui/picker.go`

**Interfaces:**
- Consumes: `module.Module`, huh.
- Produces: `tui.SelectModules(mods []*module.Module, preselected map[string]bool) ([]string, error)` (now a single flat multiselect over the passed `mods` — caller pre-filters to valid); `tui.PickProfile(defaultOS string) (osName, machine string, err error)`.

- [ ] **Step 1: Rewrite SelectModules to a single flat list**

Replace the per-tag loop in `internal/tui/selector.go` with one multiselect. Delete `GroupByTag` (and its usage). Keep `unique`:
```go
// SelectModules renders one flat multi-select over mods (already filtered to
// the profile's valid set by the caller). Names in preselected start checked.
func SelectModules(mods []*module.Module, preselected map[string]bool) ([]string, error) {
	sorted := make([]*module.Module, len(mods))
	copy(sorted, mods)
	sort.Slice(sorted, func(i, j int) bool {
		pi, pj := preselected[sorted[i].Name], preselected[sorted[j].Name]
		if pi != pj {
			return pi // preselected (defaults) first
		}
		return sorted[i].Name < sorted[j].Name
	})

	var options []huh.Option[string]
	chosen := []string{}
	for _, m := range sorted {
		label := m.Name
		if m.Description != "" {
			label = fmt.Sprintf("%s — %s", m.Name, m.Description)
		}
		options = append(options, huh.NewOption(label, m.Name))
		if preselected[m.Name] {
			chosen = append(chosen, m.Name)
		}
	}

	field := huh.NewMultiSelect[string]().
		Title(Title.Render("Modules")).
		Options(options...).
		Value(&chosen)
	if err := huh.NewForm(huh.NewGroup(field)).Run(); err != nil {
		return nil, err
	}
	return unique(chosen), nil
}
```

- [ ] **Step 2: Add the nested picker in picker.go**

```go
package tui

import "github.com/charmbracelet/huh"

// PickProfile asks for OS (default from detected), then Machine when OS=Arch.
// Returns internal os id ("arch"/"ubuntu") and machine ("desktop"/"laptop"/"").
func PickProfile(defaultOS string) (string, string, error) {
	osChoice := defaultOS
	if osChoice != "arch" {
		osChoice = "ubuntu"
	}
	if err := huh.NewSelect[string]().
		Title("Which OS?").
		Options(
			huh.NewOption("Arch", "arch"),
			huh.NewOption("WSL", "ubuntu"),
		).
		Value(&osChoice).Run(); err != nil {
		return "", "", err
	}
	if osChoice != "arch" {
		return "ubuntu", "", nil
	}
	machine := "desktop"
	if err := huh.NewSelect[string]().
		Title("Desktop or Laptop?").
		Options(
			huh.NewOption("Desktop", "desktop"),
			huh.NewOption("Laptop", "laptop"),
		).
		Value(&machine).Run(); err != nil {
		return "", "", err
	}
	return "arch", machine, nil
}
```

- [ ] **Step 3: Build (TUI is huh-driven; no unit test — covered by live check in Task 6)**

```bash
cd /home/dalton/.dotfiles && gofmt -w . && go build ./...
```
Expected: builds. `SelectModules`'s new signature (dropped tag grouping) may break `install.go` — that is rewired in Task 6; if the build fails only in `cmd/quill/install.go` on `SelectModules`/`GroupByTag`, that is expected and closed by Task 6. To keep this task's commit green, make the minimal `install.go` edit to call `SelectModules(module.FilterValid(ctx.Modules, prof.OS, prof.Machine), preselected)` using the temporary `prof` from Task 1's scaffolding.

- [ ] **Step 4: Run full tests**

```bash
cd /home/dalton/.dotfiles && go test ./...
```
Expected: PASS (no TUI unit tests; everything else green).

- [ ] **Step 5: Commit**

```bash
cd /home/dalton/.dotfiles && gofmt -w .
git -C /home/dalton/.dotfiles add -A
git -C /home/dalton/.dotfiles commit -m "tui: flat module multiselect + nested OS/machine picker"
```

---

## Task 6: wire install.go to the picker

**Files:**
- Modify: `cmd/quill/install.go`, `cmd/quill/context.go`

**Interfaces:**
- Consumes: `tui.PickProfile`, `profile.Load`, `module.FilterValid`/`Preselect`, `state.LoadState`/`SaveState`, `tui.SelectModules`.

- [ ] **Step 1: Resolve the profile via the picker**

In `install.go`'s `RunE`, after `loadCtx()`, remove the temporary `loadProfileByOS` scaffolding and the old banner/preselect block. Insert:
```go
osName, machine, err := tui.PickProfile(ctx.OS)
if err != nil {
	return err
}
prof, err := profile.Load(filepath.Join(ctx.RepoRoot, "profiles"), osName, machine)
if err != nil {
	return err
}
ctx.OS = osName // the pick drives gating

statePath, _ := state.DefaultPath()
saved, _ := state.LoadState(statePath)
candidates := prof.Modules
if saved != nil && len(saved.Modules) > 0 {
	candidates = saved.Modules
}
valid := module.FilterValid(ctx.Modules, osName, machine)
preselected := module.Preselect(valid, candidates)

selected, err := tui.SelectModules(valid, preselected)
if err != nil {
	return err
}
```
Then keep the existing deps/confirm/plan/apply/install.sh flow, but use `prof` in place of `ctx.Host` (`runner.FilterByHost(ordered, prof.Name)`, `runner.BuildPlan(ordered, prof, ctx.OS)`, `runner.RunInstallSh(p.Module, ctx.OS, prof.Name)`), and the confirm summary `"... on profile %s ..."` with `prof.Name`.

- [ ] **Step 2: Persist the full selection**

Replace the final `SaveSelection` call with:
```go
_ = state.SaveState(statePath, &state.Selection{OS: osName, Machine: machine, Modules: selected})
```

- [ ] **Step 3: Add imports**

Ensure `install.go` imports `profile` (`github.com/DaltonDayton/dotfiles/internal/profile`), `module`, `state`, `tui`, `filepath`. Remove now-unused `tui.Banner` if the banner block was deleted (leave `Banner` defined in tui; just stop calling it here).

- [ ] **Step 4: Build + test + live check**

```bash
cd /home/dalton/.dotfiles && gofmt -w . && go build -o ./bin/quill ./cmd/quill && go test ./...
```
Live (human, on this WSL box): `./bin/quill install` → OS select defaults to WSL, no machine step, flat module list **without** hyprland/fonts/gaming/obsidian/razer/solaar, defaults (`git shell tmux neovim ai python asdf`) pre-checked. Cancel before applying (or proceed). Confirm `~/.local/state/quill/last_selection.json` gained `"os":"ubuntu"`.

- [ ] **Step 5: Commit**

```bash
cd /home/dalton/.dotfiles && gofmt -w .
git -C /home/dalton/.dotfiles add -A
git -C /home/dalton/.dotfiles commit -m "install: nested OS/machine picker + flat validity-filtered selector"
```

---

## Task 7: wire apply.go with flags + state + first-run prompt

**Files:**
- Modify: `cmd/quill/apply.go`, `cmd/quill/context.go` (remove leftover scaffolding), `cmd/quill/status.go` if it still references a profile

**Interfaces:**
- Consumes: `profile.NormalizeOS`/`Load`, `state.LoadState`/`SaveState`, `tui.PickProfile`, `host.DetectOS`.
- Produces: `apply` resolving profile by flags → state → prompt, then persisting.

- [ ] **Step 1: Add `--os`/`--machine` flags**

In `newApplyCmd`, capture flags:
```go
var flagOS, flagMachine string
cmd := &cobra.Command{ ... }
cmd.Flags().StringVar(&flagOS, "os", "", "profile OS: arch|wsl (overrides saved)")
cmd.Flags().StringVar(&flagMachine, "machine", "", "profile machine: desktop|laptop (arch only)")
return cmd
```
(Restructure `newApplyCmd` to declare `cmd` then attach flags then `return cmd`.)

- [ ] **Step 2: Resolve the profile in priority order**

At the top of `RunE` (after `loadCtx`), before building the module list:
```go
statePath, _ := state.DefaultPath()
saved, _ := state.LoadState(statePath)

var osName, machine string
switch {
case flagOS != "":
	osName, machine = profile.NormalizeOS(flagOS), flagMachine
case saved != nil && saved.OS != "":
	osName, machine = saved.OS, saved.Machine
default:
	// never run: prompt once, then persist below
	osName, machine, err = tui.PickProfile(host.DetectOS())
	if err != nil {
		return err
	}
}
prof, err := profile.Load(filepath.Join(ctx.RepoRoot, "profiles"), osName, machine)
if err != nil {
	return err
}
ctx.OS = osName
```
Then replace every `ctx.Host` usage with `prof` (`ctx.Host.Modules`→`prof.Modules`, `FilterByHost(ordered, prof.Name)`, `BuildPlan(ordered, prof, ctx.OS)`, `RunInstallSh(p.Module, ctx.OS, prof.Name)`).

- [ ] **Step 3: Persist the resolved profile**

After a successful resolve (before or after the apply loop; simplest right after `prof` is loaded), persist so future runs are non-interactive. Preserve the previously-saved module list if present, else the profile defaults:
```go
mods := prof.Modules
if saved != nil && len(saved.Modules) > 0 {
	mods = saved.Modules
}
_ = state.SaveState(statePath, &state.Selection{OS: osName, Machine: machine, Modules: mods})
```

- [ ] **Step 4: Wire status.go with a non-interactive resolver**

`status.go` is read-only and must never prompt. Add a shared helper to `context.go` and use it from `status.go`:
```go
// resolveProfileNonInteractive picks the profile without prompting: saved state
// if present, else the detected OS with a default machine (arch → desktop).
// Used by status (always) and by apply when it has saved state.
func resolveProfileNonInteractive(root string, saved *state.Selection) (*manifest.Profile, string, string, error) {
	osName, machine := host.DetectOS(), ""
	if saved != nil && saved.OS != "" {
		osName, machine = saved.OS, saved.Machine
	}
	if osName == "arch" && machine == "" {
		machine = "desktop"
	}
	p, err := profile.Load(filepath.Join(root, "profiles"), osName, machine)
	return p, osName, machine, err
}
```
In `status.go`'s `RunE`, after `loadCtx`, resolve and use it:
```go
sp, _ := state.DefaultPath()
saved, _ := state.LoadState(sp)
prof, osName, _, err := resolveProfileNonInteractive(ctx.RepoRoot, saved)
if err != nil {
	return err
}
ctx.OS = osName
```
then replace `ctx.Host.Modules`→`prof.Modules`, `FilterByHost(ordered, prof.Name)`, `BuildActions(m, prof, ctx.OS)`.

- [ ] **Step 5: Remove Task-1 scaffolding**

Delete `loadProfileByOS` from `context.go` (no longer referenced). Ensure `context.go` still compiles (`appCtx.Profile` is now unused — drop the field, keeping `RepoRoot`, `Modules`, `OS`).

- [ ] **Step 6: Build + test + live check**

```bash
cd /home/dalton/.dotfiles && gofmt -w . && go build -o ./bin/quill ./cmd/quill && go test ./...
```
Live (human): with a saved state present, `./bin/quill apply git` runs non-interactive. `./bin/quill apply --os arch --machine laptop git` resolves the arch-laptop profile (on this WSL box the arch package actions gate out, which is fine — verifies resolution + gating). Remove the state file and run `./bin/quill apply git` → prompts once, then a second run is silent. `./bin/quill status` runs non-interactively (no prompt).

- [ ] **Step 7: Commit**

```bash
cd /home/dalton/.dotfiles && gofmt -w .
git -C /home/dalton/.dotfiles add -A
git -C /home/dalton/.dotfiles commit -m "apply: resolve profile via flags/state/prompt; drop hostname scaffolding"
```

---

## Done criteria

- [ ] `manifest.Module` has `OS`/`Machine`; `manifest.Profile` (renamed from `Host`) has `OS`/`Machine`; `ParseProfile` parses them. Parse tests cover the new fields.
- [ ] `hosts/` is gone; `profiles/` holds `arch-desktop.toml`, `arch-laptop.toml`, `wsl.toml` with the exact module lists + os/machine from the spec.
- [ ] `modules/{fonts,hyprland,obsidian,solaar}` carry `os=["arch"]`; `modules/{gaming,razer}` carry `os=["arch"]` + `machine=["desktop"]`.
- [ ] `module.ValidFor/FilterValid/Preselect`, `profile.NormalizeOS/FileName/Load`, `state.Selection/LoadState/SaveState` all implemented with passing table tests.
- [ ] `quill install` shows the nested OS(→machine) picker then ONE flat multiselect; OS-invalid modules hidden; defaults preselected; choice persisted as `{os,machine,modules}`.
- [ ] `quill apply` resolves profile by `--os`/`--machine` → persisted state → first-run prompt; persists; non-interactive thereafter; hostname `Detect`/`Load` deleted.
- [ ] `GroupByTag` removed from the install path; tag-based groups gone.
- [ ] `go build ./...` and `go test ./...` green; `gofmt` clean.
- [ ] Arch path behavior for per-action gating unchanged (`osMatch`/`osAllowsManager` untouched).

## Human verification (post-merge)

- Fresh-feel: delete `~/.local/state/quill/last_selection.json`, run `quill install` on this WSL box → WSL preselected, clean flat list, install proceeds.
- `quill apply` afterward runs with no prompts.
- (If an Arch box is available) `quill install` → Arch → Desktop/Laptop submenu → full module list incl. hyprland/gaming.
