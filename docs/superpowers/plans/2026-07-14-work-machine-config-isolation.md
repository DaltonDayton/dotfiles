# Work-machine Config Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Isolate this work machine's Claude settings drift from personal `main` via a base+local overlay merge, and land the generic WSL browser-shim / `BROWSER` / `jq` items, all on `main`, guarded for portability.

**Architecture:** `~/.claude/settings.json` stops being a symlink into the repo and becomes a generated file: a new `modules/ai/install.sh` deep-merges a tracked base (`modules/ai/files/claude/settings.json`) with a per-machine, out-of-repo `~/.claude/settings.local.json` using `jq '.[0] * .[1]'`. A new `wsl` module drops a WSL-guarded `wslview` shim. The shared `.zshrc` gains a WSL-guarded `BROWSER=wslview` export.

**Tech Stack:** Bash `install.sh` scripts, `jq`, quill module TOML, existing `modules/windows-terminal/test_install.sh` test pattern.

## Global Constraints

- Every `install.sh` and `test_install.sh` starts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- `install.sh` must be idempotent: exit 0 without writing when already in the desired state.
- These scripts use no `sudo` (none is needed); do not add any.
- `install.sh` scripts self-resolve their directory: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
- Test isolation follows `modules/windows-terminal/test_install.sh`: override paths via env vars, shadow binaries via a stub dir on `PATH`, never touch real `$HOME` or the network.
- Package-manager keys in `module.toml`: `pacman`, `aur`, `apt`.
- Run `chmod +x` on every new `install.sh` / `test_install.sh`.

---

### Task 1: Claude settings overlay merge

Replace the wholesale `settings.json` symlink with a generated file merged from a tracked base and an out-of-repo per-machine overlay. Add `jq` as the merge dependency.

**Files:**
- Create: `modules/ai/install.sh`
- Create: `modules/ai/test_install.sh`
- Create: `modules/ai/files/claude/settings.local.json.example`
- Modify: `modules/ai/module.toml` (drop the `settings.json` symlink; add `jq` to `pacman` and `apt` package lists)

**Interfaces:**
- Produces: `modules/ai/install.sh` reads `QUILL_CLAUDE_BASE` (default `$SCRIPT_DIR/files/claude/settings.json`), `QUILL_CLAUDE_LOCAL` (default `$HOME/.claude/settings.local.json`), `QUILL_CLAUDE_OUT` (default `$HOME/.claude/settings.json`). Writes the deep-merge `base * local` to `QUILL_CLAUDE_OUT`; local operand defaults to `{}` when the file is absent.
- Consumes: nothing from other tasks.

- [ ] **Step 1: Write the failing test**

Create `modules/ai/test_install.sh`:

```bash
#!/usr/bin/env bash
# Regression tests for install.sh's jq overlay merge: local overrides a base
# scalar, nested objects deep-merge, an absent local file yields the base
# verbatim, and a second run is a no-op. Isolation: QUILL_CLAUDE_* redirect
# base/local/out to a temp tree so nothing touches the real ~/.claude.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/install.sh"

pass=0
fail() { echo "FAIL: $1"; exit 1; }

run() {
  local root="$1"
  QUILL_CLAUDE_BASE="$root/base.json" \
  QUILL_CLAUDE_LOCAL="$root/local.json" \
  QUILL_CLAUDE_OUT="$root/out.json" \
    bash "$INSTALL"
}

# Case 1: local overrides a base scalar, deep-merges nested objects.
t1="$(mktemp -d)"
cat > "$t1/base.json" <<'JSON'
{ "model": "fable", "env": { "A": "1" }, "enabledPlugins": { "p1": true } }
JSON
cat > "$t1/local.json" <<'JSON'
{ "model": "opus", "env": { "B": "2" }, "enabledPlugins": { "p2": true } }
JSON
run "$t1"
[ "$(jq -r '.model' "$t1/out.json")" = "opus" ] || fail "local scalar did not override base"
[ "$(jq -r '.env.A' "$t1/out.json")" = "1" ] || fail "base nested key lost"
[ "$(jq -r '.env.B' "$t1/out.json")" = "2" ] || fail "local nested key missing"
[ "$(jq -r '.enabledPlugins.p1' "$t1/out.json")" = "true" ] || fail "base plugin lost"
[ "$(jq -r '.enabledPlugins.p2' "$t1/out.json")" = "true" ] || fail "local plugin missing"
pass=$((pass+1))

# Case 2: absent local file yields the base verbatim (semantically equal).
t2="$(mktemp -d)"
cat > "$t2/base.json" <<'JSON'
{ "model": "fable", "enabledPlugins": { "p1": true } }
JSON
run "$t2"
[ "$(jq -S . "$t2/out.json")" = "$(jq -S . "$t2/base.json")" ] || fail "absent local did not yield base"
pass=$((pass+1))

# Case 3: idempotent second run leaves output byte-identical.
before="$(cat "$t1/out.json")"
run "$t1"
[ "$(cat "$t1/out.json")" = "$before" ] || fail "second run changed output"
pass=$((pass+1))

echo "ok ($pass cases)"
```

`chmod +x modules/ai/test_install.sh`.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash modules/ai/test_install.sh`
Expected: FAIL — `install.sh` does not exist yet (`bash: modules/ai/install.sh: No such file or directory`).

- [ ] **Step 3: Write the merge script**

Create `modules/ai/install.sh`:

```bash
#!/usr/bin/env bash
# Generate ~/.claude/settings.json by deep-merging the tracked base with a
# per-machine, out-of-repo overlay. jq's `*` merges objects key-by-key and
# lets the local operand win on scalar conflicts (e.g. model). Idempotent:
# rewrite only when the merged result differs from what's already there.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${QUILL_CLAUDE_BASE:=$SCRIPT_DIR/files/claude/settings.json}"
: "${QUILL_CLAUDE_LOCAL:=$HOME/.claude/settings.local.json}"
: "${QUILL_CLAUDE_OUT:=$HOME/.claude/settings.json}"

local_json='{}'
[ -f "$QUILL_CLAUDE_LOCAL" ] && local_json="$(cat "$QUILL_CLAUDE_LOCAL")"

# jq aborts (set -e) on malformed JSON — fail loud rather than emit garbage.
merged="$(jq -s '.[0] * .[1]' "$QUILL_CLAUDE_BASE" <(printf '%s' "$local_json"))"

if [ -f "$QUILL_CLAUDE_OUT" ] && [ "$merged" = "$(cat "$QUILL_CLAUDE_OUT")" ]; then
  exit 0
fi

mkdir -p "$(dirname "$QUILL_CLAUDE_OUT")"
printf '%s\n' "$merged" > "$QUILL_CLAUDE_OUT"
```

`chmod +x modules/ai/install.sh`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash modules/ai/test_install.sh`
Expected: PASS — `ok (3 cases)`.

- [ ] **Step 5: Drop the symlink and add the jq dependency**

In `modules/ai/module.toml`, delete this block:

```toml
[[symlinks]]
src = "files/claude/settings.json"
dst = "~/.claude/settings.json"
```

Add `"jq"` to both package lists:

```toml
[[packages]]
manager = "pacman"
names   = ["opencode", "socat", "jq"]
```

```toml
[[packages]]
manager = "apt"
names = ["socat", "jq"]
```

(Leave the `CLAUDE.md`, `rules`, `stacks`, and opencode symlinks untouched.)

- [ ] **Step 6: Write the overlay example**

Create `modules/ai/files/claude/settings.local.json.example`:

```json
{
  "//": "Per-machine Claude settings overlay. Copy to ~/.claude/settings.local.json (outside this repo). ai/install.sh deep-merges base * local, local wins on conflicts. To disable a base plugin on this machine, set it to false here.",
  "model": "opus[1m]",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "enabledPlugins": {
    "atlassian@claude-plugins-official": true
  }
}
```

- [ ] **Step 7: Verify the module still parses and applies**

Run: `go build -o ./bin/quill ./cmd/quill && ./bin/quill apply ai`
Expected: build succeeds; `apply` completes without error (on this WSL machine it installs `jq` if missing, then generates `~/.claude/settings.json`).

- [ ] **Step 8: Commit**

```bash
git add modules/ai/install.sh modules/ai/test_install.sh \
  modules/ai/files/claude/settings.local.json.example modules/ai/module.toml
git commit -m "feat(ai): generate settings.json from base+local overlay merge"
```

---

### Task 2: Migrate this machine's settings drift into the overlay

Move the current uncommitted `settings.json` drift out of the tracked base and into this machine's out-of-repo overlay, then restore the base to `HEAD`. This is a machine-local step; it touches `~/.claude` and reverts a tracked file.

**Files:**
- Create (outside repo): `~/.claude/settings.local.json`
- Restore: `modules/ai/files/claude/settings.json` (to `HEAD`)

**Interfaces:**
- Consumes: `modules/ai/install.sh` from Task 1.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Confirm the drift about to be migrated**

Run: `git diff modules/ai/files/claude/settings.json`
Expected: shows the local additions — `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, `alwaysThinkingEnabled`, `skipWorkflowUsageWarning`, `model` `opus[1m]`, and the `atlassian` + `pr-review-toolkit` plugin enables. If the diff differs from this, stop and reconcile before proceeding.

- [ ] **Step 2: Write the machine overlay**

Create `~/.claude/settings.local.json`:

```json
{
  "model": "opus[1m]",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "alwaysThinkingEnabled": true,
  "skipWorkflowUsageWarning": true,
  "enabledPlugins": {
    "atlassian@claude-plugins-official": true,
    "pr-review-toolkit@claude-plugins-official": true
  }
}
```

- [ ] **Step 3: Restore the tracked base to HEAD**

Run: `git checkout -- modules/ai/files/claude/settings.json`
Expected: `git status` shows the file no longer modified; the base is back to personal defaults (model `fable`).

- [ ] **Step 4: Regenerate and verify the merged result**

Run: `./bin/quill apply ai && jq -r '.model, .enabledPlugins["atlassian@claude-plugins-official"], .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' ~/.claude/settings.json`
Expected output:
```
opus[1m]
true
1
```
(model from local, plugin merged in, base plugins still present — spot-check one: `jq -r '.enabledPlugins["superpowers@claude-plugins-official"]' ~/.claude/settings.json` should print `true`.)

- [ ] **Step 5: Confirm the tree is clean**

Run: `git status --short`
Expected: no modification to `modules/ai/files/claude/settings.json`. (No commit in this task; it only reverts a tracked file and writes an out-of-repo file.)

---

### Task 3: `wsl` module with the wslview shim

Add a WSL-guarded module that drops the `wslview` browser shim, and wire it into the `wsl` profile.

**Files:**
- Create: `modules/wsl/module.toml`
- Create: `modules/wsl/install.sh`
- Create: `modules/wsl/test_install.sh`
- Modify: `profiles/wsl.toml` (add `"wsl"` to `modules`)

**Interfaces:**
- Produces: `modules/wsl/install.sh` reads `QUILL_PROC_VERSION` (default `/proc/version`) and `QUILL_LOCAL_BIN` (default `$HOME/.local/bin`); writes `$QUILL_LOCAL_BIN/wslview` only under WSL when no real `wslview` (a resolved path other than the shim itself) is on `PATH`.
- Consumes: nothing from other tasks.

- [ ] **Step 1: Write the failing test**

Create `modules/wsl/test_install.sh`:

```bash
#!/usr/bin/env bash
# Regression tests for the wslview shim: written under the WSL guard when no
# real wslview is on PATH, skipped when a real wslview exists, and a clean
# no-op when the guard does not match. Isolation: QUILL_PROC_VERSION points at
# a fixture file, QUILL_LOCAL_BIN at a temp dir, and PATH is controlled per case.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/install.sh"

pass=0
fail() { echo "FAIL: $1"; exit 1; }

# Case 1: WSL guard matches, no wslview on PATH -> shim written + executable.
t1="$(mktemp -d)"
printf 'Linux version 5.15 microsoft-standard-WSL2\n' > "$t1/procversion"
QUILL_PROC_VERSION="$t1/procversion" QUILL_LOCAL_BIN="$t1/bin" PATH="/usr/bin:/bin" \
  bash "$INSTALL"
[ -x "$t1/bin/wslview" ] || fail "shim not written/executable under WSL"
grep -q 'Start-Process' "$t1/bin/wslview" || fail "shim body wrong"
pass=$((pass+1))

# Case 2: a real wslview exists on PATH -> shim skipped.
t2="$(mktemp -d)"
printf 'Linux version 5.15 microsoft-standard-WSL2\n' > "$t2/procversion"
mkdir -p "$t2/realbin"; printf '#!/bin/sh\n' > "$t2/realbin/wslview"; chmod +x "$t2/realbin/wslview"
QUILL_PROC_VERSION="$t2/procversion" QUILL_LOCAL_BIN="$t2/bin" PATH="$t2/realbin:/usr/bin:/bin" \
  bash "$INSTALL"
[ ! -e "$t2/bin/wslview" ] || fail "shim written despite real wslview on PATH"
pass=$((pass+1))

# Case 3: guard does not match (not WSL) -> no-op.
t3="$(mktemp -d)"
printf 'Linux version 5.15 generic\n' > "$t3/procversion"
QUILL_PROC_VERSION="$t3/procversion" QUILL_LOCAL_BIN="$t3/bin" PATH="/usr/bin:/bin" \
  bash "$INSTALL"
[ ! -e "$t3/bin/wslview" ] || fail "shim written off WSL"
pass=$((pass+1))

echo "ok ($pass cases)"
```

`chmod +x modules/wsl/test_install.sh`.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash modules/wsl/test_install.sh`
Expected: FAIL — `modules/wsl/install.sh` does not exist.

- [ ] **Step 3: Write the module install script**

Create `modules/wsl/install.sh`:

```bash
#!/usr/bin/env bash
# Drop a minimal wslview shim so browser-opening (az login, xdg-open) works on
# WSL, where Ubuntu 26.04 dropped wslu from its repos. WSL-only: off WSL this is
# a clean no-op, keeping the module portable to bare-Ubuntu profiles.
set -euo pipefail

: "${QUILL_PROC_VERSION:=/proc/version}"
: "${QUILL_LOCAL_BIN:=$HOME/.local/bin}"

SHIM="$QUILL_LOCAL_BIN/wslview"

grep -qiE microsoft "$QUILL_PROC_VERSION" 2>/dev/null || exit 0

# Skip if a real wslview (anything other than our own shim) is on PATH — Ubuntu
# may restore wslu, which should win.
existing="$(command -v wslview 2>/dev/null || true)"
[ -n "$existing" ] && [ "$existing" != "$SHIM" ] && exit 0

read -r -d '' body <<'EOF' || true
#!/bin/sh
# Minimal wslview: open URL/path in Windows default browser (wslu unavailable
# on Ubuntu 26.04).
exec powershell.exe -NoProfile -Command "Start-Process '$*'" </dev/null >/dev/null 2>&1
EOF

if [ -f "$SHIM" ] && [ "$(cat "$SHIM")" = "$body" ]; then
  exit 0
fi

mkdir -p "$QUILL_LOCAL_BIN"
printf '%s\n' "$body" > "$SHIM"
chmod +x "$SHIM"
```

`chmod +x modules/wsl/install.sh`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash modules/wsl/test_install.sh`
Expected: PASS — `ok (3 cases)`.

- [ ] **Step 5: Write the module manifest**

Create `modules/wsl/module.toml`:

```toml
name        = "wsl"
description = "WSL-only fixes: wslview browser shim"
os          = ["ubuntu"]
```

- [ ] **Step 6: Wire the module into the wsl profile**

In `profiles/wsl.toml`, add `"wsl"` to the `modules` list:

```toml
modules = ["git", "shell", "tmux", "neovim", "ai", "python", "asdf", "windows-terminal", "wsl"]
```

- [ ] **Step 7: Verify parse and apply**

Run: `go build -o ./bin/quill ./cmd/quill && ./bin/quill apply wsl && test -x ~/.local/bin/wslview && echo shim-ok`
Expected: build succeeds; `apply` runs; prints `shim-ok` (this machine is WSL).

- [ ] **Step 8: Commit**

```bash
git add modules/wsl/module.toml modules/wsl/install.sh modules/wsl/test_install.sh profiles/wsl.toml
git commit -m "feat(wsl): add module with WSL-guarded wslview shim"
```

---

### Task 4: WSL-guarded `BROWSER` in the shared `.zshrc`

Own `BROWSER=wslview` in the shared `.zshrc`, guarded so it is a no-op off WSL, and retire the manual `~/.zshenv` line on this machine.

**Files:**
- Modify: `modules/shell/files/.zshrc` (after the `~/.local/bin` PATH export at line 4)

**Interfaces:**
- Consumes: nothing.
- Produces: a `BROWSER` export active only under WSL.

- [ ] **Step 1: Add the guarded export**

In `modules/shell/files/.zshrc`, immediately after the line:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

insert:

```zsh

# WSL: route browser-opening (az login, xdg-open) through the wslview shim.
if grep -qiE microsoft /proc/version 2>/dev/null; then
  export BROWSER=wslview
fi
```

- [ ] **Step 2: Verify it takes effect under WSL**

Run: `zsh -c 'source modules/shell/files/.zshrc; echo "BROWSER=$BROWSER"'`
Expected: `BROWSER=wslview` on this WSL machine. (Off WSL the block is skipped and `BROWSER` stays unset — no failure.)

- [ ] **Step 3: Retire the manual `~/.zshenv` line (machine step)**

The dotfiles now own `BROWSER`. Remove the manual line from `~/.zshenv` so it does not shadow or duplicate the managed one:

Run: `grep -n 'BROWSER' ~/.zshenv 2>/dev/null || echo "none"`
If a `BROWSER=wslview` line is present, delete that single line from `~/.zshenv` (leave the rest of the file intact). Re-run the grep to confirm it is gone.

- [ ] **Step 4: Commit**

```bash
git add modules/shell/files/.zshrc
git commit -m "feat(shell): export BROWSER=wslview under WSL"
```

---

## Notes for the implementer

- PATH precondition: `modules/shell/files/.zshrc:4` already exports `~/.local/bin`, which the shim depends on. No change needed; do not add a second PATH export.
- The overlay trade-off: once `settings.json` is generated (Task 1), `quill apply` reclobbers any runtime edits Claude Code writes to `~/.claude/settings.json`. Keep-worthy runtime tweaks must be copied into `~/.claude/settings.local.json` by hand.
- Nothing sensitive (registry names, subscription IDs, internal hosts) belongs in any of these files; that data lives in Claude project memory, per the work-setup audit.
