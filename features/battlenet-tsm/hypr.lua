-- Float on the right edge of workspace 4: TSM on top, the launcher below.
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
