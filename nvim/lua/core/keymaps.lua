local utils = require("core.utils")
local snacks = require("snacks")

--- Map a key combination to a command
---@param modes string|string[]: The mode(s) to map the key combination to
---@param lhs string: The key combination to map
---@param rhs string|function: The command to run when the key combination is pressed
---@param opts table: Options to pass to the keymap
local map = function(modes, lhs, rhs, opts)
    local options = { silent = true }
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    if type(modes) == "string" then
        modes = { modes }
    end
    for _, mode in ipairs(modes) do
        vim.keymap.set(mode, lhs, rhs, options)
    end
end

--- Unmap a key combination to a command
---@param modes string|string[]: The mode(s) to map the key combination to
---@param lhs string: The key combination to map
local unmap = function(modes, lhs)
    if type(modes) == "string" then
        modes = { modes }
    end
    for _, mode in ipairs(modes) do
        vim.keymap.del(mode, lhs)
    end
end
local copilot_toggle_opts = {
    name = "Copilot Completion",
    get = function()
        return not require("copilot.client").is_disabled()
    end,
    set = function(state)
        if state then
            require("copilot.command").enable()
        else
            require("copilot.command").disable()
        end
    end,
}

--- Open a non-interactive terminal and run a command. Keeps the current window focused.
---@param cmd string: The command to run
local function run_non_interactive_cmd(cmd)
    return function()
        local win = vim.api.nvim_get_current_win()
        snacks.terminal.toggle(cmd, { interactive = false })
        vim.api.nvim_set_current_win(win)
    end
end

--- Open mini.files, also if the current buffer is not a file
local function open_mini_files_safe()
    local path = vim.bo.buftype ~= "nofile" and vim.api.nvim_buf_get_name(0) or nil
    local ok = pcall(require("mini.files").open, path)
    if not ok then
        require("mini.files").open()
    end
end

-- stylua: ignore start

-- better up/down
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true })
map({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true })
map({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true })

-- Map H and L to _ and $ for better ergonomy
map("n", "H", "_", { desc = "Go to start of line after ws" })
map("n", "L", "$", { desc = "Go to end of line" })
map("o", "H", "_", { desc = "Move to start of line after ws" })
map("o", "L", "$", { desc = "Move to end of line" })
map("n", "<C-a>", "ggVG", { desc = "Select all the buffer" })

-- Move to window using the <ctrl> hjkl keys
map("n", "<A-h>", "<C-w>h", { desc = "Go to Left Window", remap = true })
map("n", "<A-j>", "<C-w>j", { desc = "Go to Lower Window", remap = true })
map("n", "<A-k>", "<C-w>k", { desc = "Go to Upper Window", remap = true })
map("n", "<A-l>", "<C-w>l", { desc = "Go to Right Window", remap = true })

-- Break lines in normal mode
map("n", "<C-j>", "i<C-m><Esc>", { desc = "Break line in normal mode"})
map("n", "<C-S-j>", "mzo<Esc>`z", { desc = "Insert a new line below current one and keep cursor position" })

-- Resize window using <ctrl> arrow keys
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Move Lines
map("n", "<C-A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<C-A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<C-A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<C-A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<C-A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<C-A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })

-- Buffers
map("n", "<leader>bb", function() utils.switch_to_other_buffer() end, { desc = "Switch to Other Buffer" })
map("n", "<leader>bd", function() snacks.bufdelete({ wipe = true }) end, { desc = "Delete buffer" })

-- lazy
map("n", "<leader>l", ":Lazy<cr>", { desc = "Lazy" })

-- mini.files
map("n", "<leader>x", open_mini_files_safe, { desc = "Open mini.files (cwd)" })-- Snacks Picker

-- pickers
map("n", "<leader><leader>", function() snacks.picker.smart() end, { desc = "Smart Fuzzy Find" })
map("n", "<leader>ff", function() snacks.picker.files({ hidden = true }) end, { desc = "Fuzzy find files" })
map("n", "<leader>fr", function() snacks.picker.recent() end, { desc = "Fuzzy find recent files" })
map("n", "<leader>fs", function() snacks.picker.grep() end, { desc = "Find string in CWD" })
map("n", "<leader>fc", function() snacks.picker.grep_word() end, { desc = "Find word under cursor in CWD" })
map("n", "<leader>fb", function() snacks.picker.buffers({ layout = { preset = "select" }}) end, { desc = "Fuzzy find buffers" })
map("n", "<leader>ft", function() snacks.picker() end, { desc = "Other pickers..." })
map("n", "<leader>fh", function() snacks.picker.help() end, { desc = "Find help tags" })
map("n", "<leader>fS", function() require("pick-resession").pick() end, { desc = "Find Session" })
map("n", "<leader>fd", function() snacks.picker.todo_comments() end, { desc = "Todo" })

-- flash
map({ "n", "x", "o" }, "s", function() require("flash").jump() end,  { desc = "Flash" })
map({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })
map({ "o", "x" }, "R", function() require("flash").treesitter_search() end, { desc = "Treesitter Search" })
map({ "c" }, "<c-s>", function() require("flash").toggle() end, { desc = "Toggle Flash Search" })

-- toggle options
utils.toggle_global_boolean("autoformat", "Autoformat"):map("<leader>ta")
snacks.toggle(copilot_toggle_opts):map("<leader>tc")
snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>ts")
snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>tw")
snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>tL")
snacks.toggle.diagnostics():map("<leader>td")
snacks.toggle.line_number():map("<leader>tl")
snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>tC")
snacks.toggle.treesitter():map("<leader>tT")
if vim.lsp.inlay_hint then snacks.toggle.inlay_hints():map("<leader>th") end

-- browse to git repo
map("n", "<leader>gb", function() snacks.gitbrowse() end, { desc = "Git Browse" })

-- Clear search with <esc>
map("n", "<esc>", ":noh<cr><esc>", { desc = "Escape and clear hlsearch" })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
map("n", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("n", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
map("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
map("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- quit
map("n", "<leader>qq", ":qa<cr>", { desc = "Quit all" })

-- windows
map("n", "<leader>ww", "<C-W>p", { desc = "Other window", remap = true })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete window", remap = true })
map("n", "<leader>w-", "<C-W>s", { desc = "Split window below", remap = true })
map("n", "<leader>w|", "<C-W>v", { desc = "Split window right", remap = true })
map("n", "<leader>-", "<C-W>s", { desc = "Split window below", remap = true })
map("n", "<leader>|", "<C-W>v", { desc = "Split window right", remap = true })
map("n", "<leader>wz", function() snacks.zen() end, { desc = "Zen mode" })

-- tabs
map("n", "<leader><tab><tab>", ":tabnew<cr>", { desc = "New Tab" })
map("n", "<leader><tab>l", ":tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader><tab>d", ":tabclose<cr>", { desc = "Close Tab" })
map("n", "<leader><tab>h", ":tabprevious<cr>", { desc = "Previous Tab" })

-- Code/LSP
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })
map("n", "<leader>cd", function() vim.diagnostic.open_float({border = 'rounded'}) end, { desc = "Line Diagnostics" })
map("n", "<leader>cl", ":check lsp<cr>", { desc = "LSP Info" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename" })
map("n", "K", function() return vim.lsp.buf.hover() end, { desc = "Hover" })
map("n", "gsD", vim.lsp.buf.declaration, { desc = "Goto Declaration" })
map("n", "gK", vim.lsp.buf.signature_help, { desc = "Signature Help" })
map("n", "gsu", function() snacks.picker.lsp_references() end, { desc = "Goto References" })
map("n", "gsJ", function() snacks.picker.lsp_implementations() end, { desc = "Goto Implementations" })
map("n", "gsd", function() snacks.picker.lsp_definitions() end, { desc = "Goto Definitions" })
map("n", "gst", function() snacks.picker.lsp_type_definitions() end, { desc = "Goto Type Definitions" })

-- Terminal/Run...
map({"n", "t"}, "<C-\\>", function() snacks.terminal() end, { desc = "Toggle Terminal" })
map("n", "<leader>gg", function() snacks.lazygit() end, { desc = "Lazygit" })
map("n", "<leader>kk", function() utils.open_terminal_toggle({ "k9s" }, true) end, { desc = "K9s" })
map("n", "<leader>ao", function() utils.open_terminal_toggle({ "opencode", "." }) end, { desc = "Opencode" })
map("n", "<leader>rlf", ":luafile %<cr>", { desc = "Run Current Lua File" })
map("n", "<leader>rlt", ":PlenaryBustedFile %<cr>", { desc = "Run Lua Test File" })
map("n", "<leader>rss", run_non_interactive_cmd(vim.fn.expand("%:p")), { desc = "Run shell script" })
map("n", "<leader>rm", run_non_interactive_cmd("make"), { desc = "Run make" })
map("n", "<leader>rt", run_non_interactive_cmd("task"), { desc = "Run task" })
-- stylua: ignore end
