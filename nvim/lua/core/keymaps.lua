local utils = require("core.utils")
local snacks = require("snacks")
local dotnet = require("easy-dotnet")

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
local function wk_add_group(prefix, desc)
    require("which-key").add({ mode = { "n", "v" }, { prefix, group = desc } })
end

-- better up/down
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true })
map({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true })
map({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true })

-- Map H and L to _ and $ for better ergonomy
map("n", "H", function()
local current_col = vim.fn.virtcol('.')
  vim.cmd('normal ^')
  local first_char = vim.fn.virtcol('.')
  if current_col <= first_char then
    vim.cmd('normal 0')
  end
end, { desc = "Go to start of line after ws, if already there to beginning" })
map("n", "L", "$", { desc = "Go to end of line" })
map("o", "H", "_", { desc = "Move to start of line after ws" })
map("o", "L", "$", { desc = "Move to end of line" })
map("n", "<C-a>", "ggVG", { desc = "Select all the buffer" })

-- Clear search with <esc>
map("n", "<esc>", ":noh<cr><esc>", { desc = "Escape and clear hlsearch" })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
map("n", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("n", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
map("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
map("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })


-- Move to window using the <ctrl> hjkl keys
map("n", "<A-h>", "<C-w>h", { desc = "Go to Left Window", remap = true })
map("n", "<A-j>", "<C-w>j", { desc = "Go to Lower Window", remap = true })
map("n", "<A-k>", "<C-w>k", { desc = "Go to Upper Window", remap = true })
map("n", "<A-l>", "<C-w>l", { desc = "Go to Right Window", remap = true })

-- Break lines in normal mode
map("n", "<C-j>", "i<C-m><Esc>", { desc = "Break line in normal mode"})

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

-- flash
map({ "n", "x", "o" }, "s", function() require("flash").jump() end,  { desc = "Flash" })
map({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })
map({ "o", "x" }, "R", function() require("flash").treesitter_search() end, { desc = "Treesitter Search" })
map({ "c" }, "<c-s>", function() require("flash").toggle() end, { desc = "Toggle Flash Search" })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
map("n", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("n", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
map("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
map("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- Buffers
wk_add_group("<leader>b", "buffer")
map("n", "<leader>bb", function() utils.switch_to_other_buffer() end, { desc = "Switch to Other Buffer" })
map("n", "<leader>bd", function() snacks.bufdelete({ wipe = true }) end, { desc = "Delete buffer" })

-- Package manager
map("n", "<leader>l", ":Lazy<cr>", { desc = "Package manager" })

-- File explorer
map("n", "<leader>x", open_mini_files_safe, { desc = "Open mini.files (cwd)" })-- Snacks Picker

-- Search and Replace
wk_add_group("<leader>f", "file/find")
map("n", "<leader><leader>", function() snacks.picker.smart() end, { desc = "Smart Fuzzy Find" })
map("n", "<leader>fb", function() snacks.picker.buffers({ layout = { preset = "select" }}) end, { desc = "Fuzzy find buffers" })
map("n", "<leader>fc", function() snacks.picker.grep_word() end, { desc = "Find word under cursor in CWD" })
map("n", "<leader>fd", function() snacks.picker.todo_comments() end, { desc = "Todo" })
map("n", "<leader>ff", function() snacks.picker.files({ hidden = true }) end, { desc = "Fuzzy find files" })
map("n", "<leader>fh", function() snacks.picker.help() end, { desc = "Find help tags" })
map("n", "<leader>fr", function() snacks.picker.recent() end, { desc = "Fuzzy find recent files" })
map("n", "<leader>fR", function() require("grug-far").with_visual_selection() end, { desc = "Replace in files..." })
map("n", "<leader>fs", function() snacks.picker.grep() end, { desc = "Find string in CWD" })
map("n", "<leader>fS", function() require("pick-resession").pick() end, { desc = "Find Session" })
map("n", "<leader>ft", function() snacks.picker() end, { desc = "Other pickers..." })
-- toggle options
local function map_toggle(keymap, toggle)
    toggle:map(keymap)
end
wk_add_group("<leader>s", "switch")
map_toggle("<leader>sa", utils.toggle_global_boolean("autoformat", "Autoformat"))
map_toggle("<leader>sc", snacks.toggle(copilot_toggle_opts))
map_toggle("<leader>sC", snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }))
map_toggle("<leader>sd", snacks.toggle.diagnostics())
if vim.lsp.inlay_hint then
    map_toggle("<leader>sh", snacks.toggle.inlay_hints())
end
map_toggle("<leader>sl", snacks.toggle.line_number())
map_toggle("<leader>sL", snacks.toggle.option("relativenumber", { name = "Relative Number" }))
map_toggle("<leader>ss", snacks.toggle.option("spell", { name = "Spelling" }))
map_toggle("<leader>sT", snacks.toggle.treesitter())
map_toggle("<leader>sw", snacks.toggle.option("wrap", { name = "Wrap" }))

-- VCS
wk_add_group("<leader>g", "git")
map("n", "<leader>gb", function() snacks.gitbrowse() end, { desc = "Git Browse" })
map("n", "<leader>gg", function() snacks.lazygit() end, { desc = "Lazygit" })
map("n", "<esc>", ":noh<cr><esc>", { desc = "Escape and clear hlsearch" })

-- quit
wk_add_group("<leader>q", "quit")
map("n", "<leader>qq", ":qa<cr>", { desc = "Quit all" })

-- windows
wk_add_group("<leader>w", "windows")
map("n", "<leader>ww", "<C-W>p", { desc = "Other window", remap = true })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete window", remap = true })
map("n", "<leader>w-", "<C-W>s", { desc = "Split window below", remap = true })
map("n", "<leader>w|", "<C-W>v", { desc = "Split window right", remap = true })
map("n", "<leader>-", "<C-W>s", { desc = "Split window below", remap = true })
map("n", "<leader>|", "<C-W>v", { desc = "Split window right", remap = true })

-- visual layout
wk_add_group("<leader>v", "visual layout")
map("n", "<leader>vz", function() snacks.zen() end, { desc = "Zen mode" })
map("n", "<leader>vv", ":only<cr>", { desc = "Close other windows" })

-- tabs
wk_add_group("<leader><Tab>", "tabs")
map("n", "<leader><tab><tab>", ":tabnew<cr>", { desc = "New Tab" })
map("n", "<leader><tab>l", ":tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader><tab>d", ":tabclose<cr>", { desc = "Close Tab" })
map("n", "<leader><tab>h", ":tabprevious<cr>", { desc = "Previous Tab" })

-- Code/LSP
wk_add_group("<leader>c", "code")
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })
map("n", "<C-.>", vim.lsp.buf.code_action, { desc = "Code Action" })
map("n", "<leader>c?", function() vim.diagnostic.open_float({border = 'rounded'}) end, { desc = "Line Diagnostics" })
map("n", "<leader>cD", vim.lsp.buf.declaration, { desc = "Goto Declaration" })
map("n", "<leader>cd", function() snacks.picker.lsp_definitions() end, { desc = "Goto Definitions" })
map("n", "<leader>ch", function() return vim.lsp.buf.hover() end, { desc = "Hover" })
map("n", "<leader>cJ", function() snacks.picker.lsp_implementations() end, { desc = "Goto Implementations" })
map("n", "<leader>cl", ":check lsp<cr>", { desc = "LSP Info" })
map("n", "<leader>cs", vim.lsp.buf.signature_help, { desc = "Signature Help" })
map("n", "<leader>ct", function() snacks.picker.lsp_type_definitions() end, { desc = "Goto Type Definitions" })
map("n", "<leader>cu", function() snacks.picker.lsp_references() end, { desc = "Goto Usages" })
map("n", "<leader>cU", "[f<leader>cu", { desc = "Goto Usages of containing method", remap = true })

-- Debugging
wk_add_group("<leader>d", ".NET debugging")
            local dap = require("dap")
            local neotest = require("neotest")
map("n", "<leader>dd", function() dotnet.run_profile() end, { desc = "Run" })
            map("n", "<F5>", function() dap.continue() end, { desc = "Continue" })
            map("n", "<F6>", function() neotest.run.run({strategy = 'dap'}) end, { desc = "Test Debug" })
            map("n", "<F9>", function() dap.toggle_breakpoint() end, { desc = "Toggle breakpoint" })
            map("n", "<F10>", function() dap.step_over() end, { desc = "Step over" })
            map("n", "<F11>", function() dap.step_into() end, { desc = "Step into" })
            map("n", "<F8>", function() dap.step_out() end, { desc = "Step out" })
            map("n", "<leader>dp", function() dap.repl.open() end, { desc = "Open repl" })
            map("n", "<leader>dl", function() dap.run_last() end, { desc = "Run last" })
            map(
                "n",
                "<leader>dt",
                function() neotest.run.run({strategy = 'dap'}) end,
                { desc = "debug nearest test" }
            )

-- Refactoring
wk_add_group("<leader>r", "refactor")
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename" })
map("x", "<leader>re", ":Refactor extract ", { desc = "Extract" })
map("x", "<leader>rf", ":Refactor extract_to_file ", { desc = "Extract to file" })
map("x", "<leader>rv", ":Refactor extract_var ", { desc = "Extract variable" })
map({ "n", "x" }, "<leader>ri", ":Refactor inline_var", { desc = "Inline variable" })
map("n", "<leader>rI", ":Refactor inline_func", { desc = "Inline function" })
map("n", "<leader>rb", ":Refactor extract_block", { desc = "Extract block" })
map("n", "<leader>rbf", ":Refactor extract_block_to_file", { desc = "Extract block to file" })

-- REST Client
wk_add_group("<leader>R", "REST")

-- Terminal/Run...
wk_add_group("<leader>e", "execute")
map({"n", "t"}, "<C-\\>", function() snacks.terminal() end, { desc = "Toggle Terminal" })
map("n", "<leader>ek", function() utils.open_terminal_toggle({ "k9s" }, true) end, { desc = "K9s" })
wk_add_group("<leader>el", "lua")
map("n", "<leader>elf", ":luafile %<cr>", { desc = "Run Current Lua File" })
map("n", "<leader>elt", ":PlenaryBustedFile %<cr>", { desc = "Run Lua Test File" })
wk_add_group("<leader>es", "shell")
map("n", "<leader>ess", run_non_interactive_cmd(vim.fn.expand("%:p")), { desc = "Run shell script" })
map("n", "<leader>em", run_non_interactive_cmd("make"), { desc = "Run make" })
map("n", "<leader>et", run_non_interactive_cmd("task"), { desc = "Run task" })

-- test
wk_add_group("<leader>t", "test")
map("n", "<leader>tt", ":Neotest run<cr>", { desc = "Run tests" })

-- obsidian
wk_add_group("<leader>o", "obsidian")
map("n", "<leader>on", "<cmd>Obsidian new_from_template Core<cr>", { desc = "New Obsidian note" })
map("n", "<leader>oo", "<cmd>Obsidian search<cr>", { desc = "Search Obsidian notes" })
map("n", "<leader>os", "<cmd>Obsidian quick_switch<cr>", { desc = "Quick Switch" })
map("n", "<leader>ob", "<cmd>Obsidian backlinks<cr>", { desc = "Show location list of backlinks" })
map("n", "<leader>of", "<cmd>Obsidian follow_link<cr>", { desc = "Follow link under cursor" })
map("n", "<leader>ot", "<cmd>Obsidian template Core<cr>", { desc = "Apply Core Template" })
-- Custom git sync job - manual trigger. Auto sync is available but off by default.
-- Toggle on with <leader>to (toggle obsidian git sync)
map("n", "<leader>og", "<cmd>ObsidianGitSync<cr>", { desc = "Sync changes to git" })

-- stylua: ignore end
