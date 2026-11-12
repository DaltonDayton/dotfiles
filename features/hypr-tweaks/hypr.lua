-- == Move windows (SUPER+CTRL+ALT+arrows)
-- (The old SUPER+SHIFT+CTRL+arrow resize keys are gone: Omarchy 4.5 binds
-- that chord to "move window to monitor". Resize with SUPER + -/= instead.)
-- Move windows: re-tiles (unlike Omarchy's SUPER+SHIFT+arrows swap), or
-- nudges 30px when floating.
local function move_win(dx, dy, dir)
  return function()
    local w = hl.get_active_window()
    if w ~= nil and w.floating then
      hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
    else
      hl.dispatch(hl.dsp.window.move({ direction = dir }))
    end
  end
end

o.bind("SUPER + CTRL + ALT + Left", "Move window left", move_win(-30, 0, "l"), { repeating = true })
o.bind("SUPER + CTRL + ALT + Right", "Move window right", move_win(30, 0, "r"), { repeating = true })
o.bind("SUPER + CTRL + ALT + Up", "Move window up", move_win(0, -30, "u"), { repeating = true })
o.bind("SUPER + CTRL + ALT + Down", "Move window down", move_win(0, 30, "d"), { repeating = true })

-- == New tiled windows open on the side of the cursor
-- Omarchy's default (2) always splits right/bottom.
hl.config({ dwindle = { force_split = 0 } })

-- == Natural (inverse) touchpad scrolling
hl.config({ input = { touchpad = { natural_scroll = true } } })

-- == Tile Steam's main window (Omarchy floats it)
-- Anchored so it doesn't also match steam_app_battlenet.
o.window({ class = "^steam$", title = "^Steam$" }, { tile = true })

-- == Keep Firefox fully opaque on YouTube
o.window({ class = "^[Ff]irefox$", title = ".*YouTube.*" }, {
  opacity = "1 override 1 override 1 override",
})

-- == Pull floating dialogs that open off-screen back to the monitor's centre
-- XWayland sees the stacked monitors side by side, so some X11 dialogs (Unity's
-- Neovim Settings, Unreal's startup toasts) land a monitor-width off the left
-- edge, invisible. Only windows with a real title: Unity (and other X11 apps)
-- park untitled helper windows off-screen on purpose, and dragging those into
-- view leaves Unity thinking a popup is open, which blocks script reloads.
-- Checked at open and once more 250 ms later, for clients that place their
-- window after mapping. Tiled windows are never touched.
local function has_real_title(w)
  local t = (w.title or ""):lower()
  return t ~= "" and t ~= (w.class or ""):lower() and t ~= (w.initial_class or ""):lower()
end

local function recentre_if_offscreen(w)
  if not w.floating or w.monitor == nil or not has_real_title(w) then
    return
  end
  local m = w.monitor
  local off = w.at.x + w.size.x <= m.x
    or w.at.x >= m.x + m.width
    or w.at.y + w.size.y <= m.y
    or w.at.y >= m.y + m.height
  if off then
    hl.dispatch(hl.dsp.window.center({ window = "address:" .. w.address }))
  end
end

hl.on("window.open", function(w)
  recentre_if_offscreen(w)
  hl.timer(function()
    if w.mapped then
      recentre_if_offscreen(w)
    end
  end, { timeout = 250, type = "oneshot" })
end)

-- == Don't let apps steal focus (Omarchy default: focus_on_activate = true)
-- Activation requests just mark the window urgent, as in the pre-Omarchy setup.
-- warp_on_change_workspace off so a focus change elsewhere can't drag the cursor.
hl.config({
  misc = { focus_on_activate = false },
  cursor = { warp_on_change_workspace = 0 },
})

-- == Floating windows follow their workspace back after a monitor reconnects
-- When a monitor drops its link in standby, its workspaces move to the other
-- one; on wake the workspaces return (per the workspace rules) and tiled
-- windows re-lay out, but floating windows keep the pixel position they got
-- on the other monitor and are left stranded there. Translate each float by
-- the monitor offset so TSM, Battle.net and friends keep their layout. X11
-- windows (WoW) can also end up a monitor-width off-screen, as on open above,
-- so those get the same recentre.
local function monitor_at(x, y)
  for _, m in ipairs(hl.get_monitors()) do
    if x >= m.x and x < m.x + m.width and y >= m.y and y < m.y + m.height then
      return m
    end
  end
end

local function pull_floats_home()
  for _, w in ipairs(hl.get_windows({ floating = true, mapped = true })) do
    local home, here = w.monitor, monitor_at(w.at.x, w.at.y)
    if here == nil then
      recentre_if_offscreen(w)
    elseif home and here.name ~= home.name then
      hl.dispatch(hl.dsp.window.move({
        x = w.at.x - here.x + home.x,
        y = w.at.y - here.y + home.y,
        window = "address:" .. w.address,
      }))
    end
  end
end

for _, ev in ipairs({ "monitor.added", "monitor.layout_changed", "workspace.move_to_monitor" }) do
  hl.on(ev, function()
    hl.timer(pull_floats_home, { timeout = 500, type = "oneshot" })
  end)
end

-- == F9 holds to dictate
-- Omarchy 4.5 binds Alt+Space (toggle) and Right Alt (hold) for dictation and
-- drives Superwhisper through `omarchy-dictation`. Superwhisper's own Lua
-- refuses to bind F9 on Omarchy (it assumes Omarchy owns it), so F9 is bound
-- here the same way Omarchy binds Right Alt. Superwhisper's shortcuts stay off
-- these keys (toggle Ctrl+Alt+Space, hold none) or each press fires twice.
if o.dictation_installed and o.dictation_installed() then
  o.bind_hold("F9", "Start dictation (push-to-talk)", "omarchy-dictation start",
    "Stop dictation (push-to-talk)", "omarchy-dictation stop")
end
