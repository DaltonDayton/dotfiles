-- Self-contained HTML page coloured from the active colorscheme. Written to
-- stdpath("state")/cheatsheet.html and opened in Firefox.
local M = {}

local function hl(name, attr, fallback)
  local h = vim.api.nvim_get_hl(0, { name = name, link = false })
  local v = h[attr]
  return v and ("#%06x"):format(v) or fallback
end

local function palette()
  return {
    bg = hl("Normal", "bg", "#1e1e2e"),
    fg = hl("Normal", "fg", "#cdd6f4"),
    card = hl("NormalFloat", "bg", hl("CursorLine", "bg", "#262636")),
    border = hl("FloatBorder", "fg", hl("WinSeparator", "fg", "#45475a")),
    muted = hl("Comment", "fg", "#7f849c"),
    title = hl("Title", "fg", hl("Function", "fg", "#89b4fa")),
    key = hl("String", "fg", "#a6e3a1"),
    keybg = hl("CursorLine", "bg", "#313244"),
    accent = hl("Keyword", "fg", "#cba6f7"),
    mode = hl("Special", "fg", "#f5c2e7"),
  }
end

local page = [[<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Neovim cheatsheet</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root{--bg:$bg;--fg:$fg;--card:$card;--border:$border;--muted:$muted;--title:$title;--key:$key;--keybg:$keybg;--accent:$accent;--mode:$mode}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif}
header{position:sticky;top:0;z-index:2;background:var(--bg);border-bottom:1px solid var(--border);padding:14px 28px;display:flex;gap:18px;align-items:center;flex-wrap:wrap}
h1{font-size:20px;margin:0;color:var(--title)}
.meta{color:var(--muted);font-size:13px}
input{flex:1;min-width:220px;background:var(--card);color:var(--fg);border:1px solid var(--border);border-radius:8px;padding:8px 12px;font:inherit}
input:focus{outline:2px solid var(--accent);outline-offset:-1px}
.chips{display:flex;gap:6px}
.chip{border:1px solid var(--border);border-radius:999px;padding:3px 12px;font-size:12px;cursor:pointer;color:var(--muted);user-select:none}
.chip.on{color:var(--bg);background:var(--accent);border-color:var(--accent)}
.chip.all{border-style:dashed;margin-right:6px}
main{padding:22px 28px;columns:3 360px;column-gap:18px}
section{break-inside:avoid;background:var(--card);border:1px solid var(--border);border-radius:12px;padding:14px 16px 8px;margin:0 0 18px}
section.hidden{display:none}
h2{font-size:16px;margin:0 0 2px;color:var(--title);display:flex;justify-content:space-between;align-items:baseline}
h2 small{color:var(--muted);font-weight:normal;font-family:ui-monospace,monospace;font-size:12px}
.blurb{color:var(--muted);font-size:13px;margin:0 0 10px}
table{width:100%;border-collapse:collapse}
tr.hidden{display:none}
td{padding:4px 0;vertical-align:top;border-top:1px solid color-mix(in srgb,var(--border) 50%,transparent)}
td.k{width:1%;white-space:nowrap;padding-right:14px}
kbd{font-family:ui-monospace,monospace;font-size:12.5px;background:var(--keybg);color:var(--key);border:1px solid var(--border);border-bottom-width:2px;border-radius:5px;padding:1px 6px}
.mode{color:var(--mode);font-size:11px;margin-left:6px;font-style:italic}
.static kbd{color:var(--accent)}
footer{padding:10px 28px 30px;color:var(--muted);font-size:12px}
nav{display:flex;gap:4px;border:1px solid var(--border);border-radius:8px;padding:3px}
nav span{padding:4px 14px;border-radius:6px;cursor:pointer;color:var(--muted);user-select:none}
nav span.on{background:var(--accent);color:var(--bg)}
#features{display:none}
body.features #keys,body.features #chips{display:none}
body.features #features,body.features #tags{display:flex;flex-wrap:wrap}
#tags{display:none;gap:6px}
#features{padding:22px 28px;gap:18px;align-items:flex-start}
#features section{flex:1 1 420px;max-width:640px;margin:0}
.tag{font-size:11px;color:var(--mode);border:1px solid var(--border);border-radius:999px;padding:1px 8px;font-weight:normal}
.summary{margin:6px 0 8px;font-weight:600}
.body{margin:0 0 10px;color:var(--fg);opacity:.9}
.keys{display:flex;flex-wrap:wrap;gap:6px 14px;margin-bottom:8px}
.keys span{font-size:13px;color:var(--muted)}
.stale kbd{color:#f38ba8;border-color:#f38ba8}
.see{font-size:12px;color:var(--muted);font-family:ui-monospace,monospace}
</style></head><body class="features">
<header><h1>Neovim cheatsheet</h1><span class="meta">$meta</span>
<nav id="nav"><span data-page="keys">Keys</span><span class="on" data-page="features">Features</span></nav>
<input id="q" type="search" placeholder="Filter features, keys, actions…" autofocus>
<div class="chips" id="chips"></div><div class="chips" id="tags"></div></header>
<main id="keys"></main>
<main id="features"></main>
<footer>Generated from live keymaps with a description. Regenerate with <kbd>:Cheatsheet html</kbd>.</footer>
<script>
const DATA=$data;
const MODES={n:"normal",x:"visual",o:"op-pending",i:"insert",t:"terminal"};
const SHORT={n:"n",x:"v",o:"o",i:"i",t:"t"};
const esc=s=>s.replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const main=document.getElementById("keys"),chips=document.getElementById("chips"),feat=document.getElementById("features"),tags=document.getElementById("tags");
const activeTags=new Set(DATA.features.map(f=>f.tag));
for(const s of document.querySelectorAll("#nav span"))s.onclick=()=>{document.querySelectorAll("#nav span").forEach(x=>x.classList.toggle("on",x===s));document.body.classList.toggle("features",s.dataset.page==="features");apply()};
function fkey(k){return`<span class="${k.stale?"stale":""}"><kbd>${esc(k.lhs)}</kbd> ${esc(k.stale?"unmapped":k.desc)}</span>`}
feat.innerHTML=DATA.features.map(f=>`<section data-tag="${esc(f.tag)}" data-t="${esc(f.title+" "+f.summary+" "+f.body+" "+f.keys.map(k=>k.lhs+" "+k.desc).join(" ")).toLowerCase()}"><h2>${esc(f.title)}<span class="tag">${esc(f.tag)}</span></h2><p class="summary">${esc(f.summary)}</p>${f.body.split(/\n\n+/).map(p=>`<p class="body">${esc(p.replace(/\n/g," "))}</p>`).join("")}${f.keys.length?`<div class="keys">${f.keys.map(fkey).join("")}</div>`:""}${f.see?`<div class="see">see ${esc(f.see)}</div>`:""}</section>`).join("");
// A chip row: a dashed all/none toggle, then one chip per item. `set` holds the active keys.
function chipRow(container,items,set){
  const chips=new Map();
  const all=document.createElement("span");all.className="chip all";
  const sync=()=>{const everything=chips.size===set.size;all.textContent=everything?"none":"all";for(const[k,c]of chips)c.classList.toggle("on",set.has(k))};
  all.onclick=()=>{if(chips.size===set.size)set.clear();else for(const k of chips.keys())set.add(k);sync();apply()};
  container.append(all);
  for(const[k,label]of items){const c=document.createElement("span");c.className="chip";c.textContent=label;c.onclick=()=>{set.has(k)?set.delete(k):set.add(k);sync();apply()};chips.set(k,c);container.append(c)}
  sync();
}
chipRow(tags,[...activeTags].map(t=>[t,t]),activeTags);
const active=new Set(Object.keys(MODES));
function modeLabel(m){if(!m||m==="n")return"";return[...m].map(c=>SHORT[c]||c).join("")}
function row(r){const m=modeLabel(r.mode);return`<tr class="${r.static?"static":""}" data-mode="${r.mode||"n"}" data-t="${esc((r.key||r.lhs)+" "+r.desc).toLowerCase()}"><td class="k"><kbd>${esc(r.key||r.lhs)}</kbd>${m?`<span class="mode">${m}</span>`:""}</td><td>${esc(r.desc)}</td></tr>`}
function section(title,prefix,blurb,rows){return`<section data-t="${esc(title).toLowerCase()}"><h2>${esc(title)}${prefix?`<small>${esc(prefix)}</small>`:""}</h2>${blurb?`<p class="blurb">${esc(blurb)}</p>`:""}<table>${rows.map(row).join("")}</table></section>`}
let html="";
if(DATA.buffer.length)html+=section("This buffer ("+(DATA.filetype||"no filetype")+")","",null,DATA.buffer);
for(const g of DATA.groups)html+=section(g.title,g.prefix,g.blurb,g.rows);
main.innerHTML=html;
chipRow(chips,Object.entries(MODES),active);
const q=document.getElementById("q");q.oninput=apply;
function apply(){const t=q.value.trim().toLowerCase();for(const s of feat.children){s.classList.toggle("hidden",!activeTags.has(s.dataset.tag)||(t&&!s.dataset.t.includes(t)))}for(const s of main.children){const sm=!t||s.dataset.t.includes(t);let any=false;for(const r of s.querySelectorAll("tr")){const modeOk=[...r.dataset.mode].some(c=>active.has(c))||r.classList.contains("static");const ok=modeOk&&(sm||r.dataset.t.includes(t));r.classList.toggle("hidden",!ok);any=any||ok}s.classList.toggle("hidden",!any)}}
</script></body></html>
]]

function M.render(data)
  local p = palette()
  local json = vim.json.encode(data):gsub("</", "<\\/")
  local vars = vim.tbl_extend("force", p, {
    data = json,
    meta = ("nvim %s · %d maps · leader = %s · %s"):format(data.version, data.count, data.leader, vim.g.colors_name or ""),
  })
  return (page:gsub("%$(%w+)", function(k) return vars[k] end))
end

function M.open(data)
  local path = vim.fn.stdpath("state") .. "/cheatsheet.html"
  vim.fn.writefile(vim.split(M.render(data), "\n"), path)
  vim.fn.jobstart({ "setsid", "firefox", path }, { detach = true })
  vim.notify("Cheatsheet written to " .. path)
end

return M
