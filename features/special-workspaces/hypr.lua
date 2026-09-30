-- == Obsidian on a special workspace (SUPER+ALT+O, move with SUPER+SHIFT+ALT+O)
-- Launches Obsidian when opened empty.
hl.workspace_rule({ workspace = "special:obsidian", on_created_empty = "obsidian", gaps_out = 25, gaps_in = 12 })
o.bind("SUPER + ALT + O", "Toggle Obsidian workspace", hl.dsp.workspace.toggle_special("obsidian"))
o.bind("SUPER + SHIFT + ALT + O", "Move window to Obsidian workspace", hl.dsp.window.move({ workspace = "special:obsidian", follow = true }))

-- == Playwright's Chromium parked on a hidden workspace, never steals focus (SUPER+ALT+B)
-- The tag has to go first, or Omarchy's browser tile rule wins. Suppressing
-- activation is what keeps it off screen when Playwright raises the window.
hl.workspace_rule({ workspace = "special:playwright", gaps_out = 20, gaps_in = 10 })
o.window({ class = "^chromium$" }, { tag = "-chromium-based-browser" })
o.window({ class = "^chromium$" }, {
  float = true,
  size = { 1920, 1080 },
  center = true,
  workspace = "special:playwright silent",
  no_initial_focus = true,
  suppress_event = "activate activatefocus",
})
o.bind("SUPER + ALT + B", "Toggle Playwright workspace", hl.dsp.workspace.toggle_special("playwright"))
