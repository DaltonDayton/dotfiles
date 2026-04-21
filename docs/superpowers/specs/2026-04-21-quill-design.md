# Dotfiles Manager (`quill`) — Design

## Context

The user is starting fresh on their `.dotfiles` repo (the repo was wiped with a "start over" commit). They want a Go-based dotfiles/machine manager that:

- Fully bootstraps a fresh Arch install (packages, configs, services, host-specific tweaks)
- Uses Charm's TUI tooling (Bubble Tea + Huh + Lip Gloss) for a nice interactive selector and progress view
- Is modular — each concern (git, zsh, hyprland, …) is its own unit
- Is idempotent — safe to re-run, auto-heals drift
- Targets Arch (desktop + laptop) for v1. Multi-host differences are minor (monitor configs, small tweaks). WSL/Ubuntu support is a future concern; architecture should not preclude it.

The user is learning Go and wants idiomatic / best-practice structure.

## Approach (one-line summary)

A single-binary Go tool that reads **declarative TOML manifests** per module, runs **idempotent actions** (packages, symlinks, commands, files, services, directories), uses **host profiles** for desktop vs laptop, and drives the whole thing through a **Charm TUI** with an interactive module selector and live install progress. An optional **`install.sh`** per module serves as the escape hatch for logic that doesn't fit declaratively.

## Repo layout

```
.dotfiles/
├── bootstrap.sh                 # curl-able fresh-install entry
├── cmd/quill/main.go           # CLI entry
├── go.mod
├── internal/
│   ├── module/                  # manifest parsing + Module type
│   ├── action/                  # executors: packages/symlinks/commands/files/services/directories
│   ├── host/                    # hostname detection + profile loading
│   ├── template/                # Go template rendering with host vars
│   ├── tui/                     # Huh forms + Bubble Tea progress + Lip Gloss styles
│   └── runner/                  # orchestrator: resolve deps → select → apply → report
├── modules/
│   ├── git/
│   │   ├── module.toml
│   │   ├── files/               # dotfiles to symlink (optionally .tmpl)
│   │   └── install.sh           # optional escape hatch
│   ├── zsh/…
│   └── hyprland/…
└── hosts/
    ├── desktop.toml             # enabled modules + template vars
    └── laptop.toml
```

## Module manifest (`modules/<name>/module.toml`)

Every action type supports idempotency via a natural check.

```toml
name = "hyprland"
description = "Hyprland window manager + config"
tags = ["desktop"]                # used for grouping in the selector
depends_on = ["waybar"]           # auto-pulled in if selected
hosts = ["desktop", "laptop"]     # optional; default = all

[[packages]]
manager = "paru"                  # or "pacman", "yay", "flatpak"
names = ["hyprland", "xdg-desktop-portal-hyprland"]

[[symlinks]]
src = "files/hyprland.conf"
dst = "~/.config/hypr/hyprland.conf"

# whole-file swap — same dst, different src per host
[[symlinks]]
src = "files/monitors.desktop.conf"
dst = "~/.config/hypr/monitors.conf"
hosts = ["desktop"]

[[symlinks]]
src = "files/monitors.laptop.conf"
dst = "~/.config/hypr/monitors.conf"
hosts = ["laptop"]

# templated — .tmpl suffix renders with host vars ({{ .Host.Monitor }}, etc.)
[[symlinks]]
src = "files/hyprland.conf.tmpl"
dst = "~/.config/hypr/hyprland.conf"

[[commands]]
run = "systemctl --user enable hyprpaper.service"
check = "systemctl --user is-enabled hyprpaper.service"   # idempotency gate

[[services]]
name = "hyprpaper.service"
scope = "user"                    # "user" | "system"
state = "enabled"                 # "enabled" | "started" | "enabled+started"

[[directories]]
path = "~/.config/hypr"
mode = "0755"

[[files]]
dst = "~/.config/hypr/variables.conf"
content = "$mod = SUPER"          # or content_from = "files/variables.conf"
mode = "0644"
```

**Idempotency checks per action type:**
- `packages` — query the manager (`pacman -Q <name>` etc.)
- `symlinks` — `readlink` matches expected target
- `commands` — user-supplied `check` command exits 0 ⇒ skip
- `files` — content hash matches
- `services` — `systemctl is-enabled` / `is-active`
- `directories` — `stat` matches mode

**Escape hatch**: `modules/<name>/install.sh` runs after declarative actions. Expected to self-check (exit 0 if already applied, do work if not). For rare logic like "generate SSH key if missing" or GPU detection.

## Host profiles (`hosts/<hostname>.toml`)

```toml
name = "laptop"
aur_helper = "paru"               # "paru" | "yay"

modules = [
  "git", "zsh", "neovim", "ssh",
  "hyprland", "waybar", "backlight",
]

[vars]
monitor = "eDP-1,preferred,auto,1.0"
user_email = "daltondayton1@gmail.com"
theme = "catppuccin-mocha"
```

- Selected automatically via `os.Hostname()` → matches `hosts/<hostname>.toml`
- `vars` map exposed to templates as `{{ .Host.monitor }}` etc.
- Action-level `hosts = [...]` filter layered on top for per-action gating

## Charm TUI flow (`quill install`)

1. **Banner + host detection** (Lip Gloss) — `Detected host: laptop — using hosts/laptop.toml`
2. **Module selector** (Huh multi-select, grouped by tag):
   ```
   Essential      [x] git   [x] zsh   [x] ssh
   Dev            [x] neovim   [ ] docker
   Desktop        [x] hyprland   [x] waybar   [x] backlight
   Optional       [ ] obsidian
   ```
   - Defaults: host manifest selections on first run
   - Subsequent runs: preselect from `~/.local/state/quill/last_selection.json`
3. **Dependency resolution** — auto-add missing deps, show which were added
4. **Confirm** (Huh) — "Will apply 12 modules. Proceed?"
5. **Progress view** (Bubble Tea):
   ```
   ✓ git          (3 pkgs, 4 symlinks)
   ✓ zsh          (2 pkgs, 3 symlinks, 1 cmd)
   ⏳ hyprland     (installing paru packages…)
   ⏸ waybar       (pending)
   ```
6. **Summary** — applied / skipped / failed counts, errors expanded

## Non-interactive commands

- `quill apply` — apply all host-manifest modules, no prompts (re-runs, scripting)
- `quill apply git zsh` — specific modules
- `quill list` — all modules + applied status
- `quill status` — diff current vs desired
- `quill path` — symlink `~/.dotfiles/bin/quill` → `~/.local/bin/quill`, and append `~/.local/bin` to `.zshrc` PATH if missing (offered during interactive install)

## Bootstrap (`bootstrap.sh`)

Single curl-able entrypoint on a fresh Arch install:

```sh
curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/bootstrap.sh | bash
```

Does roughly:
1. `sudo pacman -Sy --needed git go base-devel`
2. `git clone <repo> ~/.dotfiles`
3. `cd ~/.dotfiles && go build -o ./bin/quill ./cmd/quill`
4. `./bin/quill install`

Stays ~30 lines — easy to audit before piping to bash.

## Idempotency model

Stateless. Every run re-checks current state before acting. No system state file. The only stored state is `~/.local/state/quill/last_selection.json` (purely a UI preference for the selector). Self-healing: if you manually delete a symlink, next run restores it.

## Critical files to create

- `cmd/quill/main.go` — CLI entry, cobra or stdlib `flag`
- `internal/module/manifest.go` — TOML schema + parser (use `github.com/BurntSushi/toml` or `pelletier/go-toml`)
- `internal/module/module.go` — `Module` type + loader (walks `modules/`)
- `internal/action/{packages,symlinks,commands,files,services,directories}.go` — one file per action, each with `Check()` + `Apply()`
- `internal/host/host.go` — hostname detection + `hosts/<name>.toml` loader
- `internal/template/render.go` — `text/template` wrapper with host var context
- `internal/tui/selector.go` — Huh multi-select grouped by tag
- `internal/tui/progress.go` — Bubble Tea model for live install progress
- `internal/tui/styles.go` — Lip Gloss styles
- `internal/runner/runner.go` — orchestrator; resolves deps, filters by host, drives TUI, calls actions
- `bootstrap.sh` — fresh-install entry

**Reusable libraries:**
- `github.com/charmbracelet/bubbletea` — progress TUI
- `github.com/charmbracelet/huh` — selector + confirm forms
- `github.com/charmbracelet/lipgloss` — styling
- `github.com/BurntSushi/toml` — manifest parsing
- `github.com/spf13/cobra` (optional) — CLI command structure

## Scope boundaries (v1)

**In scope:**
- Arch only (desktop + laptop hosts)
- Six action types (packages, symlinks, commands, files, services, directories)
- Declarative TOML + optional `install.sh` escape hatch
- Interactive TUI + non-interactive commands
- Stateless idempotency
- `curl | bash` bootstrap

**Out of scope (future):**
- WSL/Ubuntu support (architecture must not preclude — package managers are already abstracted per-action)
- Secrets management (age/sops)
- Uninstall/removal paths
- Go-plugin escape hatch (shell is enough for v1)
- Remote state / multi-machine sync beyond git

## Verification plan

End-to-end test in a disposable environment (Arch VM or container):

1. **Unit-level**: each `internal/action/*.go` has tests with temp dirs / mocked commands verifying `Check()` correctly reports state, `Apply()` is idempotent (run twice, second run is a no-op)
2. **Manifest parsing**: round-trip TOML fixtures through `internal/module/manifest.go`
3. **Dry-run end-to-end**: `quill status` on a fresh Arch VM shows all modules as "not applied"
4. **Full install**: `./bootstrap.sh` on a fresh Arch VM completes without errors; all selected modules report applied
5. **Idempotency**: immediately re-run `quill apply` — every action reports skipped
6. **Drift repair**: manually delete a symlink, re-run `quill apply`, confirm it's restored
7. **Host switch**: clone the same repo on desktop + laptop, confirm only host-appropriate modules + files are applied
8. **Interactive flow**: manually walk through `quill install` and confirm selector grouping, dependency resolution, progress view, and summary all render correctly

## Open items deferred to implementation

- Exact module set to port (git, zsh, neovim, ssh, hyprland, waybar, etc.) — decided as each module is built
- Cobra vs stdlib `flag` for the CLI — small call; pick whichever feels cleaner when writing `cmd/quill/main.go`
- `install.sh` parallelism with declarative actions — for v1, serialize: declarative actions first, then `install.sh` last
