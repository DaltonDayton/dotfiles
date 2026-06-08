# Spec: WSL/Ubuntu support — foundation + shell module

**Date:** 2026-06-08
**Status:** Draft (pending review)

## Problem

`quill` targets Arch Linux only. The user also works on a headless **Ubuntu
24.04 (WSL)** machine (hostname `Dalton`) and wants quill to manage it using
the same module/host model — *without* changing anything about how the existing
`archlinux` / `archlaptop` hosts behave.

Today there is no concept of "which OS am I on" anywhere in the codebase. Gating
is by hostname only (`hosts = [...]`), and every `[[packages]]` block hardcodes
an Arch package manager (`pacman` / `aur`→`yay` / `flatpak`). There is no `apt`
driver, and `install.sh` scripts are invoked via `sh` — which is `bash` on Arch
but `dash` on Ubuntu, so the scripts' bashisms (`[[ ]]`, arrays) silently break
there.

This is the **first slice** of a larger, multi-slice WSL/Ubuntu effort. It
delivers the core OS plumbing plus the **shell module**, because (a) shell is
what makes `startover` actually livable on the WSL box, and (b) the shell module
cannot work until the plumbing exists, so the two ship together. Subsequent
slices (git+asdf, tmux+neovim, python+ai) each get their own spec/plan and build
on this foundation.

## Guiding principle: additive, never a migration

The Arch path must behave **identically** after this change. Every new branch
keys off a detected `os` value that is `arch` for the existing hosts, so their
code path is unchanged. Concretely:

- A `[[packages]]` block with no Ubuntu counterpart still runs exactly as before
  on Arch.
- The new `os = [...]` action field defaults to empty = "all OSes", so existing
  modules are untouched.
- `BuildActions` gains an `os` parameter; for Arch hosts it is `"arch"` and all
  current filtering decisions are preserved.

## Convention: arch/ubuntu lines are always explicit

A hard requirement for this and every future slice. Nothing about *where code
runs* may be ambiguous:

1. **Every module documents an explicit arch-vs-ubuntu table** in this spec (and
   future module specs): which packages install via which manager, and what the
   `install.sh` ubuntu branch does.
2. **`install.sh` branches are always a full `case "$QUILL_OS"`** with *both*
   arms present, even when one is a no-op:
   ```sh
   case "$QUILL_OS" in
     arch)   : ;;            # handled by the pacman [[packages]] block
     ubuntu) npm i -g opencode-ai ;;
     *) echo "unsupported QUILL_OS=$QUILL_OS" >&2; exit 1 ;;
   esac
   ```
3. **Package blocks never rely on implicit OS knowledge beyond the manager.** The
   manager *is* the OS signal (see mapping below); a reader sees `manager = "apt"`
   and knows "Ubuntu only" without cross-referencing anything.

## The OS dimension

### Detection

A single new function detects the OS once at startup from `/etc/os-release`:

```
internal/host/os.go  (new, + os_test.go)

  func DetectOS() string   // "arch" | "ubuntu"
```

- Parse `/etc/os-release`, read `ID`. `ID=arch` → `"arch"`, `ID=ubuntu` →
  `"ubuntu"`.
- Fallback to `ID_LIKE` (e.g. an Ubuntu derivative reporting `ID_LIKE=ubuntu
  debian`) so close relatives still resolve to `"ubuntu"`.
- Unknown/unsupported → return the raw `ID` (or `"unknown"`); callers treat any
  value other than `arch`/`ubuntu` as unsupported and the gating simply runs
  nothing OS-specific. (We do **not** hard-error, so a future third OS degrades
  gracefully rather than bricking `quill list`.)

Detection is runtime-only — host profiles declare nothing about OS, matching how
the package manager is already abstracted at runtime. (An optional explicit
override was considered and deferred; revisit only if detection proves wrong.)

### Threading `os` through the runner

`DetectOS()` is called once in `cmd/quill` and threaded down:

- `runner.BuildPlan(...)` and `runner.BuildActions(m, host, os)` take the
  detected `os` string.
- `runner.RunInstallSh(m, os, hostName)` takes it too (see `$QUILL_OS` below).

`internal/runner` stays pure (no `os.Hostname`/`DetectOS` calls inside library
code); `cmd/` resolves the value and passes it in, consistent with how host
resolution already works.

## Package gating: manager implies OS

No new schema field for packages. `BuildActions` skips any `[[packages]]` block
whose manager does not apply to the detected OS. Mapping:

| Manager   | Valid on        |
|-----------|-----------------|
| `pacman`  | `arch`          |
| `yay`     | `arch`          |
| `aur`     | `arch` (→ yay)  |
| `apt`     | `ubuntu`        |
| `flatpak` | any OS          |

A module that needs a package on both OSes writes two blocks; quill runs only
the matching one:

```toml
[[packages]]
manager = "pacman"
names   = ["fd", "ripgrep"]

[[packages]]
manager = "apt"
names   = ["fd-find", "ripgrep"]
```

### The `apt` driver

`internal/action/packages.go` gains an `aptDriver` registered as `"apt"` in
`pkgDrivers` (same swap-for-fakes pattern used by tests):

- `IsInstalled(name)` → `dpkg -s <name>` exit 0 means installed. A non-zero
  exit (`*exec.ExitError`) means not installed; other errors propagate.
- `Install(names)` → `sudo apt-get install -y <names...>` via the existing
  `runSudo` helper. (Idempotent because `Apply` already filters to missing
  names before installing.)
- `NeedsSudo()` → `true` (so `apt` joins `pacman`/`yay` in the upfront
  `sudo -v` priming via `Packages.NeedsSudo`).

The manager→OS mapping lives next to the gating logic in
`internal/runner/build.go` as a small helper (e.g. `osAllowsManager(os,
manager) bool`), not inside the driver — gating is the runner's job; the driver
only knows how to install.

## General `os = [...]` gate for non-package actions

For the occasional non-package action that is OS-specific (a symlink, command,
file, service, or directory that should only exist on one OS), every action
struct gains an optional `OS []string \`toml:"os"\`` field, filtered exactly
like the existing `Hosts []string`:

```
internal/manifest/schema.go   add OS []string to Packages, Symlink, Command,
                              File, Service, Directory

internal/runner/build.go      osMatch(osList, currentOS) bool  // mirrors hostMatch;
                              empty list = matches all
```

In `BuildActions`, each action is included iff `hostMatch && osMatch`. For
packages, the manager→OS rule and `osMatch` both apply (AND); in practice
packages rely on the manager rule and leave `os` empty.

`empty os = all OSes` is the regression guard: existing Arch modules set nothing
and behave exactly as today.

## `$QUILL_OS` for install.sh + the `sh`→shebang fix

Two changes in `internal/runner/install_sh.go`:

1. **Export the OS (and host) into the script environment** so scripts can
   branch:
   ```go
   cmd.Env = append(os.Environ(),
       "QUILL_OS="+osName,
       "QUILL_HOST="+hostName)
   ```
2. **Honor the script's shebang instead of forcing `sh`.** Currently
   `exec.Command("sh", script)` runs under `/bin/sh`, which is `bash` on Arch
   but `dash` on Ubuntu — breaking `[[ ]]`/arrays. Change to invoke the script
   directly (`exec.Command(script)`) so its `#!/usr/bin/env bash` shebang
   governs on every OS. Scripts are already `chmod +x` per project convention;
   the plan adds a guard/test that they are executable.

`InstallShNeedsSudo`'s comment-aware `sudo ` grep is unaffected.

## Entry point: `bootstrap.sh` ubuntu branch

`bootstrap.sh` currently hardcodes `sudo pacman -Sy --needed --noconfirm git go
base-devel`. Add an OS branch around prerequisite install only; the
clone/build/launch tail is shared:

```sh
case "$(. /etc/os-release && echo "$ID")" in
  arch)   sudo pacman -Sy --needed --noconfirm git go base-devel ;;
  ubuntu) sudo apt-get update && sudo apt-get install -y git golang-go build-essential curl ;;
  *) echo "unsupported distro" >&2; exit 1 ;;
esac
```

(`bootstrap.sh` runs before quill is built, so it self-detects from
`/etc/os-release` rather than using `$QUILL_OS`.)

## New host: `hosts/Dalton.toml`

```toml
name    = "Dalton"
modules = ["git", "shell", "tmux", "neovim", "ai", "python", "asdf"]

[vars]
git_email       = "50755420+DaltonDayton@users.noreply.github.com"
git_signing_key = "~/.ssh/id_ed25519"
```

> The full module list is declared now so the host is complete, but **only the
> `shell` module is made Ubuntu-ready in this slice.** Running `quill apply` on
> `Dalton` before later slices land will succeed for `shell` and either no-op or
> partially apply the not-yet-converted modules. The shell-first sequencing (and
> `quill apply shell`) keeps that controllable.

## Shell module on Ubuntu

The `.zshrc` stays a **single shared file** (`modules/shell/files/.zshrc`,
symlinked to `~/.zshrc`) — it already guards most tool init on availability and
its PATH exports (`~/.asdf/shims`, `~/go/bin`, `~/.local/bin`) are valid on both
OSes. One hardening change: guard the unconditional `eval "$(starship init
zsh)"` and `eval "$(atuin init zsh)"` lines with `command -v` so a shell still
starts cleanly if a tool is briefly missing.

### Explicit arch/ubuntu package lines

| Tool       | Arch (`pacman`) | Ubuntu                                              |
|------------|-----------------|-----------------------------------------------------|
| `zsh`      | pacman          | `apt` (`zsh`)                                        |
| `less`     | pacman          | `apt` (`less`)                                       |
| `fzf`      | pacman          | `apt` (`fzf`)                                        |
| `nvtop`    | pacman          | `apt` (`nvtop`)                                      |
| `bat`      | pacman          | `apt` (`bat`, binary is `batcat`) + install.sh shim |
| `starship` | pacman          | install.sh: official installer → `~/.local/bin`     |
| `zoxide`   | pacman          | install.sh: official installer                      |
| `atuin`    | pacman          | install.sh: official installer                      |
| `eza`      | pacman          | install.sh: official deb repo or `cargo`            |
| `yazi`     | pacman          | install.sh: release binary or `cargo`               |

Resulting `module.toml` blocks:

```toml
[[packages]]
manager = "pacman"
names = ["zsh","starship","eza","zoxide","bat","less","fzf","yazi","atuin","nvtop"]

[[packages]]
manager = "apt"
names = ["zsh","less","fzf","nvtop","bat"]
```

### `modules/shell/install.sh`

Today it only sets the login shell to zsh (works on both OSes via `chsh`). Add a
`$QUILL_OS` branch for the non-apt long tail. Every installer is the
upstream-blessed path and must be idempotent (skip if `command -v` already finds
the tool):

```sh
case "$QUILL_OS" in
  arch) : ;;   # pacman block installed everything
  ubuntu)
    command -v starship >/dev/null || curl -sS https://starship.rs/install.sh | sh -s -- -y
    command -v zoxide   >/dev/null || curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    command -v atuin    >/dev/null || curl -sSfL https://setup.atuin.sh | sh
    command -v eza      >/dev/null || <official eza deb repo or cargo install eza>
    command -v yazi     >/dev/null || <release binary or cargo install --locked yazi-fm yazi-cli>
    # bat ships as `batcat` on Ubuntu; expose it as `bat`
    [ -e ~/.local/bin/bat ] || { mkdir -p ~/.local/bin && ln -s "$(command -v batcat)" ~/.local/bin/bat; }
    ;;
  *) echo "unsupported QUILL_OS=$QUILL_OS" >&2; exit 1 ;;
esac

# (existing) set login shell to zsh — unchanged, runs on both OSes
```

(Exact installer invocations are pinned in the implementation plan; cargo-based
fallbacks require `asdf`/rust, which is the next slice — the plan will prefer
the prebuilt-binary path to avoid a cross-slice dependency.)

## Testing

- `internal/host/os_test.go`: feed fixture `os-release` contents → assert
  `arch` / `ubuntu` / `ID_LIKE` fallback / unknown.
- `internal/action/packages_test.go`: fake `aptDriver` via the `pkgDrivers`
  swap; assert `Check`/`Apply` filter-to-missing behavior and `dpkg -s`/`apt-get`
  command shapes.
- `internal/runner/build_test.go`: add cases —
  - `apt` block skipped when `os="arch"`; `pacman` block skipped when
    `os="ubuntu"`.
  - `os=["ubuntu"]` action filtered out on arch and vice-versa.
  - **regression:** module with empty `os` and only `pacman` blocks produces the
    identical action set on `os="arch"` as before this change.
- `internal/runner/install_sh_test.go`: assert `QUILL_OS`/`QUILL_HOST` are in
  the child env and the script is invoked via its shebang (not `sh`).

`go test ./...` and `gofmt -w .` before each task commit, per project
convention.

## Scope boundaries

**In scope (this slice):** OS detection; `apt` driver; manager→OS package
gating; `os=[]` action gate; `$QUILL_OS` + shebang fix; `bootstrap.sh` ubuntu
branch; `hosts/Dalton.toml`; `shell` module Ubuntu-ready.

**Out of scope (later slices, each its own spec):** git, asdf, tmux, neovim,
python, ai modules on Ubuntu. Desktop modules (hyprland, razer, solaar, gaming,
fonts) remain Arch-only — never added to a WSL host's module list.

**Out of scope (permanently, unchanged from project v1):** macOS / other
distros; secrets management; `quill remove`.

**Doc updates required as part of this slice:** `CLAUDE.md` currently lists
"WSL / non-Arch Linux support" under *Things explicitly out of scope (v1)* and
notes "v1 doesn't target WSL". Those lines, plus the "User context" OS line, are
updated to reflect that WSL/Ubuntu is now a supported (in-progress) target.

## Open questions

1. `eza` and `yazi` on Ubuntu: prefer prebuilt release binary (no rust toolchain
   needed) over `cargo install`? The plan should pick the binary path to keep
   this slice independent of the asdf/rust slice. **Recommended: release
   binary.**
2. Should `quill apply` on `Dalton` warn when it encounters a module that has no
   `apt`/`os` coverage yet (pre-conversion), rather than silently no-op? Small
   UX nicety; can defer.
