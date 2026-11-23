-- Cheatsheet built from live keymaps (anything with a desc) grouped by
-- cheatsheet.groups. <leader>? opens a float; :Cheatsheet html writes a page.
local M = {}

local MODES = { "n", "x", "o", "i", "t" }
local MODE_LABEL = { n = "n", x = "v", o = "o", i = "i", t = "t", v = "v", s = "s" }
-- Runtime defaults and auto-pair internals that only add noise.
local IGNORE = { "^:", "which_key_ignore", "^MiniPairs", " action for .- pair$" }

local function groups_sorted()
  local gs = vim.deepcopy(require("cheatsheet.groups"))
  table.sort(gs, function(a, b) return #a.prefix > #b.prefix end)
  return gs
end

local function normalise(lhs)
  local leader = vim.g.mapleader or "\\"
  if lhs:sub(1, #leader) == leader then lhs = "<leader>" .. lhs:sub(#leader + 1) end
  return lhs:gsub("<Leader>", "<leader>")
end

local function add(acc, m, buffer)
  if not m.desc or m.desc == "" or m.lhs:find("<Plug>") then return end
  for _, pat in ipairs(IGNORE) do
    if m.desc:find(pat) then return end
  end
  local lhs = normalise(m.lhs):gsub("^ ", "<Space>"):gsub("<leader> $", "<leader><Space>")
  local key = lhs .. "\0" .. m.desc .. (buffer and "\0b" or "")
  local e = acc[key]
  if not e then
    e = { lhs = lhs, desc = m.desc, modes = {}, buffer = buffer }
    acc[key] = e
  end
  e.modes[m.mode == " " and "n" or m.mode] = true
end

--- Collect maps with a desc into { groups = { {title, blurb, prefix, rows} }, buffer = {...rows} }.
function M.collect()
  local acc = {}
  for _, mode in ipairs(MODES) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do add(acc, m, false) end
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do add(acc, m, true) end
  end

  local gs = vim.tbl_filter(function(g) return g.when == nil or g.when() end, groups_sorted())
  local by_prefix = {}
  for _, g in ipairs(gs) do
    g.rows = {}
    for _, s in ipairs(g.static or {}) do table.insert(g.rows, { lhs = s[1], desc = s[2], static = true }) end
    by_prefix[g.prefix] = g
  end
  local buffer_rows = {}

  for _, e in pairs(acc) do
    local modes = vim.tbl_keys(e.modes)
    table.sort(modes)
    e.mode = table.concat(modes)
    e.modes = nil
    if e.buffer then
      table.insert(buffer_rows, e)
    else
      for _, g in ipairs(gs) do
        if e.lhs:sub(1, #g.prefix) == g.prefix then
          -- Keep the whole lhs when the prefix would cut a <...> token in half.
          local cuts_token = g.prefix:match("^<") and not g.prefix:match("^<leader>") and not g.prefix:match(">$")
          e.key = (g.prefix == "" or cuts_token) and e.lhs or e.lhs:sub(#g.prefix + 1)
          if e.key == "" then e.key = g.prefix end
          e.key = e.key:gsub(" ", "<Space>")
          table.insert(g.rows, e)
          break
        end
      end
    end
  end

  local function sort_rows(rows)
    table.sort(rows, function(a, b)
      if (a.static or false) ~= (b.static or false) then return not a.static end
      return (a.key or a.lhs):lower() < (b.key or b.lhs):lower()
    end)
  end
  local ordered = {}
  for _, g in ipairs(require("cheatsheet.groups")) do
    local full = by_prefix[g.prefix]
    if full and #full.rows > 0 then
      sort_rows(full.rows)
      table.insert(ordered, { title = g.title, prefix = g.prefix, blurb = g.blurb, rows = full.rows })
    end
  end
  sort_rows(buffer_rows)
  for _, e in ipairs(buffer_rows) do e.key = e.lhs end

  return {
    groups = ordered,
    buffer = buffer_rows,
    filetype = vim.bo.filetype,
    version = ("%d.%d.%d"):format(vim.version().major, vim.version().minor, vim.version().patch),
    leader = vim.g.mapleader == " " and "Space" or vim.g.mapleader,
    count = vim.tbl_count(acc),
  }
end

function M.mode_label(mode)
  if mode == nil or mode == "n" or mode == "" then return "" end
  local parts = {}
  for c in mode:gmatch(".") do table.insert(parts, MODE_LABEL[c] or c) end
  return table.concat(parts)
end

--- Feature tour entries with `keys` resolved against collected maps:
--- each becomes { lhs, desc, live } where live=false means the fallback desc
--- was used, and desc="unmapped" flags a key that no longer exists.
function M.features(data)
  -- Only <...> tokens are case-insensitive (<C-e> vs <C-E>); bare keys keep case.
  local function canon(lhs) return (lhs:gsub("<[^>]+>", string.lower)) end
  local index = {}
  local function add_rows(rows)
    for _, r in ipairs(rows) do
      if not r.static then index[canon(r.lhs)] = index[canon(r.lhs)] or r.desc end
    end
  end
  for _, g in ipairs(data.groups) do add_rows(g.rows) end
  add_rows(data.buffer)

  local out = {}
  for _, f in ipairs(require("cheatsheet.features")) do
    if f.when == nil or f.when() then
      local keys = {}
    for _, k in ipairs(f.keys or {}) do
      local lhs, fallback = k, nil
      if type(k) == "table" then lhs, fallback = k[1], k[2] end
      lhs = lhs:gsub("<Leader>", "<leader>")
      local live = index[canon(lhs)]
      table.insert(keys, { lhs = lhs, desc = live or fallback or "unmapped", live = live ~= nil, stale = not live and not fallback })
    end
    table.insert(out, { title = f.title, tag = f.tag, summary = f.summary, body = f.body, see = f.see, keys = keys })
    end
  end
  return out
end

function M.float(page)
  local data = M.collect()
  data.features = M.features(data)
  require("cheatsheet.float").open(data, page)
end
function M.html()
  local data = M.collect()
  data.features = M.features(data)
  require("cheatsheet.html").open(data)
end

--- Report feature keys that no longer exist and maps without a desc. Returns
--- the number of problems; prints them so it works headless.
function M.check()
  local data = M.collect()
  local features = M.features(data)
  local problems = {}
  for _, f in ipairs(features) do
    for _, k in ipairs(f.keys) do
      if k.stale then table.insert(problems, ("features.lua: %s references unmapped key %s"):format(f.title, k.lhs)) end
    end
  end
  if #problems == 0 then
    print(("cheatsheet ok: %d maps, %d features"):format(data.count, #features))
  else
    print(table.concat(problems, "\n"))
  end
  return #problems
end

function M.setup()
  vim.api.nvim_create_user_command("Cheatsheet", function(o)
    if o.args == "html" then M.html()
    elseif o.args == "check" then M.check()
    else M.float() end
  end, { nargs = "?", complete = function() return { "html", "check" } end, desc = "Keybind cheatsheet (float, html, or check)" })
end

return M
