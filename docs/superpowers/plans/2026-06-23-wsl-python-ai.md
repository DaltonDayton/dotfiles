# WSL/Ubuntu python + ai Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `python` and `ai` modules work on Ubuntu — additively, Arch path unchanged — closing the last neovim/mason gap (python tools).

**Architecture:** Two independent module changes. The slice-1 foundation already provides OS detection, manager→OS package gating, and `$QUILL_OS` in install.sh. Each module gets an apt block (auto-gates to Ubuntu, runs declaratively before install.sh) plus a new `install.sh` whose `ubuntu)` arm handles the non-apt tools (uv via Astral installer; claude + opencode via npm on asdf node). The `arch)` arms no-op because the existing pacman/aur blocks already cover Arch.

**Tech Stack:** TOML module manifests, bash `install.sh`. **No Go changes, no Go tests** — verification is `bash -n` + `go build` + `quill status` parse check + (human-run) idempotent `quill apply`.

## Global Constraints

- Additive only: the Arch path must behave identically. Never modify the existing `pacman`/`aur` blocks; only add `apt` blocks and `ubuntu)` install.sh arms.
- install.sh scripts: `#!/usr/bin/env bash` + `set -euo pipefail`, a full `case "$QUILL_OS"` with explicit `arch)` / `ubuntu)` / `*)` arms (the `*)` arm prints `unsupported QUILL_OS=$QUILL_OS` to stderr and `exit 1`).
- All declarative actions (apt blocks) run before any install.sh; module order honors `depends_on`.
- Idempotency is the contract: every install.sh path must no-op on re-run.
- `gofmt -w .` not needed (no Go changes). Run `bash -n` on every script.

**Branch:** `wsl-python-ai` (off `startover`). Repo-local git identity already set.

**Spec:** `docs/superpowers/specs/2026-06-23-wsl-python-ai-design.md`.

> **Shell note:** in this repo's zsh, `cd` is aliased to zoxide and bare globs can trip `set -e`. Run git/file commands with explicit absolute paths (e.g. `git -C /home/dalton/.dotfiles ...`) and avoid `cd module/...`.

---

## File structure

| File | Change | Task |
|---|---|---|
| `modules/python/module.toml` | add `apt` block (`python3-venv`, `python3-pip`) | 1 |
| `modules/python/install.sh` | NEW — uv via Astral installer on Ubuntu | 1 |
| `modules/ai/module.toml` | add `depends_on = ["asdf"]` + `apt` block (`socat`) | 2 |
| `modules/ai/install.sh` | NEW — claude + opencode via npm on asdf node | 2 |

Two tasks, one per module. They are independent and each ends in an
independently testable deliverable (lint + build + parse).

---

## Task 1: python module — venv + pip (apt) + uv (Astral) on Ubuntu

**Files:**
- Modify: `modules/python/module.toml`
- Create: `modules/python/install.sh`

**Interfaces:**
- Consumes: `$QUILL_OS` (exported by the runner to install.sh; values `arch` / `ubuntu`). Slice-1 foundation.
- Produces: nothing other tasks depend on (terminal leaf module).

- [ ] **Step 1: Read the current module.toml**

Run: `cat /home/dalton/.dotfiles/modules/python/module.toml`
Confirm it has exactly a `name`/`description`/`tags` header and one `pacman`
block (`names = ["uv"]`), and currently NO `apt` block and NO install.sh.

- [ ] **Step 2: Add the apt block**

In `modules/python/module.toml`, after the existing `[[packages]] manager = "pacman"`
block, append exactly:

```toml
[[packages]]
manager = "apt"
names = ["python3-venv", "python3-pip"]
```

`python3-venv` resolves to `python3.12-venv`, providing `ensurepip` — the actual
fix for mason's python tools (debugpy/isort/black/pylint), which each create a
venv. `python3-pip` gives system `pip3`. Do NOT touch the pacman block.

- [ ] **Step 3: Create install.sh**

Create `modules/python/install.sh` with exactly:

```sh
#!/usr/bin/env bash
set -euo pipefail

case "$QUILL_OS" in
  arch)
    : # uv comes from the pacman block
    ;;
  ubuntu)
    export PATH="$HOME/.local/bin:$PATH"
    # uv is not in the Ubuntu 24.04 repos; install via Astral's official script
    # (standalone binary into ~/.local/bin, self-updating via `uv self update`).
    command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 4: Make it executable**

Run: `chmod +x /home/dalton/.dotfiles/modules/python/install.sh`
Then: `ls -l /home/dalton/.dotfiles/modules/python/install.sh`
Expected: the `x` bit is set.

- [ ] **Step 5: Lint the script**

Run: `bash -n /home/dalton/.dotfiles/modules/python/install.sh`
Expected: no output (syntax OK).

- [ ] **Step 6: Verify the module parses and builds**

Run: `go build -o /home/dalton/.dotfiles/bin/quill /home/dalton/.dotfiles/cmd/quill && /home/dalton/.dotfiles/bin/quill status 2>&1 | grep python`
Expected: the `python` line prints with no parse error. On this Ubuntu box the
apt block is active (pacman gated out).

- [ ] **Step 7: Smoke-test — SKIP actual apply**

Do NOT run `./bin/quill apply python` here — it needs interactive sudo (apt) and
network (Astral installer). Lint + build + parse (Steps 5–6) are the success
criteria. The human runs the real apply and verifies `uv --version` and
`python3 -m venv <tmp>` succeeds.

- [ ] **Step 8: Commit**

```bash
git -C /home/dalton/.dotfiles add modules/python/module.toml modules/python/install.sh
git -C /home/dalton/.dotfiles commit -m "python: ubuntu venv/pip (apt) + uv (Astral installer)"
```

---

## Task 2: ai module — claude + opencode (npm on asdf node) + socat (apt) on Ubuntu

**Files:**
- Modify: `modules/ai/module.toml`
- Create: `modules/ai/install.sh`

**Interfaces:**
- Consumes: `$QUILL_OS`; asdf-managed node (provided by the `asdf` module's
  install.sh — `npm` reachable via `~/.asdf/shims` after `asdf set -u nodejs`).
  The new `depends_on = ["asdf"]` guarantees asdf's install.sh runs first.
- Produces: nothing other tasks depend on (terminal leaf module).

- [ ] **Step 1: Read the current module.toml**

Run: `cat /home/dalton/.dotfiles/modules/ai/module.toml`
Confirm it has a `pacman` block (`opencode`, `socat`), an `aur` block
(`claude-code`), three `[[symlinks]]` blocks, NO `depends_on`, NO `apt` block,
and NO install.sh.

- [ ] **Step 2: Add depends_on to the header**

In `modules/ai/module.toml`, add a `depends_on` line to the top header block
(after the `tags = [...]` line), exactly:

```toml
depends_on = ["asdf"]
```

This orders ai's install.sh after asdf's (which installs/sets node). Harmless on
Arch — asdf is already in the host manifest.

- [ ] **Step 3: Add the apt block**

In `modules/ai/module.toml`, after the `aur` block and before the first
`[[symlinks]]` block, add exactly:

```toml
[[packages]]
manager = "apt"
names = ["socat"]
```

Keeps parity with the pacman block's `socat`. Do NOT touch the pacman, aur, or
symlink blocks.

- [ ] **Step 4: Create install.sh**

Create `modules/ai/install.sh` with exactly:

```sh
#!/usr/bin/env bash
set -euo pipefail

case "$QUILL_OS" in
  arch)
    : # opencode + claude-code come from pacman/aur
    ;;
  ubuntu)
    # claude + opencode install as global npm packages on asdf-managed node.
    # asdf 0.16+ is a Go binary with shims under ~/.asdf/shims; the asdf binary
    # itself was `go install`ed by the asdf module, so include ~/go/bin too.
    export PATH="$HOME/.asdf/shims:$HOME/go/bin:$PATH"

    # Query npm's global list directly — more reliable than PATH/shim probing,
    # which is racy before `asdf reshim`.
    npm_global_has() { npm ls -g --depth=0 "$1" >/dev/null 2>&1; }
    npm_global_has @anthropic-ai/claude-code || npm i -g @anthropic-ai/claude-code
    npm_global_has opencode-ai || npm i -g opencode-ai

    # Expose the freshly-installed bins as asdf shims (~/.asdf/shims/claude etc.).
    asdf reshim nodejs
    ;;
  *)
    echo "unsupported QUILL_OS=$QUILL_OS" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 5: Make it executable**

Run: `chmod +x /home/dalton/.dotfiles/modules/ai/install.sh`
Then: `ls -l /home/dalton/.dotfiles/modules/ai/install.sh`
Expected: the `x` bit is set.

- [ ] **Step 6: Lint the script**

Run: `bash -n /home/dalton/.dotfiles/modules/ai/install.sh`
Expected: no output (syntax OK).

- [ ] **Step 7: Verify the module parses and builds**

Run: `go build -o /home/dalton/.dotfiles/bin/quill /home/dalton/.dotfiles/cmd/quill && /home/dalton/.dotfiles/bin/quill status 2>&1 | grep ai`
Expected: the `ai` line prints with no parse error. The `depends_on` parses
(no "unknown module" error — asdf exists).

- [ ] **Step 8: Smoke-test — SKIP actual apply**

Do NOT run `./bin/quill apply ai` here — it needs interactive sudo (apt socat)
and network (npm). Lint + build + parse (Steps 6–7) are the success criteria.
The human runs the real apply and verifies `claude --version` and
`opencode --version` resolve.

- [ ] **Step 9: Commit**

```bash
git -C /home/dalton/.dotfiles add modules/ai/module.toml modules/ai/install.sh
git -C /home/dalton/.dotfiles commit -m "ai: ubuntu claude + opencode (npm on asdf node) + socat (apt)"
```

---

## Done criteria

- [ ] `bash -n` passes for both new install.sh scripts; both are executable.
- [ ] `go build ./cmd/quill` succeeds; `quill status` lists `python` and `ai` without parse errors.
- [ ] `modules/python/module.toml` has a new `apt` block (`python3-venv`, `python3-pip`); pacman block unchanged.
- [ ] `modules/ai/module.toml` has `depends_on = ["asdf"]` + a new `apt` block (`socat`); pacman/aur/symlink blocks unchanged.
- [ ] Both install.sh `arch)` arms no-op (`:`); `ubuntu)` arms handle uv / npm; `*)` arms error.
- [ ] Arch path unchanged: pacman/aur blocks still gate to Arch.
- [ ] No change to any module other than `python` and `ai`.

## Human verification (post-merge, on the Ubuntu box)

- `./bin/quill apply python ai` (interactive sudo). Re-run → idempotent.
- `uv --version`, `claude --version`, `opencode --version` resolve.
- `python3 -m venv /tmp/x` creates successfully (ensurepip present).
- Reopen nvim → mason installs `debugpy`, `isort`, `black`, `pylint`.
