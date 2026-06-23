# Spec: WSL/Ubuntu python + ai (slice 4)

**Date:** 2026-06-23
**Status:** Draft (pending review)

## Problem

Two modules remain Arch-only. This slice makes both work on Ubuntu, closing the
last gap in the WSL/Ubuntu story.

1. **`python`** — currently just `pacman uv`. On Ubuntu there is no `uv`, and —
   more importantly — neovim's mason still fails to install four python tools
   (`debugpy`, `isort`, `black`, `pylint`). Root cause confirmed on this box:
   `python3` is present (3.12.3) but the `python3-venv` package is missing, so
   `ensurepip` is unavailable and `python3 -m venv` aborts:

   > The virtual environment was not created successfully because ensurepip is
   > not available. … you need to install the python3-venv package …

   mason creates a venv per python package, so every python tool dies with
   `spawn: python3 failed with exit code 1`. Installing `python3-venv` (which
   resolves to `python3.12-venv`, providing ensurepip) fixes all four.

2. **`ai`** — `pacman opencode socat` + `aur claude-code`. On this box the ai
   tooling was set up by hand (claude + opencode via npm on asdf node). This
   slice makes that reproducible declaratively.

## Guiding principle: additive, explicit arch/ubuntu lines

Same contract as slices 1–3. The Arch path is untouched: both modules' existing
`pacman`/`aur` blocks still auto-gate to Arch. This slice only adds Ubuntu
behavior (apt blocks + `ubuntu)` arms in new install.sh scripts).

## Changes

### `python` module

**`modules/python/module.toml`** — add an apt block after the pacman block:

```toml
[[packages]]
manager = "apt"
names = ["python3-venv", "python3-pip"]
```

- `python3-venv` → pulls `python3.12-venv` → provides `ensurepip`, the actual
  fix for mason's python tools.
- `python3-pip` → system `pip3` for direct use (cheap, idempotent, useful on a
  dev box).

`uv` is **not** apt-installable on 24.04, so it is handled in install.sh.

**`modules/python/install.sh`** (NEW, `chmod +x`):

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

### `ai` module

**`modules/ai/module.toml`** — add `depends_on = ["asdf"]` and an apt block.

- `depends_on = ["asdf"]` — on Ubuntu, claude/opencode install via npm on asdf
  node, so ai's install.sh must run after asdf's. Harmless on Arch (asdf is
  already in the host manifest; this just fixes ordering).
- apt block for socat (the pacman block already pairs `opencode socat`; keep
  parity on Ubuntu):

```toml
[[packages]]
manager = "apt"
names = ["socat"]
```

The pacman (`opencode socat`) and aur (`claude-code`) blocks stay unchanged and
gate to Arch. The three config symlinks are OS-agnostic and unchanged.

**`modules/ai/install.sh`** (NEW, `chmod +x`):

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

## Ordering

quill runs all declarative actions (both apt blocks) before any install.sh.
Module order honors `depends_on`, so asdf's install.sh (which installs/sets node)
runs before ai's install.sh (which needs npm). The python module has no runtime
dependency on other modules.

## Testing / verification

No Go changes → no Go unit tests. Verification is script-level + live:

- `bash -n modules/python/install.sh` and `bash -n modules/ai/install.sh` pass;
  both files are executable.
- `go build ./cmd/quill` succeeds; `quill status` lists `python` and `ai`
  without parse errors (apt blocks active on this box; pacman/aur gated out).
- `./bin/quill apply python ai` on this Ubuntu box (interactive, sudo for apt):
  - python: apt installs `python3-venv`/`python3-pip`; install.sh installs uv.
  - ai: apt installs socat; install.sh npm-installs claude + opencode, reshims.
  - re-run is idempotent (apt packages present → skipped; `command -v uv` and
    `npm ls -g` guards no-op).
- Post-apply, `uv --version`, `claude --version`, `opencode --version`, and
  `python3 -m venv <tmp>` (creates successfully) all resolve.
- In nvim, reopening so mason-tool-installer retries now installs `debugpy`,
  `isort`, `black`, `pylint` — closing the last mason gap.
- Arch path unchanged: pacman/aur blocks gate to Arch; both `arch)` arms no-op.

## Scope boundaries

**In scope (this slice):** python module provides `python3-venv`/`pip` (apt) +
`uv` (Astral installer) on Ubuntu, fixing mason's python tools; ai module
provides claude + opencode (npm on asdf node) + socat (apt) on Ubuntu.

**Out of scope:**

- **Binary-update follow-up** (cross-cutting, still deferred): the `command -v uv`
  and `npm ls -g` guards freeze uv/claude/opencode at first install, same as the
  other GitHub/installer binaries across slices 1/3. Addressed in its own future
  slice, not here. (npm globals can be bumped manually with `npm update -g`; uv
  with `uv self update`.)
- **TPM guard quirk** (tmux, orthogonal).

**Permanent out of scope (unchanged):** macOS / other distros; secrets
management; `quill remove`.

## Open questions

None. uv method (Astral official installer), ai delivery (npm global on asdf
node), and the combined-slice scope all resolved during brainstorming.
