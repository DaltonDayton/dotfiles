# Obsidian second-brain setup on WSL

Goal: replicate the desktop machine's Obsidian + Claude Code vault integration on this WSL/Ubuntu machine. The desktop setup has six pieces; most transfer via git clone plus one skill file. The Obsidian app itself is the only piece that needs a decision.

## Desktop setup inventory (what we are replicating)

1. **Obsidian app**: installed via pacman through the dotfiles `modules/obsidian` module (module is `os = ["arch"]`, so it does nothing on WSL; that is expected).
2. **Vault**: `~/vaults/Personal`, a private git repo (`git@github.com:DaltonDayton/personal_notes.git`). The vault carries its own `CLAUDE.md`, folder conventions (`1 - Fleeting Notes/` through `6 - Main Notes/`), templates, and the `graphify-out/` knowledge graph. Community plugins in use: `obsidian-git` (auto-sync), `better-word-count`, `obsidian-relative-line-numbers`, `smart-random-note`. Plugin configs live in `.obsidian/` inside the repo, so they travel with the clone.
3. **obsidian-cli**: `~/.local/bin/obsidian-cli`, a symlink to the Obsidian launcher. It remote-controls a *running* Obsidian app; it is not headless.
4. **Claude Code skill**: `~/.claude/skills/obsidian-vault/SKILL.md` (plain file, not dotfiles-managed). Full content embedded below.
5. **graphify**: `~/.local/bin/graphify` binary + `~/.claude/skills/graphify/` skill. The vault's `graphify-out/` provides semantic Q&A over the notes.
6. **Sync model**: the `obsidian-git` plugin auto-commits and pushes; the skill forbids manual git inside the vault on the desktop.

## Decision to make first (ASK THE USER before proceeding)

Where should the Obsidian app run, if at all? Three options:

- **A. No app on this machine (recommended starting point).** Clone the vault into WSL, install the skill, use the skill's file-based fallback flow for captures and graphify for queries. No obsidian-cli. Least moving parts; upgrade later if wanted.
- **B. Windows-side Obsidian.** Install Obsidian on Windows and open the vault via `\\wsl$\Ubuntu\home\<user>\vaults\Personal`. Human gets the full UI and obsidian-git sync; Claude in WSL still uses the file-based fallback because the WSL shell cannot drive the Windows app through obsidian-cli.
- **C. Linux Obsidian under WSLg.** Works on Windows 11; install the `.deb` from Obsidian's GitHub releases (not in apt). Only this option makes `obsidian-cli` usable from the WSL shell. Most setup effort.

The steps below assume **A**, with notes where B/C differ.

## Step 1: clone the vault

```bash
mkdir -p ~/vaults
git clone git@github.com:DaltonDayton/personal_notes.git ~/vaults/Personal
```

Requires the machine's SSH key to be added to the user's GitHub account (private repo). If the clone fails on auth, stop and ask the user to add the key.

Verify: `ls ~/vaults/Personal` shows the numbered folders (`0 - Files` … `6 - Main Notes`), `CLAUDE.md`, and `graphify-out/`.

## Step 2: install the skill

Write the following to `~/.claude/skills/obsidian-vault/SKILL.md`. This is the desktop skill with two WSL adaptations: the obsidian-cli sections are marked conditional (option A/B has no working CLI), and the sync guardrail is replaced (no obsidian-git plugin running means manual git is the sync mechanism here).

````markdown
---
name: obsidian-vault
description: Use when capturing knowledge into the Obsidian vault, querying the second brain / personal notes, or working with notes in ~/vaults/Personal - vault conventions, capture flow, graphify routing
---

# Obsidian Vault (Personal Second Brain)

Vault: `~/vaults/Personal`, vault name `Personal`.

This machine (WSL) has no running Obsidian app, so there is no `obsidian-cli`. All reads and writes are plain file operations following the conventions below. Semantic queries go through graphify.

## Folders

- `1 - Fleeting Notes/` - all new captures land here. Never create notes anywhere else.
- `2 - Source Material/` - processed sources (Books/Articles/Videos/Podcasts/Papers/Other).
- `3 - Tags/` - tag definitions. Tags are wiki-links to these files: `Tags: [[development]]`.
- `6 - Main Notes/` - mature interconnected notes. Do not create or edit here without asking.
- `0 - Files/` - attachments.

## Capturing a note

Create the file directly under `1 - Fleeting Notes/` with this exact shape:

```
08 Jul 2026 - 18:26
Status: #seed #ai
Tags: [[tag1]], [[tag2]]

# My Note Title

Content.

# References
- source URL or origin of this knowledge
```

Date format is exactly `DD MMM YYYY - HH:MM`. Every AI-created note carries `Status: #seed #ai` (the human removes `#ai` after reviewing; never remove it yourself). Fill in `Tags:` from existing files in `3 - Tags/` only; if none fits, leave empty rather than inventing one.

## Routing

- Semantic Q&A ("what do I know about X", cross-note synthesis): `cd ~/vaults/Personal && graphify query "X"`; `graphify explain "concept"` for one concept. The vault has `graphify-out/`.
- Exact lookup: grep/Read within the vault folders.
- All writes: plain file creation under `1 - Fleeting Notes/` per the shape above.

## Sync (differs from desktop)

The desktop syncs via the obsidian-git plugin. This machine has no app, so git is manual. At the START of any vault work run `git -C ~/vaults/Personal pull --ff-only`. After creating notes, ask the user before committing and pushing; use a plain `vault backup: <date>` style message matching obsidian-git's history.

## Guardrails

- Create and append only. Never mass-edit, move, or delete the user's notes without asking (deleting your own just-created test/scratch notes is fine).
- Do not promote note statuses (#seed -> #sapling -> #evergreen); that is the human's job.
- Never remove `#ai` from a Status line.
````

If the user chose option C (WSLg app + registered CLI), port the desktop skill instead: it adds the `obsidian-cli` command reference and keeps the "never run git" guardrail. The desktop copy is at `~/.claude/skills/obsidian-vault/SKILL.md` on the Arch machine; ask the user to paste it if needed.

## Step 3: graphify

Check whether graphify is already on this machine (`which graphify`, `ls ~/.claude/skills/graphify`). The desktop has the binary at `~/.local/bin/graphify` plus a `graphify` skill directory. If missing, ask the user how they installed graphify (it is not in the dotfiles repo); do not guess at an install method. The vault's `graphify-out/` came with the clone, so queries should work as soon as the binary exists. Verify with:

```bash
cd ~/vaults/Personal && graphify query "zettelkasten"
```

If `graphify-out/` is stale or was gitignored, rebuild with `/graphify` in a Claude session at the vault root.

## Step 4: verification

1. `git -C ~/vaults/Personal pull --ff-only` succeeds.
2. Create a throwaway note `1 - Fleeting Notes/WSL Smoke Test.md` following the skill's shape, confirm it matches the header format of an existing note in `6 - Main Notes/`, then delete it (do not commit it).
3. `graphify query` returns a scoped answer (if graphify installed).
4. In a fresh Claude session, ask "what do I know about zettelkasten" and confirm the obsidian-vault skill triggers and routes to graphify.

## Out of scope / notes

- Dotfiles `modules/obsidian` stays arch-only. If option B or C is chosen and it sticks, extending the module for WSL is a separate dotfiles task on the desktop.
- The `~/vaults/Work` directory on the desktop is empty scaffolding; nothing to migrate.
- Do not enable the obsidian-git plugin expectation on this machine unless an app is actually running (option C); the skill above owns sync manually instead.
