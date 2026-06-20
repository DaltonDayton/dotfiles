# WSL/Ubuntu tmux + neovim Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `tmux` and `neovim` modules work on Ubuntu — apt package blocks plus `install.sh` ubuntu branches — additively, with the Arch path unchanged.

**Architecture:** Pure module changes; the slice-1 foundation already provides OS detection, manager→OS package gating, and `$QUILL_OS` in install.sh. Each module gets an `apt` block where apt-native packages exist, and a `case "$QUILL_OS"` install.sh branch for the long tail. The `fetch_gh_release` helper from `modules/shell/install.sh` is copy-pasted into each module that needs it (no shared lib). neovim is installed from the official stable tarball (a directory tree, not a single binary) because apt's nvim is too old for the config's plugins.

**Tech Stack:** TOML module manifests, bash `install.sh` scripts. **No Go changes, no Go tests** — verification is `bash -n` + `quill status` parse check + idempotent `quill apply` on this Ubuntu box.

**Branch:** `wsl-tmux-neovim` (off `startover`, already created). Repo-local git identity already set.

**Spec:** `docs/superpowers/specs/2026-06-19-wsl-tmux-neovim-design.md`.

> **Shell note:** in this repo's zsh, `cd` is aliased to zoxide and bare globs can trip `set -e`. Run git/file commands with explicit paths (e.g. `git -C /home/dalton/.dotfiles ...`) and avoid `cd module/...`.

---

## File structure

| File | Change | Task |
|---|---|---|
| `modules/tmux/module.toml` | add `apt` packages block | 1 |
| `modules/tmux/install.sh` | restructure: `case "$QUILL_OS"` (ubuntu: gum/sesh via fetch + fd shim) then OS-agnostic TPM bootstrap | 1 |
| `modules/neovim/module.toml` | add `apt` packages block | 2 |
| `modules/neovim/install.sh` | new — nvim tarball tree + lazygit/tree-sitter via fetch + fd shim | 2 |

`modules/tmux/files/` and `modules/neovim/files/` are unchanged — the symlinked
configs are OS-agnostic.

---

## Task 1: tmux module — Ubuntu support

**Files:**
- Modify: `modules/tmux/module.toml`
- Modify: `modules/tmux/install.sh`

- [ ] **Step 1: Add the apt packages block**

In `modules/tmux/module.toml`, after the existing `[[packages]] manager = "aur"`
block (names `["sesh-bin"]`), add:

```toml
[[packages]]
manager = "apt"
names = ["tmux", "fd-find"]
```

Leave the pacman block (`["tmux", "gum", "fd"]`) and aur block (`["sesh-bin"]`)
unchanged — they auto-gate to Arch. `gum` and `sesh` are intentionally absent
from the apt block (not in Ubuntu's default repos; fetched in install.sh).

- [ ] **Step 2: Replace `modules/tmux/install.sh` with the restructured version**

Write `modules/tmux/install.sh` with this exact content. The TPM bootstrap at
the bottom is unchanged from the original and runs on both OSes; only the
`LOCAL_BIN`/`fetch_gh_release`/`case` wrapper above it is new.

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
  # `|| true`: grep exits non-zero on no match, which set -e would otherwise
  # treat as fatal before the guard below runs.
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
    # -print -quit stops at the first match without SIGPIPE (a `| head` pipe
    # would SIGPIPE find, which pipefail+set -e would treat as fatal).
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

- [ ] **Step 3: Confirm it is still executable**

Run: `ls -l modules/tmux/install.sh`
Expected: shows the `x` bit (it already had it; if not, `chmod +x modules/tmux/install.sh`).

- [ ] **Step 4: Lint the script**

Run: `bash -n modules/tmux/install.sh`
Expected: no output (syntax OK).

- [ ] **Step 5: Verify the module still parses and gates correctly**

Run: `go build -o ./bin/quill ./cmd/quill && ./bin/quill status 2>&1 | grep tmux`
Expected: the `tmux` line prints (e.g. `tmux PENDING (...)` or `OK`) with no
parse error. On this Ubuntu box the apt block is active (pacman/aur gated out).

- [ ] **Step 6: Smoke-test on this Ubuntu box (best-effort)**

Run (interactively if possible): `./bin/quill apply tmux`
Expected: apt installs `tmux`/`fd-find` (already present → skipped); install.sh's
ubuntu arm fetches `gum`/`sesh` into `~/.local/bin` on first run (or skips if the
`command -v` guards already see them); the fd shim is created if `fd` is absent
but `fdfind` present; TPM bootstrap clones TPM on first run, skips after. A
re-run installs nothing (idempotent). NOTE: `quill apply` primes sudo first; in a
non-interactive shell `sudo -v` will fail — that is an environment limitation,
not a task failure. The task's success criterion is correct files + lint + parse.

- [ ] **Step 7: Commit**

```bash
git -C /home/dalton/.dotfiles add modules/tmux/module.toml modules/tmux/install.sh
git -C /home/dalton/.dotfiles commit -m "tmux: ubuntu support (apt block + gum/sesh via fetch_gh_release)"
```

---

## Task 2: neovim module — Ubuntu support

**Files:**
- Modify: `modules/neovim/module.toml`
- Create: `modules/neovim/install.sh`

- [ ] **Step 1: Add the apt packages block**

In `modules/neovim/module.toml`, after the existing `[[packages]] manager =
"pacman"` block (names `["neovim", "lazygit", "ripgrep", "fd", "unzip",
"tree-sitter-cli"]`), add:

```toml
[[packages]]
manager = "apt"
names = ["ripgrep", "fd-find", "unzip"]
```

Leave the pacman block unchanged (auto-gates to Arch). `neovim`, `lazygit`, and
`tree-sitter-cli` are intentionally absent from the apt block — apt's nvim is too
old, and lazygit/tree-sitter-cli are not in default repos; all three are handled
in install.sh.

- [ ] **Step 2: Create `modules/neovim/install.sh`**

Create the file with this exact content:

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
  # `|| true`: grep exits non-zero on no match, which set -e would otherwise
  # treat as fatal before the guard below runs.
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
    # -print -quit stops at the first match without SIGPIPE (a `| head` pipe
    # would SIGPIPE find, which pipefail+set -e would treat as fatal).
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
      # EXIT (not RETURN — this is top-level, not a function) cleans the temp
      # dir even if curl/tar aborts under set -e.
      trap 'rm -rf "$tmp"' EXIT
      curl -fsSL -o "$tmp/nvim.tar.gz" \
        https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
      tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
      rm -rf "$HOME/.local/nvim"
      mv "$tmp/nvim-linux-x86_64" "$HOME/.local/nvim"
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

- [ ] **Step 3: Make it executable**

Run: `chmod +x modules/neovim/install.sh`
(Required: the runner invokes install.sh via its shebang, which needs the
execute bit.)

- [ ] **Step 4: Lint the script**

Run: `bash -n modules/neovim/install.sh`
Expected: no output (syntax OK).

- [ ] **Step 5: Verify the module still parses**

Run: `./bin/quill status 2>&1 | grep neovim`
Expected: the `neovim` line prints with no parse error. On this Ubuntu box the
apt block is active (pacman block gated out).

- [ ] **Step 6: Smoke-test on this Ubuntu box (best-effort)**

Run (interactively if possible): `./bin/quill apply neovim`
Expected: apt installs `ripgrep`/`fd-find`/`unzip` (already present → skipped);
install.sh's ubuntu arm downloads the nvim stable tarball to `~/.local/nvim` and
symlinks `~/.local/bin/nvim` on first run (skips the download on re-run because
`~/.local/nvim/bin/nvim` exists, but always refreshes the symlink); fetches
`lazygit` and `tree-sitter` (or skips if `command -v` guards see them); creates
the fd shim if needed. Verify `~/.local/bin/nvim --version` reports 0.10+ and
`tree-sitter --version` works. A re-run installs nothing new (idempotent). As in
Task 1, a non-interactive `sudo -v` failure during priming is an environment
limit, not a task failure (this module needs sudo only for the apt packages).

- [ ] **Step 7: Commit**

```bash
git -C /home/dalton/.dotfiles add modules/neovim/module.toml modules/neovim/install.sh
git -C /home/dalton/.dotfiles commit -m "neovim: ubuntu support (apt block + nvim tarball + lazygit/tree-sitter via fetch)"
```

---

## Done criteria

- [ ] `bash -n` passes for both `modules/tmux/install.sh` and `modules/neovim/install.sh`; both are executable.
- [ ] `go build ./cmd/quill` succeeds (no accidental Go breakage) and `quill status` lists `tmux` and `neovim` without parse errors.
- [ ] On this Ubuntu box, `quill apply tmux neovim` (run interactively, sudo primed) installs the long-tail tools on first run and nothing new on re-run (idempotent). `~/.local/bin/nvim --version` is 0.10+.
- [ ] Arch path unchanged: pacman/aur blocks still gate to Arch; the `arch)` install.sh arms are no-ops; tmux's TPM bootstrap still runs on both OSes.
- [ ] The binary-update gap is NOT addressed here (deferred per spec) — no attempt to add refresh/version-pin logic in this slice.
