local M = {}

local function cell(s) return (s:gsub("|", "\\|")) end

local function key_cell(row)
  local k = "`" .. cell(row.key or row.lhs) .. "`"
  local mode = require("cheatsheet").mode_label(row.mode)
  if mode ~= "" then k = k .. " (" .. mode .. ")" end
  return k
end

-- Column-aligned markdown table, two key/action pairs per row, so it reads
-- fine even where markview doesn't render.
local function table_lines(rows, lines)
  local grid = { { "Key", "Action", "Key", "Action" } }
  for i = 1, #rows, 2 do
    local a, b = rows[i], rows[i + 1]
    table.insert(grid, { key_cell(a), cell(a.desc), b and key_cell(b) or "", b and cell(b.desc) or "" })
  end
  local width = { 0, 0, 0, 0 }
  for _, r in ipairs(grid) do
    for c = 1, 4 do width[c] = math.max(width[c], vim.fn.strdisplaywidth(r[c])) end
  end
  local function fmt(r)
    local out = {}
    for c = 1, 4 do out[c] = r[c] .. string.rep(" ", width[c] - vim.fn.strdisplaywidth(r[c])) end
    return "| " .. table.concat(out, " | ") .. " |"
  end
  table.insert(lines, fmt(grid[1]))
  local sep = {}
  for c = 1, 4 do sep[c] = string.rep("-", width[c]) end
  table.insert(lines, "|-" .. table.concat(sep, "-|-") .. "-|")
  for i = 2, #grid do table.insert(lines, fmt(grid[i])) end
  table.insert(lines, "")
end

function M.render(data)
  local lines = {
    "# Cheatsheet",
    "",
    ("nvim %s · %d maps · leader = %s · `/` to search, `q` to close · `:Cheatsheet html` for the full page"):format(
      data.version, data.count, data.leader),
    "",
  }
  if #data.buffer > 0 then
    table.insert(lines, ("## This buffer (%s)"):format(data.filetype ~= "" and data.filetype or "no filetype"))
    table.insert(lines, "")
    table_lines(data.buffer, lines)
  end
  for _, g in ipairs(data.groups) do
    table.insert(lines, ("## %s%s"):format(g.title, g.prefix ~= "" and ("  `" .. g.prefix .. "`") or ""))
    table.insert(lines, "")
    if g.blurb then table.insert(lines, g.blurb); table.insert(lines, "") end
    table_lines(g.rows, lines)
  end
  return lines
end

function M.render_features(data)
  local lines = {
    "# Features",
    "",
    "What this config does and why. `Tab` flips to the key index, `/` searches, `q` closes.",
    "",
  }
  local by_tag = {}
  for _, f in ipairs(data.features) do
    if not by_tag[f.tag] then
      by_tag[f.tag] = true
      table.insert(lines, "## " .. f.tag:sub(1, 1):upper() .. f.tag:sub(2))
      table.insert(lines, "")
    end
    table.insert(lines, "### " .. f.title)
    table.insert(lines, "")
    table.insert(lines, "**" .. f.summary .. "**")
    table.insert(lines, "")
    for _, para in ipairs(vim.split(f.body, "\n\n", { plain = true })) do
      table.insert(lines, (para:gsub("\n", " ")))
      table.insert(lines, "")
    end
    if #f.keys > 0 then
      local parts = {}
      for _, k in ipairs(f.keys) do
        local d = k.stale and "⚠ unmapped" or k.desc
        table.insert(parts, ("`%s` %s"):format(k.lhs, d))
      end
      table.insert(lines, table.concat(parts, " · "))
      table.insert(lines, "")
    end
    if f.see then
      table.insert(lines, "See " .. f.see)
      table.insert(lines, "")
    end
  end
  return lines
end

function M.open(data, page)
  page = page or "keys"
  local win = Snacks.win({
    text = page == "features" and M.render_features(data) or M.render(data),
    ft = "markdown",
    title = page == "features" and " Features  (Tab: keys) " or " Cheatsheet  (Tab: features) ",
    title_pos = "center",
    border = "rounded",
    width = 0.85,
    height = 0.85,
    bo = { modifiable = false, filetype = "markdown", buftype = "nofile" },
    wo = { wrap = false, number = false, relativenumber = false, signcolumn = "no", cursorline = true, conceallevel = 3 },
    keys = {
      q = "close",
      ["<Esc>"] = "close",
      ["<Tab>"] = function(self)
        self:close()
        M.open(data, page == "features" and "keys" or "features")
      end,
    },
  })
  -- markview skips nofile buffers by default (preview.ignore_buftypes), so attach by hand.
  local ok, markview = pcall(require, "markview")
  if ok and markview then require("markview.actions").attach(win.buf) end
  return win
end

return M
