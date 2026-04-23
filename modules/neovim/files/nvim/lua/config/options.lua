-- Netrw settings
vim.cmd("let g:netrw_liststyle = 3") -- Use tree-style view for netrw

-- Line numbers
vim.opt.relativenumber = true -- Show relative line numbers
vim.opt.number = true -- Show absolute line numbers

-- Mouse settings
vim.opt.mouse = "a" -- Enable mouse support

-- Tabs and indentation
vim.opt.expandtab = true -- Expand tab to spaces
vim.opt.shiftwidth = 4 -- Number of spaces to use for each step of (auto)indent
vim.opt.softtabstop = 4 -- Number of spaces that a <Tab> counts for while editing
vim.opt.autoindent = true -- Copy indent from current line when starting new one
vim.opt.tabstop = 4 -- Number of spaces that a <Tab> in the file counts for

-- Text wrapping
vim.opt.wrap = false -- Disable line wrapping

-- Search settings
vim.opt.ignorecase = true -- Ignore case when searching
vim.opt.smartcase = true -- Case-sensitive search when mixed case is used
vim.opt.shortmess:remove("S") -- Show search count message when searching

-- Cursor line
vim.opt.cursorline = true -- Highlight the current line

-- Appearance settings
vim.opt.termguicolors = true -- Enable 24-bit RGB color in the TUI
vim.opt.background = "dark" -- Use dark background
vim.opt.signcolumn = "yes" -- Always show the sign column
vim.opt.cmdheight = 0 -- Auto-hide command line when not in use

-- Backspace behavior
vim.opt.backspace = "indent,eol,start" -- Allow backspace on indent, end of line, or insert mode start position

-- Clipboard
-- vim.opt.clipboard:append("unnamedplus")     -- Use system clipboard as default register

-- Window splitting
vim.opt.splitright = true -- Split vertical window to the right
vim.opt.splitbelow = true -- Split horizontal window to the bottom

-- File handling
vim.opt.swapfile = false -- Disable swap file creation
vim.opt.backup = false -- Disable backup file creation
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir" -- Set the directory for undo files
vim.opt.undofile = true -- Enable persistent undo

-- Miscellaneous settings
vim.opt.showmode = false -- Disable showing mode in command line
vim.opt.breakindent = true -- Enable break indent
vim.opt.updatetime = 50 -- Faster completion
vim.opt.timeoutlen = 300 -- Time to wait for a mapped sequence to complete (in milliseconds)
vim.opt.list = true -- Show some invisible characters
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" } -- Define characters for invisible characters
vim.opt.inccommand = "split" -- Show effects of a command incrementally
vim.opt.scrolloff = 10 -- Minimum number of screen lines to keep above and below the cursor
-- vim.opt.colorcolumn = "120"                 -- Highlight column at 120 characters
