# Spec: OS/Machine install profile picker

**Date:** 2026-07-01
**Status:** Draft (pending review)

## Problem

`quill install` today keys everything on **hostname**: `host.Detect()` reads
`os.Hostname()`, `host.Load()` reads `hosts/<hostname>.toml`, and it hard-errors
(`host profile %q not found`) when no file matches. The selector then renders one
`huh.MultiSelect` per module tag — several stacked groups the user dislikes — and
every module is selectable regardless of OS (hyprland shows on WSL even though it
can't run there).

This makes provisioning a fresh machine awkward: a new WSL instance's hostname
won't be `Dalton`, so `quill install` aborts. The user wants to pick **what kind
of machine this is** explicitly instead of relying on hostname.

## Goal

Replace hostname selection with an explicit two-axis profile pick:

- **OS** — `Arch` or `WSL`. Drives package-manager gating and hides modules that
  can't run on the chosen OS.
- **Machine** — `Desktop` or `Laptop`. **Arch-only** (WSL has no split). Drives
  which machine-specific modules are valid/default.

The pick resolves to a curated default module set, shown as a **single flat
list** (no tag groups) with OS/machine-invalid modules hidden. Defaults are
preselected; the user toggles freely. The choice persists so `quill apply` is
non-interactive after the first run.

## Guiding principles

- **Additive to the OS abstraction already in place.** Per-action OS gating
  (`pacman/aur ⇒ arch`, `apt ⇒ ubuntu`, the `os = [...]` action field) is
  unchanged. This spec adds a *module-level* validity layer and a profile picker
  on top; it does not alter how actions gate.
- **Explicit over inferred.** The user states OS + machine; we stop guessing from
  hostname. `DetectOS()` is used only to pre-highlight the likely choice.
- **Learning-Go-friendly.** Plain structs, table-driven resolution, pure
  functions for anything testable. No clever abstractions.

## Data model

### New module fields (`manifest.Module`)

```go
OS      []string `toml:"os"`      // empty = any OS
Machine []string `toml:"machine"` // empty = any machine
```

A module is **valid** for a pick `(os, machine)` iff:
- `OS` is empty OR contains `os`, AND
- `Machine` is empty OR contains `machine` OR `machine == ""` (WSL: machine axis
  not applicable → machine filter is skipped).

Invalid modules are hidden from the selector and excluded from the plan.

**Population (from current module scan — for user review):**

| Module | OS | Machine | Reason |
|---|---|---|---|
| ai, asdf, git, neovim, python, shell, tmux | *(any)* | *(any)* | cross-platform (have apt blocks) |
| fonts, hyprland, obsidian, solaar | `["arch"]` | *(any)* | Arch-only (no apt block) |
| gaming, razer | `["arch"]` | `["desktop"]` | Arch-only + desktop hardware/gaming |

`hyprland` also carries the `desktop` tag today; the `machine` field is the
authoritative validity signal going forward (tags become cosmetic — see below).

### Profile files (`profiles/` — replaces `hosts/`)

Each combo gets one TOML. New `OS` and `Machine` fields on the profile struct;
`modules` is the curated preselect list (migrated verbatim from the current host
TOMLs).

```toml
# profiles/arch-desktop.toml
name    = "arch-desktop"
os      = "arch"
machine = "desktop"
modules = ["git","shell","tmux","fonts","asdf","python","neovim","hyprland","ai","obsidian","solaar","gaming","razer"]
[vars]
git_email       = "..."
git_signing_key = "~/.ssh/id_ed25519"
```

```toml
# profiles/arch-laptop.toml   (os=arch, machine=laptop)
modules = ["git","shell","tmux","fonts","asdf","python","neovim","hyprland","ai","obsidian","solaar"]
```

```toml
# profiles/wsl.toml           (os=ubuntu, machine omitted)
modules = ["git","shell","tmux","neovim","ai","python","asdf"]
```

`os = "ubuntu"` in `wsl.toml` (not `"wsl"`) so it matches `DetectOS()` and the
existing per-action manager gating (`apt ⇒ ubuntu`). The picker *label* is "WSL";
the stored/gating value is `ubuntu`.

### Renames (hostname is gone → keep names honest)

- `hosts/` → `profiles/`.
- `manifest.Host` → `manifest.Profile` (gains `OS`, `Machine`).
- `host.Detect()`/`host.Load()` (hostname) retired; `host.DetectOS()` stays.
- Runner name-gating (`FilterByHost`, per-action `hosts = [...]` /`hostMatch`)
  repurposed to the **profile name** (`arch-desktop`, etc.). A quick scan shows
  no module currently uses `hosts = [...]`, so this is a rename, not a behavior
  change; the plan verifies.

## Picker flow (`quill install`)

1. **OS select** (`huh.NewSelect`): `Arch` / `WSL`, default highlighted from
   `DetectOS()` (`arch → Arch`, `ubuntu → WSL`).
2. **Machine select** — only if OS = Arch: `Desktop` / `Laptop`. WSL skips this
   (machine = "").
3. Resolve `(os, machine)` → profile file (`arch-desktop` / `arch-laptop` /
   `wsl`). Load its `modules` as the default preselect set (or
   `last_selection.json` if present, intersected with valid modules).
4. **Single flat `huh.NewMultiSelect`** over the OS/machine-**valid** modules
   only. Sorted defaults-first then alphabetical. Space toggles. (Replaces the
   per-tag multi-field form; `GroupByTag` is removed.)
5. Confirm → resolve deps → build plan (gated by resolved `os`) → declarative
   apply in TUI → install.sh post-TUI → persist `{os, machine, modules}`.

## Persistence & `quill apply`

`last_selection.json` extends to:

```json
{ "os": "ubuntu", "machine": "", "modules": ["git","shell", "..."] }
```

`quill apply [modules...]` resolves the profile in priority order:

1. **Flags** `--os arch|wsl` and `--machine desktop|laptop` → use, then persist.
   (`--os wsl` normalizes to `ubuntu`. `--machine` ignored when os resolves to
   ubuntu.)
2. **Persisted state** → use silently (the normal, non-interactive case).
3. **Never run** (no flags, no state) → interactive prompt: the same OS (+machine
   if Arch) select as install, then persist. After this once, apply is
   non-interactive forever.

If flags give OS=arch but no `--machine` and there's no persisted machine, apply
prompts for machine only (or errors with a clear message in a non-TTY context —
plan decides the exact copy).

Resolved `os` → `ctx.OS` (package gating); profile name → `ctx.Profile.Name`
(name-gating). `DetectOS()` no longer drives gating directly — the explicit/
persisted pick does — but remains the default for the picker.

## Tags

Tags stop driving the selector (no more groups). They remain in the schema and
may be used later for sort/badges, but this spec removes `GroupByTag` from the
install path. No module edits needed for tags.

## Testing

Pure, TTY-free units (extract selection logic from the huh wiring):

- `ModuleValidFor(mod, os, machine) bool` — table test: hyprland invalid on
  ubuntu; gaming invalid on arch+laptop; git valid everywhere; wsl (machine="")
  skips machine filter.
- Profile resolve: `(os, machine) → profile file`, incl. WSL ignoring machine;
  unknown combo errors.
- Preselect: `last_selection` intersected with valid modules; falls back to
  profile `modules` on first run; invalid persisted modules dropped.
- `manifest` parse tests: `os`/`machine` on Module, `os`/`machine` on Profile.
- Flag/state precedence for `apply`: flag > state > prompt; `--os wsl` →
  `ubuntu`; persistence round-trips `{os, machine, modules}`.

Live (human): `quill install` on this WSL box → OS defaults to WSL, no machine
step, flat list without hyprland/fonts/gaming/etc., defaults preselected;
`quill apply` afterward runs non-interactive; `quill apply --os arch --machine
laptop` (dry, on this box) resolves the arch-laptop profile.

## Scope boundaries

**In scope:** two-axis picker, module `os`/`machine` validity + hiding, `profiles/`
combo files, flat selector, persisted profile, `apply` flag/state/prompt
resolution, `hosts`→`profiles` rename.

**Out of scope:**
- README `startover`-branch bootstrap note (going away when startover merges to
  main).
- The binary-refresh slice.
- Any new module behavior; gaming/razer/hyprland internals unchanged.
- macOS / other distros; secrets; `quill remove`.

## Open questions

None. OS/machine axes, Arch-only machine axis, per-combo profile TOMLs,
hidden (not disabled) invalid modules, and apply flag/state/prompt precedence all
resolved during brainstorming.
