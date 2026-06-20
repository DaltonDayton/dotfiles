# Spec: WSL/Ubuntu support — tmux + neovim modules (slice 3)

**Date:** 2026-06-19
**Status:** Draft (pending review)

## Problem

Slices 1–2 shipped the WSL/Ubuntu foundation (OS detection, `apt` driver,
manager→OS package gating, `$QUILL_OS` for install.sh, the `Dalton` host) plus
the `shell`, `git`, and `asdf` modules. The `Dalton` host also lists `tmux` and
`neovim`, but those modules are still Arch-only — their packages install via
`pacman`/`aur`, so on Ubuntu they no-op.

This slice makes `tmux` and `neovim` work on Ubuntu — **additively**, with the
Arch path behaving identically. As with slice 2 there are **no Go code changes**;
the foundation already handles gating and `$QUILL_OS`. It is entirely
`module.toml` apt blocks and `install.sh` ubuntu branches.

## Guiding principle: additive, explicit arch/ubuntu lines

Same contract as slices 1–2. The Arch path is untouched: existing `pacman`/`aur`
package blocks auto-gate to Arch via the manager→OS rule, and every new or
modified `install.sh` branch is a full `case "$QUILL_OS"` with an explicit
`arch)` arm (a no-op `:` where the declarative block already covers Arch) and a
`*)` error arm.

**Shared-helper policy (decided this slice):** the `fetch_gh_release` helper
(introduced in `modules/shell/install.sh`) is **copy-pasted** into each module
that needs it, not extracted into a shared library. Only `shell` used it before;
this slice adds two more callers. Two-to-three copies of a ~20-line function is
not worth new runner machinery yet. Revisit a shared lib only if a later slice
adds a fourth caller.

**Binary-name shims:** each tool's name shim (e.g. `fd→fdfind`) lives in the
module that apt-installs that tool, guarded by `command -v`. `fd` is listed in
both `tmux` and `neovim`, so the shim is duplicated (two guarded lines) — accepted
under the copy-paste policy.

## tmux module

### Package / tool lines

| Tool | Arch | Ubuntu |
|------|------|--------|
| tmux | pacman `tmux` | apt `tmux` |
| fd | pacman `fd` | apt `fd-find` (binary `fdfind`; `fd` shim created in install.sh) |
| gum | pacman `gum` | **install.sh** — not in default apt repos; `fetch_gh_release` prebuilt binary |
| sesh | aur `sesh-bin` | **install.sh** — `fetch_gh_release` prebuilt binary |

Full Arch parity on Ubuntu: gum + sesh are installed (not skipped). They are
cheap single-binary GitHub fetches, and the symlinked `tmux.conf` has a sesh
keybind that would otherwise be dead.

### `modules/tmux/module.toml`

Keep the existing pacman (`tmux`, `gum`, `fd`) and aur (`sesh-bin`) blocks. Add:

```toml
[[packages]]
manager = "apt"
names = ["tmux", "fd-find"]
```

`gum` and `sesh` are deliberately NOT in the apt block — neither is in Ubuntu's
default repos, so both are fetched as prebuilt binaries in install.sh. The two
symlinks (`tmux.conf`, `sesh.toml`) and `depends_on` are OS-agnostic, unchanged.

### `modules/tmux/install.sh` (restructure existing)

The current script is only the unconditional TPM bootstrap. Wrap it: a
`case "$QUILL_OS"` installs the Ubuntu long-tail first, then the **OS-agnostic
TPM bootstrap runs for both OSes** (it is a plain `git clone` + `install_plugins`,
which already works on Ubuntu once `tmux` is present).

```sh
#!/usr/bin/env bash
set -euo pipefail

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Copy of the helper from modules/shell/install.sh (per the copy-paste policy).
# Downloads the latest GitHub release asset matching $2 (a grep -E pattern) from
# repo $1 into $LOCAL_BIN, extracting tar.gz/zip and copying out binaries $3...
fetch_gh_release() {
  repo="$1"; asset_re="$2"; shift 2
  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -oE "https://[^\"]*$asset_re" | head -n1 || true)"
  [ -n "$url" ] || { echo "no release asset for $repo matching $asset_re" >&2; return 1; }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  file="$tmp/$(basename "$url")"
  curl -fsSL "$url" -o "$file"
  case "$file" in
    *.tar.gz|*.tgz) tar -xzf "$file" -C "$tmp" ;;
    *.zip)          unzip -q "$file" -d "$tmp" ;;
  esac
  for bin in "$@"; do
    found="$(find "$tmp" -type f -name "$bin" -perm -u+x -print -quit)"
    [ -n "$found" ] || found="$(find "$tmp" -type f -name "$bin" -print -quit)"
    if [ -n "$found" ]; then
      install -m755 "$found" "$LOCAL_BIN/$bin"
    else
      echo "warning: $bin not found in $repo archive" >&2
    fi
  done
}

case "$QUILL_OS" in
  arch)
    : # gum from pacman, sesh from aur, fd from pacman
    ;;
  ubuntu)
    command -v gum >/dev/null || \
      fetch_gh_release "charmbracelet/gum" 'gum_.*_Linux_x86_64\.tar\.gz' gum
    command -v sesh >/dev/null || \
      fetch_gh_release "joshmedeski/sesh" 'sesh_Linux_x86_64\.tar\.gz' sesh
    # fd ships as `fdfind` on Ubuntu; expose it under the expected name.
    if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then
      ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
    fi
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac

# TPM bootstrap — OS-agnostic, runs on both Arch and Ubuntu.
TPM="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM" ]; then
    exit 0
fi
echo "Cloning TPM to $TPM"
git clone https://github.com/tmux-plugins/tpm "$TPM"
"$TPM/bin/install_plugins"
```

## neovim module

### Package / tool lines

| Tool | Arch | Ubuntu |
|------|------|--------|
| neovim | pacman `neovim` | **install.sh** — apt's is too old (0.9.x); official stable tarball tree |
| lazygit | pacman `lazygit` | **install.sh** — `fetch_gh_release` prebuilt binary |
| ripgrep | pacman `ripgrep` | apt `ripgrep` (binary `rg`, no shim) |
| fd | pacman `fd` | apt `fd-find` (binary `fdfind`; `fd` shim in install.sh) |
| unzip | pacman `unzip` | apt `unzip` |
| tree-sitter-cli | pacman `tree-sitter-cli` | **install.sh** — `fetch_gh_release` (`.zip` asset, binary `tree-sitter`) |

Why nvim is a tarball, not apt: the config uses `blink.cmp` + `snacks.nvim` +
`mason`, all of which require nvim **0.10+**. Ubuntu 24.04 apt ships 0.9.5. The
official prebuilt **stable** tarball is the same artifact the nvim team releases
from the stable tag — effectively as current as Arch's `neovim` package — and
needs no build toolchain. It is a directory tree (`bin/nvim` + `lib/` +
`share/runtime`), not a single binary, so it gets a bespoke extract-and-symlink
path rather than reusing `fetch_gh_release`.

### `modules/neovim/module.toml`

Keep the existing pacman block. Add:

```toml
[[packages]]
manager = "apt"
names = ["ripgrep", "fd-find", "unzip"]
```

`neovim`, `lazygit`, and `tree-sitter-cli` are deliberately NOT in the apt block
— apt's nvim is too old, and lazygit/tree-sitter-cli are not in default repos.
All three are handled in install.sh. The `nvim` symlink is OS-agnostic, unchanged.

### `modules/neovim/install.sh` (new, `chmod +x`)

```sh
#!/usr/bin/env bash
set -euo pipefail

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Copy of the helper from modules/shell/install.sh (per the copy-paste policy).
fetch_gh_release() {
  repo="$1"; asset_re="$2"; shift 2
  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | grep -oE "https://[^\"]*$asset_re" | head -n1 || true)"
  [ -n "$url" ] || { echo "no release asset for $repo matching $asset_re" >&2; return 1; }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  file="$tmp/$(basename "$url")"
  curl -fsSL "$url" -o "$file"
  case "$file" in
    *.tar.gz|*.tgz) tar -xzf "$file" -C "$tmp" ;;
    *.zip)          unzip -q "$file" -d "$tmp" ;;
  esac
  for bin in "$@"; do
    found="$(find "$tmp" -type f -name "$bin" -perm -u+x -print -quit)"
    [ -n "$found" ] || found="$(find "$tmp" -type f -name "$bin" -print -quit)"
    if [ -n "$found" ]; then
      install -m755 "$found" "$LOCAL_BIN/$bin"
    else
      echo "warning: $bin not found in $repo archive" >&2
    fi
  done
}

case "$QUILL_OS" in
  arch)
    : # neovim/lazygit/tree-sitter-cli/fd all come from the pacman block
    ;;
  ubuntu)
    # neovim: official stable tarball is a directory tree (bin/ + lib/ + share/),
    # not a single binary — extract to ~/.local/nvim and symlink the launcher.
    if [ ! -x "$HOME/.local/nvim/bin/nvim" ]; then
      tmp="$(mktemp -d)"
      curl -fsSL -o "$tmp/nvim.tar.gz" \
        https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
      tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
      rm -rf "$HOME/.local/nvim"
      mv "$tmp/nvim-linux-x86_64" "$HOME/.local/nvim"
      rm -rf "$tmp"
    fi
    ln -sf "$HOME/.local/nvim/bin/nvim" "$LOCAL_BIN/nvim"

    command -v lazygit >/dev/null || \
      fetch_gh_release "jesseduffield/lazygit" 'lazygit_.*_linux_x86_64\.tar\.gz' lazygit

    command -v tree-sitter >/dev/null || \
      fetch_gh_release "tree-sitter/tree-sitter" 'tree-sitter-cli-linux-x64\.zip' tree-sitter

    # fd ships as `fdfind` on Ubuntu; expose it under the expected name.
    if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then
      ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
    fi
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac
```

The nvim guard checks the real install path (`~/.local/nvim/bin/nvim`) rather
than `command -v nvim`, so a stray apt nvim on PATH would not false-skip the
tarball install. The `ln -sf` runs every apply (cheap, idempotent) to self-heal a
missing symlink. `~/.local/bin` is already on PATH (set in the shell module's
`.zshrc`).

## Testing / verification

No Go changes → no Go unit tests. Verification is script-level:

- `bash -n modules/tmux/install.sh` and `bash -n modules/neovim/install.sh` pass;
  both scripts are `chmod +x`.
- `go build ./cmd/quill` succeeds and `quill status` lists `tmux` and `neovim`
  without parse errors (apt blocks active on this box; pacman/aur gated out).
- `./bin/quill apply tmux neovim` on this Ubuntu box, run interactively (sudo
  primed for apt): apt installs tmux/ripgrep/fd-find/unzip; install.sh fetches
  nvim/lazygit/gum/sesh/tree-sitter on first run, then re-runs are idempotent
  (all `command -v` / `[ -x ]` guards skip). A non-interactive `sudo -v` failure
  during priming is an environment limit, not a task failure.
- Arch path unchanged: pacman/aur blocks still gate to Arch; the `arch)` arms are
  no-ops; tmux's TPM bootstrap still runs on both OSes.

## Scope boundaries

**In scope (this slice):** `tmux` and `neovim` modules Ubuntu-ready (apt blocks +
install.sh ubuntu branches), full Arch parity (gum/sesh/tree-sitter-cli included),
nvim via official stable tarball, lazygit/gum/sesh/tree-sitter-cli via
`fetch_gh_release` copy-paste.

**Deferred to its own slice — binary update story.** The `command -v` / `[ -x ]`
idempotency guards freeze every GitHub-fetched and official-installer binary at
its first-install version (nvim, lazygit, gum, sesh, tree-sitter here; plus
eza/yazi/starship/zoxide/atuin from slice 1). Unlike apt packages (`apt upgrade`)
or asdf node (re-bumps each apply), these never update. The user has flagged this
as undesirable. It is a **cross-cutting** concern across all done slices and will
get its own dedicated design (a `--refresh-binaries`-style bypass or in-repo
version pinning). Manual workaround until then: `rm ~/.local/bin/<tool>` (or
`rm -rf ~/.local/nvim`) then re-apply.

**Out of scope (later slices):** python + ai (slice 4).

**Permanent out of scope (unchanged):** macOS / other distros; secrets
management; `quill remove`.

## Open questions

None. All decisions (copy-paste helper, full parity, nvim stable tarball, defer
the update story) resolved during brainstorming.
