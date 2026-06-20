# Spec: WSL/Ubuntu asdf ruby + dotnet (mason toolchains)

**Date:** 2026-06-19
**Status:** Draft (pending review)

## Problem

After slice 3 made `neovim` work on Ubuntu, opening nvim surfaces mason install
errors. Root cause (from `~/.local/state/nvim/mason.log`): the config's
`ensure_installed` lists assume the full Arch toolchain, but the WSL box is lean.
Three buckets fail:

- `csharp-language-server` (+ `coreclr` DAP) → `cmd="dotnet" ENOENT` — no dotnet.
- `ruby-lsp`, `rubocop` → `cmd="gem" ENOENT` — no ruby/gem.
- `debugpy`, `isort`, `black`, `pylint` → `python3 failed exit 1` — python3
  present but no `pip`/`venv`.

The dotnet and ruby gaps are the deliberate slice-2 decision (node-only runtimes,
skip dotnet). The user has chosen to **reverse** that: they want multi-version
ruby (so asdf-managed, not apt system ruby) and a working C# LSP. This slice
provides `gem` (via asdf ruby) and `dotnet` (via apt) so mason's ruby/dotnet
tools install.

**The python bucket is explicitly out of scope here** — `pip`/`venv` belong to
the `python` module (slice 4). Those four mason tools stay failing until slice 4.

## Guiding principle: additive, explicit arch/ubuntu lines

Same contract as slices 1–3. The Arch path is untouched: the asdf module's
existing `pacman` (`dotnet-sdk`, `libyaml`) and `aur` (`asdf-vm`) blocks still
auto-gate to Arch, and the install.sh `arch)` arm already installs
`nodejs ruby`. This slice only adds Ubuntu behavior.

## Why asdf ruby (not apt system ruby)

The user may need different ruby versions per project. apt `ruby` gives a single
system ruby (3.2) with no version switching; asdf ruby gives per-project versions
via `.tool-versions`, matching the Arch setup. The cost is that the asdf `ruby`
plugin compiles ruby from source, which needs the `ruby-build` dependency chain
installed first. That heavier path is the trade accepted for version flexibility.

## Why apt dotnet (not asdf dotnet)

dotnet is not asdf-managed on Arch either — it is a plain `pacman dotnet-sdk`
package. Ubuntu 24.04 ships `dotnet-sdk-8.0` (8.0.127) in its **native** repos,
so no Microsoft apt repo is needed. A single apt package gives `dotnet`, which is
all mason's `csharp-language-server` / `coreclr` need.

## Changes

### `modules/asdf/module.toml`

The asdf module currently has no apt block. Add one (after the existing aur
block). Keep the pacman and aur blocks unchanged (they gate to Arch).

```toml
[[packages]]
manager = "apt"
names = [
  "dotnet-sdk-8.0",
  "autoconf", "patch", "build-essential", "rustc", "libssl-dev", "libyaml-dev",
  "libreadline-dev", "zlib1g-dev", "libgmp-dev", "libncurses-dev",
  "libffi-dev", "libgdbm-dev", "libdb-dev", "uuid-dev",
]
```

- `dotnet-sdk-8.0` — provides `dotnet`.
- The remaining packages are the `ruby-build` dependency chain (per ruby-build's
  documented Ubuntu/Debian suggested-build-environment list) so the asdf `ruby`
  plugin can compile ruby from source. `build-essential` is likely already
  present from `bootstrap.sh`, but apt is idempotent so listing it is harmless.
- `rustc` is included so the ruby compile enables YJIT (Ruby's Rust-based JIT,
  available on 3.2+). Without it the build still succeeds — `./configure` detects
  rustc's absence and silently disables YJIT — but YJIT is worth having on a dev
  box, so it is listed. Modern package names are used throughout (`libncurses-dev`,
  `libreadline-dev` — not the obsolete `libncurses5-dev`/`libreadline6-dev` from
  old ruby-build docs, which no longer exist on 24.04).

### `modules/asdf/install.sh`

In the `ubuntu)` arm, change the plugin set from node-only to node + ruby:

```sh
  ubuntu)
    # asdf is a Go binary on the 0.16+ rewrite; go ships from bootstrap.
    command -v go >/dev/null || sudo apt-get install -y golang-go
    command -v asdf >/dev/null || go install github.com/asdf-vm/asdf/cmd/asdf@latest
    export PATH="$HOME/go/bin:$PATH"   # go install target, for this script run
    plugins="nodejs ruby"
    ;;
```

The plugin-install loop below is unchanged; it now also adds the `ruby` plugin,
runs `asdf install ruby <latest>` (source compile, using the apt build deps), and
`asdf set -u ruby <latest>`.

**Ordering:** quill runs all declarative actions (the apt block) before any
install.sh, so the build deps and dotnet are present by the time install.sh
compiles ruby — and by the time mason later shells out to `gem`/`dotnet`.

## Testing / verification

No Go changes → no Go unit tests. Verification is script-level + live:

- `bash -n modules/asdf/install.sh` passes.
- `go build ./cmd/quill` succeeds; `quill status` lists `asdf` without parse
  errors (apt block active on this box; pacman/aur gated out).
- `./bin/quill apply asdf` on this Ubuntu box (interactive, sudo primed): apt
  installs `dotnet-sdk-8.0` + the ruby-build deps; install.sh adds the asdf
  `ruby` plugin and compiles the latest ruby (slow first run); re-run is
  idempotent (node + ruby already at latest → loop no-ops; apt packages present
  → skipped).
- Post-apply, `dotnet --version`, `ruby --version`, and `gem --version` all
  resolve.
- In nvim, `:MasonInstall ruby-lsp rubocop csharp-language-server` (or simply
  reopening nvim so mason-tool-installer retries) now succeeds for these three.
- Arch path unchanged: pacman/aur blocks still gate to Arch; the `arch)` arm
  still installs `nodejs ruby`.

## Scope boundaries

**In scope (this slice):** asdf module provides `dotnet` (apt) and asdf-managed
`ruby` (with build deps) on Ubuntu, fixing mason's dotnet + ruby tools.

**Out of scope:** the python mason tools (`debugpy`, `isort`, `black`, `pylint`)
— they need `pip`/`venv` from the `python` module (slice 4) and stay failing
until then. The `ai` module (also slice 4).

**Permanent out of scope (unchanged):** macOS / other distros; secrets
management; `quill remove`.

## Open questions

None. Ruby method (asdf, for version flexibility), dotnet method (native apt
`dotnet-sdk-8.0`), and module ownership (asdf module) all resolved during
brainstorming.
