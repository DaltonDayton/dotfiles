# TODO

## quill: persistent install/apply log

Quill currently keeps no record of a run — the only persisted state is
`~/.local/state/quill/last_selection.json` (a UI preference). After the
2026-07-04 fresh install, the only record of what failed was a manual
terminal copy-paste.

Wanted: every `quill install` / `quill apply` writes a detailed log to
`~/.local/state/quill/logs/<timestamp>.log` — per-action outcomes
(applied/skipped/failed), full command output on failure, and install.sh
output. Design questions to settle in a plan first:

- Which layer writes it (runner emits events; a log sink alongside the TUI
  consumer fits the existing runner-never-imports-tui rule).
- Log rotation / retention (keep last N runs?).
- Whether `quill status` gets a `--last-run` view of the newest log.

Go through brainstorming → writing-plans per the repo workflow before
implementing.
