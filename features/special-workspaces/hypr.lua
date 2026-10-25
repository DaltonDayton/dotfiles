-- == Obsidian on a special workspace (SUPER+ALT+O, move with SUPER+SHIFT+ALT+O)
-- Launches Obsidian when opened empty.
hl.workspace_rule({ workspace = "special:obsidian", on_created_empty = "obsidian", gaps_out = 25, gaps_in = 12 })
o.bind("SUPER + ALT + O", "Toggle Obsidian workspace", hl.dsp.workspace.toggle_special("obsidian"))
o.bind("SUPER + SHIFT + ALT + O", "Move window to Obsidian workspace", hl.dsp.window.move({ workspace = "special:obsidian", follow = true }))

-- == Agent browser (Playwright / chrome-devtools MCP) parked on a hidden workspace (SUPER+ALT+B)
-- Automation launches Chromium with --class=agent-browser (set in the MCP and
-- playwright-cli configs), so this never catches a Chromium opened by hand or an
-- Omarchy web app, and Omarchy's browser tile rule never matches it either.
-- Suppressing activation is what keeps it off screen when Playwright raises the window.
hl.workspace_rule({ workspace = "special:playwright", gaps_out = 20, gaps_in = 10 })
o.window({ class = "^agent-browser$" }, {
  float = true,
  size = { 1920, 1080 },
  center = true,
  workspace = "special:playwright silent",
  no_initial_focus = true,
  suppress_event = "activate activatefocus",
})
o.bind("SUPER + ALT + B", "Toggle Playwright workspace", hl.dsp.workspace.toggle_special("playwright"))
