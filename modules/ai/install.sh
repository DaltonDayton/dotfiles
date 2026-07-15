#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Generate ~/.claude/settings.json by deep-merging the tracked base with a
# per-machine, out-of-repo overlay. jq's `*` merges objects key-by-key and lets
# the local operand win on scalar conflicts (e.g. model). Idempotent: rewrite
# only when the merged result differs from what's already there.
: "${QUILL_CLAUDE_BASE:=$SCRIPT_DIR/files/claude/settings.json}"
: "${QUILL_CLAUDE_LOCAL:=$HOME/.claude/settings.local.json}"
: "${QUILL_CLAUDE_OUT:=$HOME/.claude/settings.json}"
: "${QUILL_CLAUDE_SNAP:=${XDG_STATE_HOME:-$HOME/.local/state}/quill/claude_settings.last.json}"

local_json='{}'
[ -f "$QUILL_CLAUDE_LOCAL" ] && local_json="$(cat "$QUILL_CLAUDE_LOCAL")"

# jq aborts (set -e) on malformed JSON — fail loud rather than emit garbage.
merged="$(jq -s '.[0] * .[1]' "$QUILL_CLAUDE_BASE" <(printf '%s' "$local_json"))"

# Migrate pre-overlay machines, where settings.json was a symlink into the
# repo: a symlinked output is always replaced, never compared or written
# through — that would clobber the tracked base.
[ -L "$QUILL_CLAUDE_OUT" ] && rm "$QUILL_CLAUDE_OUT"

# Drift guard: the snapshot holds whatever this script generated last time. If
# the live file no longer matches it, something (Claude Code /plugin installs,
# /config, hand edits) wrote to the generated file since — regenerating would
# silently destroy those edits. Fail loud and make reconciliation a choice.
# No snapshot (first run after this feature) means drift can't be told apart
# from a base update, so the guard is skipped once and the snapshot bootstraps.
if [ "${QUILL_CLAUDE_FORCE:-0}" != 1 ] && [ -f "$QUILL_CLAUDE_OUT" ] && [ -f "$QUILL_CLAUDE_SNAP" ] \
  && ! cmp -s "$QUILL_CLAUDE_OUT" "$QUILL_CLAUDE_SNAP" \
  && [ "$merged" != "$(cat "$QUILL_CLAUDE_OUT")" ]; then
  {
    echo "ai/install.sh: $QUILL_CLAUDE_OUT was edited since it was last generated; refusing to overwrite."
    echo "Runtime edits (last generated -> current):"
    diff -u "$QUILL_CLAUDE_SNAP" "$QUILL_CLAUDE_OUT" || true
    echo "Keep them by moving them into the tracked base ($QUILL_CLAUDE_BASE)"
    echo "or this machine's overlay ($QUILL_CLAUDE_LOCAL),"
    echo "or discard them: QUILL_CLAUDE_FORCE=1 ./bin/quill apply ai"
  } >&2
  exit 1
fi

snapshot() {
  mkdir -p "$(dirname "$QUILL_CLAUDE_SNAP")"
  printf '%s\n' "$merged" > "$QUILL_CLAUDE_SNAP"
}

if [ -f "$QUILL_CLAUDE_OUT" ] && [ "$merged" = "$(cat "$QUILL_CLAUDE_OUT")" ]; then
  snapshot
  exit 0
fi

mkdir -p "$(dirname "$QUILL_CLAUDE_OUT")"
# Write via temp + rename so a symlink or partial write can never corrupt the
# destination in place.
tmp="$(mktemp "$(dirname "$QUILL_CLAUDE_OUT")/.settings.json.XXXXXX")"
printf '%s\n' "$merged" > "$tmp"
mv "$tmp" "$QUILL_CLAUDE_OUT"
snapshot
