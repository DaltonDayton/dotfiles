-- Float on the right edge of workspace 4: TSM on top, the launcher below.
-- TSM restores its own last size from window-state.json; the size here matches it.
o.window({ class = "^steam_app_battlenet$", title = "^TradeSkillMaster$" }, {
  workspace = "4",
  float = true,
  size = { 1131, 520 },
  move = { "monitor_w-window_w-2", "28" },
})
o.window({ class = "^steam_app_battlenet$", title = "^Battle\\.net$" }, {
  workspace = "4",
  float = true,
  size = { 1520, 890 },
  center = false,
  move = { "monitor_w-window_w-2", "540" },
})
-- Wine's activation requests otherwise warp the cursor on every open/close.
o.window({ class = "^steam_app_battlenet$" }, { focus_on_activate = false })
