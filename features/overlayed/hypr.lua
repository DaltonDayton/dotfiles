-- Transparent voice overlay: only the channel name and avatars are drawn, so
-- tiled it looks like a broken empty window. Float it small and pinned top-right.
o.window({ class = "^overlayed$" }, {
  float = true,
  pin = true,
  size = { 420, 600 },
  move = { "monitor_w-window_w-28", "60" },
  border_size = 0,
  no_shadow = true,
  no_blur = true,
})
