# WSL/Ubuntu asdf ruby + dotnet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make mason's ruby + dotnet tools install on Ubuntu by giving the asdf module an apt block (dotnet-sdk + ruby-build deps) and adding `ruby` to the Ubuntu asdf plugin set — additively, Arch path unchanged.

**Architecture:** Pure module change to `asdf`. The slice-1 foundation already provides OS detection, manager→OS package gating, and `$QUILL_OS` in install.sh. The new apt block auto-gates to Ubuntu and runs (declaratively) before install.sh, so dotnet + ruby-build deps exist by the time install.sh compiles asdf ruby and by the time mason later shells out to `gem`/`dotnet`.

**Tech Stack:** TOML module manifest, bash `install.sh`. **No Go changes, no Go tests** — verification is `bash -n` + `quill status` parse check + (best-effort) idempotent `quill apply` on this Ubuntu box.

**Branch:** `wsl-asdf-ruby-dotnet` (off `startover`, already created). Repo-local git identity already set.

**Spec:** `docs/superpowers/specs/2026-06-19-wsl-asdf-ruby-dotnet-design.md`.

> **Shell note:** in this repo's zsh, `cd` is aliased to zoxide and bare globs can trip `set -e`. Run git/file commands with explicit absolute paths (e.g. `git -C /home/dalton/.dotfiles ...`) and avoid `cd module/...`.

---

## File structure

| File | Change | Task |
|---|---|---|
| `modules/asdf/module.toml` | add `apt` packages block (dotnet-sdk-8.0 + ruby-build deps) | 1 |
| `modules/asdf/install.sh` | ubuntu arm: `plugins="nodejs"` → `plugins="nodejs ruby"` | 1 |

Single task — the two edits are tightly coupled (the apt build deps exist to
support the ruby plugin compile) and ship together.

---

## Task 1: asdf module — ruby + dotnet on Ubuntu

**Files:**
- Modify: `modules/asdf/module.toml`
- Modify: `modules/asdf/install.sh`

- [ ] **Step 1: Read the current module.toml**

Run: `cat /home/dalton/.dotfiles/modules/asdf/module.toml`
Confirm it has a `pacman` block (includes `dotnet-sdk`, `libyaml`) and an `aur`
block (`asdf-vm`), and currently NO `apt` block. You will add the apt block after
the aur block, leaving pacman/aur unchanged.

- [ ] **Step 2: Add the apt packages block**

In `modules/asdf/module.toml`, after the existing `[[packages]] manager = "aur"`
block, add exactly:

```toml
[[packages]]
manager = "apt"
names = [
  "dotnet-sdk-8.0",
  "autoconf", "patch", "build-essential", "libssl-dev", "libyaml-dev",
  "libreadline-dev", "zlib1g-dev", "libgmp-dev", "libncurses-dev",
  "libffi-dev", "libgdbm-dev", "libdb-dev", "uuid-dev",
]
```

`dotnet-sdk-8.0` provides `dotnet` (Ubuntu 24.04 native repo — no Microsoft repo
needed). The rest is the `ruby-build` dependency chain so asdf can compile ruby
from source. Do NOT touch the pacman or aur blocks.

- [ ] **Step 3: Add ruby to the Ubuntu plugin set in install.sh**

In `modules/asdf/install.sh`, in the `ubuntu)` arm of the `case "$QUILL_OS"`,
change the plugins line from:

```sh
    plugins="nodejs"
```

to:

```sh
    plugins="nodejs ruby"
```

Leave everything else in the file unchanged — the `arch)` arm already has
`plugins="nodejs ruby"`, and the plugin-install `for` loop below the case is
unchanged (it will now also add/install/set the `ruby` plugin).

- [ ] **Step 4: Confirm install.sh is still executable**

Run: `ls -l /home/dalton/.dotfiles/modules/asdf/install.sh`
Expected: shows the `x` bit (it already had it; if not, `chmod +x` it).

- [ ] **Step 5: Lint the script**

Run: `bash -n /home/dalton/.dotfiles/modules/asdf/install.sh`
Expected: no output (syntax OK).

- [ ] **Step 6: Verify the module parses and builds**

Run: `go build -o /home/dalton/.dotfiles/bin/quill /home/dalton/.dotfiles/cmd/quill && /home/dalton/.dotfiles/bin/quill status 2>&1 | grep asdf`
Expected: the `asdf` line prints with no parse error. On this Ubuntu box the apt
block is active (pacman/aur gated out), so the declarative action count reflects
the apt packages.

- [ ] **Step 7: Smoke-test — SKIP actual apply**

Do NOT run `./bin/quill apply asdf` here — it triggers a long source compile of
ruby and needs interactive sudo/network, which is not appropriate for an
automated implementer. Lint + build + parse (Steps 5–6) are the success criteria.
The human will run the real apply separately and verify `dotnet --version`,
`ruby --version`, `gem --version`, and the mason ruby/dotnet tools.

- [ ] **Step 8: Commit**

```bash
git -C /home/dalton/.dotfiles add modules/asdf/module.toml modules/asdf/install.sh
git -C /home/dalton/.dotfiles commit -m "asdf: ubuntu ruby (asdf) + dotnet (apt) for mason toolchains"
```

---

## Done criteria

- [ ] `bash -n modules/asdf/install.sh` passes; the file is still executable.
- [ ] `go build ./cmd/quill` succeeds and `quill status` lists `asdf` without parse errors.
- [ ] `modules/asdf/module.toml` has a new `apt` block with `dotnet-sdk-8.0` + the ruby-build deps; pacman and aur blocks are unchanged.
- [ ] `modules/asdf/install.sh` ubuntu arm uses `plugins="nodejs ruby"`; the rest of the file (helper logic, `arch)` arm, `*)` arm, the for-loop) is unchanged.
- [ ] Arch path unchanged: pacman/aur blocks still gate to Arch; the `arch)` arm still installs `nodejs ruby`.
- [ ] No change to any module other than `asdf`. Python mason tools are NOT addressed here (deferred to slice 4).
