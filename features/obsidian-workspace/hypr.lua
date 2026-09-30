-- Launches Obsidian when opened empty.
hl.workspace_rule({ workspace = "special:obsidian", on_created_empty = "obsidian", gaps_out = 25, gaps_in = 12 })
o.bind("SUPER + ALT + O", "Toggle Obsidian workspace", hl.dsp.workspace.toggle_special("obsidian"))
o.bind("SUPER + SHIFT + ALT + O", "Move window to Obsidian workspace", hl.dsp.window.move({ workspace = "special:obsidian", follow = true }))
