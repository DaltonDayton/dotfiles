# Spec: WSL/Ubuntu support — git + asdf modules (slice 2)

**Date:** 2026-06-10
**Status:** Draft (pending review)

## Problem

Slice 1 shipped the WSL/Ubuntu foundation (OS detection, `apt` driver,
manager→OS package gating, the `os = []` action field, `$QUILL_OS` for
install.sh, the `bootstrap.sh` ubuntu branch, and the `Dalton` host) plus the
`shell` module. The `Dalton` host lists `git` and `asdf`, but those modules are
still Arch-only: their packages install via `pacman`/`aur`, so on Ubuntu they
either no-op or produce nothing useful.

This slice makes `git` and `asdf` work on Ubuntu — **additively**, with the Arch
path behaving identically. `asdf` matters because it provides Node, which the
`ai` module's `claude`/`opencode` depend on (slice 4).

This slice has **no Go code changes** — the foundation already handles gating
and `$QUILL_OS`. It is entirely `module.toml` apt blocks and `install.sh`
ubuntu branches.

## Guiding principle: additive, explicit arch/ubuntu lines

Same contract as slice 1. The Arch path is untouched: existing `pacman`/`aur`
package blocks auto-gate to Arch via the manager→OS rule, and every new
`install.sh` branch is a full `case "$QUILL_OS"` with an explicit `arch)` arm
(a no-op `:` where the declarative block already covers Arch). Every module
below documents an explicit arch-vs-ubuntu table.

## git module

### Package lines

| Tool | Arch (`pacman`) | Ubuntu |
|------|-----------------|--------|
| git | pacman `git` | apt `git` |
| openssh | pacman `openssh` | apt `openssh-client` (client only — no sshd on a WSL dev box) |
| bat | pacman `bat` | apt `bat` (binary is `batcat`; the `bat` shim is created by the `shell` module) |
| man-db | pacman `man-db` | apt `man-db` |
| gh | pacman `github-cli` | **install.sh** — not in default Ubuntu repos; add the GitHub apt repo, then `apt install gh` |

### `modules/git/module.toml`

Keep the existing pacman block. Add:

```toml
[[packages]]
manager = "apt"
names = ["git", "openssh-client", "bat", "man-db"]
```

`gh` is deliberately NOT in the apt block — `apt-get install gh` fails until the
GitHub apt repo is configured, so it lives in install.sh.

The `gitconfig.tmpl` symlink and the `gh auth login` todo are OS-agnostic and
unchanged.

### `modules/git/install.sh` (new, `chmod +x`)

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

Idempotent: the whole ubuntu block is guarded by `command -v gh`. The
`tee`/`apt-get` steps are themselves re-runnable, but the guard keeps re-applies
silent and network-free once gh exists.

## asdf module

### Package / runtime lines

| Item | Arch | Ubuntu |
|------|------|--------|
| asdf itself | aur `asdf-vm` (declarative) | install.sh: `go install github.com/asdf-vm/asdf/cmd/asdf@latest` |
| runtimes | nodejs + ruby | **nodejs only** (Node is a prebuilt download — no compiler/build deps) |
| dotnet | pacman `dotnet-sdk` | **skip** |
| libyaml | pacman `libyaml` (ruby build dep) | **skip** (no ruby) |

Rationale for node-only: ruby via asdf compiles from source on Ubuntu, pulling a
heavy `ruby-build` apt dependency chain (libssl-dev, libreadline-dev, zlib1g-dev,
libyaml-dev, …) that isn't needed on the WSL dev box. The asdf `nodejs` plugin
downloads official prebuilt Node binaries, so it needs no apt build deps.

### `modules/asdf/module.toml`

**No apt block is added** — on Ubuntu this module installs nothing declaratively
(asdf + node are handled in install.sh; ruby/dotnet/libyaml are skipped). Keep
the existing pacman (`dotnet-sdk`, `libyaml`) and aur (`asdf-vm`) blocks; the
manager→OS rule auto-skips them on Ubuntu.

### `modules/asdf/install.sh` (restructure existing)

The current script unconditionally loops `for plugin in nodejs ruby`. Wrap it in
an OS `case` that (a) on Ubuntu first ensures `go` and installs asdf, and (b)
selects the plugin set per OS. The plugin-install loop body is unchanged.

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

`QUILL_OS` is always set by the runner (slice 1), so the `case` is `set -u`-safe
under quill. The `$HOME/go/bin` PATH prepend covers a fresh box where that dir
isn't yet on PATH for this script's process (the symlinked `.zshrc` already adds
it for interactive shells).

## Testing / verification

No Go changes → no Go unit tests. Verification is script-level:

- `bash -n modules/git/install.sh` and `bash -n modules/asdf/install.sh` pass;
  both scripts are `chmod +x`.
- `./bin/quill apply git asdf` on this Ubuntu box: declarative apt actions apply;
  install.sh branches run. On this box `gh`/`asdf`/`node` already exist, so the
  `command -v` guards skip — confirming idempotency. Re-run shows no installs.
- Fresh-box reasoning: on a clean Ubuntu, git/openssh-client/bat/man-db install
  via apt; gh installs via the GitHub repo; asdf installs via `go install`
  (go self-healed via apt if absent); node installs via the asdf nodejs plugin.
- Arch path unchanged: pacman/aur blocks still gate to Arch; the `arch)` arms
  reproduce prior install.sh behavior (nodejs+ruby; gh from github-cli package).

## Scope boundaries

**In scope (this slice):** `git` and `asdf` modules Ubuntu-ready (apt blocks +
install.sh ubuntu branches), node-only runtime, gh via GitHub apt repo, asdf via
`go install`.

**Out of scope (later slices):** tmux + neovim (slice 3); python + ai (slice 4).
dotnet and ruby on Ubuntu (intentionally skipped; can be revisited if WSL work
ever needs them).

**Permanent out of scope (unchanged):** macOS / other distros; secrets
management; `quill remove`.

## Open questions

None. All scope decisions (node-only, skip dotnet, `go install` asdf, gh via apt
repo) resolved during brainstorming.
