# Project: `quill`

A Go CLI that declaratively manages the user's Arch Linux setup — packages, dotfiles, services, host-specific tweaks. Binary name: `quill`. Go module: `github.com/DaltonDayton/dotfiles`.

## Where things live

**Code:**
- **Go binary entry:** `cmd/quill/main.go`
- **Internal packages:** `internal/{manifest,module,host,template,action,runner,state,tui}`
- **Modules (dotfile units):** `modules/<name>/module.toml` + `files/` + optional `install.sh`
- **Host profiles:** `hosts/<hostname>.toml`
- **Bootstrap entry:** `bootstrap.sh`

**Specs and plans** (always read the plan before implementing a task — it specifies exact code, file paths, and test shapes):

| Feature | Spec | Plan |
|---|---|---|
| Quill core (Go CLI, action types, runner, TUI) | `docs/superpowers/specs/2026-04-21-quill-design.md` | `docs/superpowers/plans/2026-04-21-quill-implementation.md` |
| `hyprland` mega-module (WM, bar, terminal, theming engine) | `docs/superpowers/specs/2026-04-25-hyprland-module-design.md` | `docs/superpowers/plans/2026-04-25-hyprland-module-implementation.md` |
| Theme switcher (Super+D / Super+Shift+D, indirection layer, matugen-as-theme) | `docs/superpowers/specs/2026-04-25-theme-switcher-design.md` | `docs/superpowers/plans/2026-04-25-theme-switcher.md` |
| Neovim theme integration (per-theme `nvim.lua`, dispatcher, SIGUSR1 reload) | (extends theme-switcher spec) | `docs/superpowers/plans/2026-04-28-nvim-theme-integration.md` |
| WSL/Ubuntu foundation + shell module | `docs/superpowers/specs/2026-06-08-wsl-ubuntu-foundation-shell-design.md` | `docs/superpowers/plans/2026-06-08-wsl-ubuntu-foundation-shell.md` |

## User context

- Primary OS: **Arch Linux** (desktop + laptop). Also uses **WSL/Ubuntu** for some work; Ubuntu is a **supported (in-progress) target** managed by the same module/host model — OS detection, an `apt` driver, and the `shell` module are done; Arch remains the primary platform.
- **Learning Go** — prefers idiomatic, widely-used patterns over clever abstractions. When introducing a Go pattern the user may not have seen, a short one-line comment explaining *why* is welcome; `what` it does should be self-evident from the code.
- Shell: **zsh**. Window manager: **Hyprland**. AUR helper: **yay** (bootstrapped from source by `quill install` if missing).
- Editor preferences live inside the `neovim` module (`modules/neovim/files/nvim/`).

## Conventions

**Idempotency is the contract.** Every action executor (`internal/action/*.go`) implements the `Action` interface with `Describe()`, `Check() (bool, error)`, `Apply() error`. `Check` returns `true` iff the system is already in the desired state — the runner then skips `Apply`. Stateless — no system-state file. The only persisted state is `~/.local/state/quill/last_selection.json`, which is a UI preference (remembers selector defaults), not system truth.

**Declarative first, escape hatch when needed.** Modules describe their work in `module.toml` (packages / symlinks / commands / files / services / directories). When declarative doesn't fit (SSH key generation, GPU detection, interactive wizards), drop into `modules/<name>/install.sh`. Scripts must self-check for idempotency (exit 0 when already applied).

**Install.sh ordering.** All modules' declarative actions run first (inside the TUI for `install`, inline for `apply`). Then *after* the TUI releases the terminal, install.sh scripts run in module order with inherited stdio — so they can use the real TTY for `sudo`, interactive prompts, etc. Trade-off: a module's declarative action cannot depend on an earlier module's install.sh output, because all declarative work finishes before any script runs.

**TDD per the plan.** Each `internal/*` package is introduced alongside its `_test.go` in the same task. Tests use `t.TempDir()` for filesystem work and inject fakes for shell-outs (see `internal/action/services.go`'s `var systemctl` and `internal/action/packages.go`'s `var pkgDrivers`). Run `go test ./...` before committing a task.

**File scope.** One responsibility per file. Action types get their own file (`symlinks.go`, `packages.go`, …). TUI presentation lives in `internal/tui/` and is a pure consumer of `internal/runner` events — `runner` never imports `tui`.

**Sudo is primed once, upfront.** The `pacman` driver uses `sudo -n` so it never prompts mid-action (a prompt inside the Bubble Tea progress view would mangle it). Before `install`/`apply` starts the runner, the CLI builds the plan via `runner.BuildPlan` and primes sudo (interactive `sudo -v`) when *either* `runner.PlanNeedsSudo` (a declarative action implements `NeedsSudo() bool` and its `Check` says it'll run) *or* `runner.PlanInstallShNeedsSudo` (a module's `install.sh` contains a `sudo` invocation outside of comments) returns true. Covering install.sh too means the user isn't ambushed by a password prompt at the end of the run after the TUI exits. `NeedsSudo` is a structural interface — action types opt in by implementing the method; it isn't part of the core `Action` contract.

**No `sudo` surprises.** The `pacman` driver uses `sudo -n`, which errors out rather than prompting. Users are expected to have run `sudo -v` before `quill apply`, or to be in a context where passwordless sudo is configured. Don't paper over this with prompts.

## Build, run, test

```bash
# build
go build -o ./bin/quill ./cmd/quill

# test
go test ./...
go test ./internal/action/... -v        # iterating on a package

# format (always before commit)
gofmt -w .

# run
./bin/quill list
./bin/quill status
./bin/quill apply            # non-interactive, host-manifest modules
./bin/quill apply git        # specific module(s)
./bin/quill install          # interactive TUI
./bin/quill path             # install to ~/.local/bin + patch .zshrc
```

## When adding a new action type

1. Add the struct to `internal/manifest/schema.go` and the `[[...]]` slice to the `Module` struct.
2. Add a parser test case in `internal/manifest/parse_test.go`.
3. Create `internal/action/<name>.go` + `_test.go` implementing the `Action` interface.
4. Wire it into `internal/runner/runner.go:BuildActions` in the right execution position (directories → packages → symlinks → files → commands → services is the canonical order — new types go where their dependencies are already satisfied).
5. Document the new verb in the spec and (if user-facing) in `README.md`.

## When adding a new module

1. `mkdir modules/<name>` and write `modules/<name>/module.toml`.
2. Put any files to symlink under `modules/<name>/files/`. Use `.tmpl` suffix for templated files (host vars available as `{{ .Vars.whatever }}`, hostname as `{{ .Name }}`).
3. If the module needs imperative logic, add `modules/<name>/install.sh` (`chmod +x`).
4. Add the module name to the relevant `hosts/<hostname>.toml` modules list.
5. Smoke-test: `./bin/quill apply <name>` → rerun to confirm idempotency.

## Agent workflow

This project uses the `superpowers` skill set. New tasks that modify behavior should go through:

- **brainstorming** → design lands in `docs/superpowers/specs/`
- **writing-plans** → implementation plan lands in `docs/superpowers/plans/`
- **subagent-driven-development** or **executing-plans** → execute task by task with checkpoint reviews

Don't skip the plan for multi-step changes. One-line fixes are fine to do inline.

## Coding preferences

- Short comments only where *why* is non-obvious. No comment headers, no section banners in code.
- Prefer returning errors up the stack over logging+continuing. The runner is the only layer that decides what to do with errors.
- Wrap errors with `fmt.Errorf("...: %w", err)` including the operation context. No bare error returns for wrapped calls.
- Keep test helpers (fakes, fixtures) in the same `_test.go` as the tests that use them. Don't introduce `testutil` packages until two packages need the same fake.
- No external CLI parsers beyond `cobra` without discussion. No logging framework; use `fmt.Println`/`fmt.Fprintln(os.Stderr, …)` from `cmd/` only. Library code returns, it doesn't print.

## Things that are explicitly out of scope (v1)

- macOS / non-Arch-non-Ubuntu distros
- Secrets management (age/sops)
- `quill remove` / uninstall paths
- Go-plugin escape hatch (shell is enough)
- Remote state / multi-machine sync beyond plain git

Listed in the spec's "Scope boundaries" section. If a request drifts into these, flag it before implementing.
