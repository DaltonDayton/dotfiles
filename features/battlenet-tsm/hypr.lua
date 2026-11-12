-- Float on the right edge of whatever workspace they open on: TSM on top, the launcher below.
-- TSM runs in its own prefix (class steam_app_tsm) inside a Wine virtual desktop of
-- this exact size (see battlenet-tsm), so the size here and there must match. The
-- move avoids window_w: the desktop window first requests the whole monitor, which
-- made monitor_w-window_w land it at x=-2.
o.window({ class = "^steam_app_tsm$" }, {
  float = true,
  size = { 1129, 530 },
  move = { "monitor_w-1132", "40" },
})
-- Battle.net's main window sometimes maps before its title is set, and in any case
-- restores its own saved 1280x800 centered geometry right after mapping, which
-- overrides a static rule. Place it once it has settled.
local function place_battlenet(window)
  local m = window.monitor
  if not m or window.title ~= "Battle.net" then return end
  local w, h = 1522, 856
  local target = "address:" .. window.address
  hl.dispatch(hl.dsp.window.float({ action = "on", window = target }))
  hl.dispatch(hl.dsp.window.resize({ x = w, y = h, relative = false, window = target }))
  hl.dispatch(hl.dsp.window.move({ x = m.x + math.floor(m.width / m.scale) - w - 2, y = m.y + 574, window = target }))
end
hl.on("window.open", function(window)
  if window.class ~= "steam_app_battlenet" then return end
  hl.timer(function() place_battlenet(window) end, { type = "oneshot", timeout = 1500 })
end)
-- Wine's activation requests otherwise warp the cursor on every open/close.
o.window({ class = "^steam_app_battlenet$" }, { focus_on_activate = false })
