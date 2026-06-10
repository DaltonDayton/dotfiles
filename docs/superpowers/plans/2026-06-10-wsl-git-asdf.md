# WSL/Ubuntu git + asdf Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `git` and `asdf` modules work on Ubuntu — apt package blocks plus `install.sh` ubuntu branches — additively, with the Arch path unchanged.

**Architecture:** Pure module changes; the slice-1 foundation already provides OS detection, manager→OS package gating, and `$QUILL_OS` in install.sh. Each module gets an `apt` block where apt-native packages exist, and a `case "$QUILL_OS"` install.sh branch for the long tail (gh via GitHub apt repo; asdf via `go install`; node-only runtime).

**Tech Stack:** TOML module manifests, bash `install.sh` scripts. **No Go changes, no Go tests** — verification is `bash -n` + idempotent `quill apply` on this Ubuntu box.

**Branch:** `wsl-git-asdf` (off `startover`). Repo-local git identity already set.

**Spec:** `docs/superpowers/specs/2026-06-10-wsl-git-asdf-design.md`.

---

## File structure

| File | Change | Task |
|---|---|---|
| `modules/git/module.toml` | add `apt` packages block | 1 |
| `modules/git/install.sh` | new — gh via GitHub apt repo (ubuntu) | 1 |
| `modules/asdf/install.sh` | restructure with `case "$QUILL_OS"` (ubuntu: go-install asdf + node-only) | 2 |

`modules/asdf/module.toml` is **not** modified — Ubuntu installs nothing
declaratively for asdf (node is handled in install.sh; ruby/dotnet/libyaml are
skipped), and the existing pacman/aur blocks auto-gate to Arch.

---

## Task 1: git module — Ubuntu support

**Files:**
- Modify: `modules/git/module.toml`
- Create: `modules/git/install.sh`

- [ ] **Step 1: Add the apt packages block**

In `modules/git/module.toml`, after the existing
`[[packages]] manager = "pacman"` block (names `["git", "github-cli",
"openssh", "bat", "man-db"]`), add:

```toml
[[packages]]
manager = "apt"
names = ["git", "openssh-client", "bat", "man-db"]
```

`gh` is intentionally absent here — it is not in Ubuntu's default repos, so it
is installed in install.sh after adding the GitHub apt repo. The pacman block
stays unchanged (gates to Arch automatically).

- [ ] **Step 2: Create `modules/git/install.sh`**

Create the file with this exact content:

```sh
#!/usr/bin/env bash
set -euo pipefail

case "$QUILL_OS" in
  arch)
    : # github-cli comes from the pacman block
    ;;
  ubuntu)
    if ! command -v gh >/dev/null; then
      # Official GitHub CLI apt repo (keyring + source list), then install.
      command -v curl >/dev/null || sudo apt-get install -y curl
      sudo mkdir -p -m 755 /etc/apt/keyrings
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update
      sudo apt-get install -y gh
    fi
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 3: Make it executable**

Run: `chmod +x modules/git/install.sh`
(Required: slice 1's runner invokes install.sh via its shebang, which needs the
execute bit.)

- [ ] **Step 4: Lint the script**

Run: `bash -n modules/git/install.sh`
Expected: no output (syntax OK).

- [ ] **Step 5: Verify the module still parses and gates correctly**

Run: `go build -o ./bin/quill ./cmd/quill && ./bin/quill status 2>&1 | grep git`
Expected: the `git` line prints (e.g. `git PENDING (...)` or `OK`) with no parse
error. On this Ubuntu box the apt block is what's active (pacman block gated
out).

- [ ] **Step 6: Smoke-test on this Ubuntu box (best-effort)**

Run: `./bin/quill apply git`
Expected: apt installs `git`/`openssh-client`/`bat`/`man-db` (already present →
skipped); install.sh's gh guard sees `gh` already on PATH (`/usr/bin/gh`) and
skips the repo setup entirely. NOTE: `quill apply` primes sudo first; in a
non-interactive shell `sudo -v` will fail — that is an environment limitation,
not a task failure. The task's success criterion is correct files + lint +
parse. If you can run it interactively, confirm a re-run is idempotent (no
installs, gh guard skips).

- [ ] **Step 7: Commit**

```bash
git add modules/git/module.toml modules/git/install.sh
git commit -m "git: ubuntu support (apt block + gh via GitHub apt repo)"
```

---

## Task 2: asdf module — Ubuntu support

**Files:**
- Modify: `modules/asdf/install.sh`

(`modules/asdf/module.toml` is intentionally NOT changed.)

- [ ] **Step 1: Read the current install.sh**

Run: `cat modules/asdf/install.sh`
Confirm it currently is an unconditional `for plugin in nodejs ruby` loop that
adds each plugin, installs `asdf latest`, and runs `asdf set -u`. You will wrap
this loop in an OS `case` that selects the plugin set and, on Ubuntu, first
installs `go`+`asdf`.

- [ ] **Step 2: Replace the whole file with the restructured version**

Write `modules/asdf/install.sh` with this exact content (the plugin-install loop
body is unchanged from the original; only the `case` wrapper around the
`plugins` selection is new):

```sh
#!/usr/bin/env bash
set -euo pipefail

case "$QUILL_OS" in
  arch)
    plugins="nodejs ruby"   # asdf-vm installed declaratively via aur
    ;;
  ubuntu)
    # asdf is a Go binary on the 0.16+ rewrite; go ships from bootstrap.
    command -v go >/dev/null || sudo apt-get install -y golang-go
    command -v asdf >/dev/null || go install github.com/asdf-vm/asdf/cmd/asdf@latest
    export PATH="$HOME/go/bin:$PATH"   # go install target, for this script run
    plugins="nodejs"
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac

for plugin in $plugins; do
    if ! asdf plugin list 2>/dev/null | grep -qx "$plugin"; then
        echo "Adding asdf plugin: $plugin"
        asdf plugin add "$plugin"
    fi

    latest="$(asdf latest "$plugin")"
    # `asdf install` no-ops when the version is present, but still prints
    # "version X of Y is already installed" — guard it explicitly so re-runs
    # stay silent. `asdf list` marks the active version with a leading `*`,
    # so strip leading spaces/asterisks before matching.
    if ! asdf list "$plugin" 2>/dev/null | sed 's/^[ *]*//' | grep -qx "$latest"; then
        asdf install "$plugin" "$latest"
    fi
    asdf set -u "$plugin" "$latest"
done
```

- [ ] **Step 3: Confirm it is still executable**

Run: `ls -l modules/asdf/install.sh`
Expected: shows the `x` bit (it already had it; if not, `chmod +x`).

- [ ] **Step 4: Lint the script**

Run: `bash -n modules/asdf/install.sh`
Expected: no output (syntax OK).

- [ ] **Step 5: Verify the module still parses**

Run: `./bin/quill status 2>&1 | grep asdf`
Expected: the `asdf` line prints with no parse error. On this Ubuntu box the
pacman/aur package blocks are gated out, so the module's declarative action
count is 0 — it may show `OK` (declarative work empty; the real work is in
install.sh, which `status` does not run).

- [ ] **Step 6: Smoke-test on this Ubuntu box (best-effort)**

Run (interactively if possible): `./bin/quill apply asdf`
Expected: install.sh's ubuntu arm runs — `go` present (`/usr/bin/go`) →
skipped; `asdf` present (`~/go/bin/asdf`) → skipped; nodejs plugin already added
and node 24.4.0 already installed/set → loop no-ops. Net: no changes, proving
idempotency. As in Task 1, a non-interactive `sudo -v` failure during priming is
an environment limit, not a task failure (note: this module only needs sudo if
`go` is missing).

- [ ] **Step 7: Commit**

```bash
git add modules/asdf/install.sh
git commit -m "asdf: ubuntu support (go-install asdf + node-only via QUILL_OS branch)"
```

---

## Done criteria

- [ ] `bash -n` passes for both `modules/git/install.sh` and `modules/asdf/install.sh`; both are executable.
- [ ] `go build ./cmd/quill` succeeds (no accidental Go breakage) and `quill status` lists `git` and `asdf` without parse errors.
- [ ] On this Ubuntu box, `quill apply git asdf` (run interactively, sudo primed) installs nothing new (all guards skip) — idempotent.
- [ ] Arch path unchanged: pacman/aur blocks still gate to Arch; the `arch)` install.sh arms reproduce prior behavior (gh from github-cli; nodejs+ruby plugins).
- [ ] No `modules/asdf/module.toml` change.
```
