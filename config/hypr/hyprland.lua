dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

require("default.hypr.toggles")

-- Tile Steam's main window (Omarchy floats it). Anchored so it doesn't also
-- match steam_app_battlenet.
o.window({ class = "^steam$", title = "^Steam$" }, { tile = true })

-- Keep Firefox opaque on YouTube.
o.window({ class = "^[Ff]irefox$", title = ".*YouTube.*" }, {
  opacity = "1 override 1 override 1 override",
})

-- Obsidian on its own special workspace (SUPER+ALT+O).
hl.workspace_rule({ workspace = "special:obsidian", on_created_empty = "obsidian", gaps_out = 25, gaps_in = 12 })

-- Playwright's headed Chromium: float it on a hidden workspace (SUPER+ALT+B)
-- and ignore its activation requests so it never steals focus. The tag has to
-- go first, or Omarchy's browser tile rule wins.
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

-- Battle.net + TSM (~/.local/bin/battlenet-tsm): float on the right edge of
-- workspace 4, TSM on top and the launcher below.
o.window({ class = "^steam_app_battlenet$", title = "^TradeSkillMaster Application.*" }, {
  workspace = "4",
  float = true,
  size = { 600, 600 },
  move = { "monitor_w-window_w-3", "27" },
})
o.window({ class = "^steam_app_battlenet$", title = "^TSM Login.*" }, {
  workspace = "4",
  float = true,
  move = { "monitor_w-window_w-3", "27" },
})
-- TSM's login dialog, centred on the main TSM window.
o.window({ class = "^steam_app_battlenet$", title = "^TSMApplication$" }, {
  workspace = "4",
  float = true,
  move = { "monitor_w-303-(window_w*0.5)", "327-(window_h*0.5)" },
})
o.window({ class = "^steam_app_battlenet$", title = "^Battle\\.net$" }, {
  workspace = "4",
  center = false,
  move = { "monitor_w-window_w-3", "631" },
})
-- Wine's activation requests otherwise warp the cursor on every open/close.
o.window({ class = "^steam_app_battlenet$" }, { focus_on_activate = false })
