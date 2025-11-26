-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

-- General mappings ===========================================================

-- Use this section to add custom general mappings. See `:h vim.keymap.set()`.

-- Helper to create a Normal mode mapping
local nmap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set('n', lhs, rhs, { desc = desc })
end

--- Map a key combination to a command
---@param modes string|string[]: The mode(s) to map the key combination to
---@param lhs string: The key combination to map
---@param rhs string|function: The command to run when the key combination is pressed
---@param opts table|string: Options to pass to the keymap
local map = function(modes, lhs, rhs, opts)
  if type(opts) == 'string' then opts = { desc = opts } end
  local options = { silent = true }
  if opts then options = vim.tbl_extend('force', options, opts) end
  if type(modes) == 'string' then modes = { modes } end
  for _, mode in ipairs(modes) do
    vim.keymap.set(mode, lhs, rhs, options)
  end
end

-- better up/down
map({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Down', expr = true })
map({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Up', expr = true })

-- shift doesn't leave visual mode
map('x', '>', '>gv', { desc = 'Shift right and stay visual' })
map('x', '<', '<gv', { desc = 'Shift left and stay visual' })

-- Map H and L to _ and $ for better ergonomy
local smart_go_to_begin_of_line = function()
  local current_col = vim.fn.virtcol('.')
  vim.cmd('normal ^')
  local first_char = vim.fn.virtcol('.')
  if current_col <= first_char then vim.cmd('normal 0') end
end

-- stylua: ignore start
map('',  'H',     smart_go_to_begin_of_line, 'Go to start of line after ws, or to beginning')
map('',  'L',     '$',                       'Go to end of line')
map('n', '<C-a>', 'ggVG',                    'Select all the buffer')

-- Clear search highlight with <esc>
map('n', '<esc>', ':noh<cr><esc>',           'Escape and clear hlsearch')

-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap('[p', '<Cmd>exe "put! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "put "  . v:register<CR>', 'Paste Below')


  -- keymaps
  -- You can use the capture groups defined in `textobjects.scm`
local xomap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set({ 'x', 'o' }, lhs, rhs, { desc = desc })
end
local select = function(capture)
    return '<Cmd>lua require("nvim-treesitter-textobjects.select").select_textobject("' .. capture .. '", "textobjects")<CR>'
end
xomap('af', select('@function.outer'), 'Around Function')
xomap('af', select('@function.outer'), 'Inside Function')
xomap("ac", select("@class.outer"), 'Around Class')
xomap("ic", select("@class.inner"), 'Inside Class')
xomap("aa", select("@parameter.outer"), 'Around Parameter')
xomap("ia", select("@parameter.inner"), 'Inside Parameter')
xomap("al", select("@loop.outer"), 'Around Loop')
xomap("il", select("@loop.inner"), 'Inside Loop')
xomap("ai", select("@conditional.outer"), 'Around Conditional')
xomap("ii", select("@conditional.inner"), 'Inside Conditional')
xomap("ab", select("@block.outer"), 'Around Block')
xomap("ib", select("@block.inner"), 'Inside Block')
-- Many general mappings are created by 'mini.basics'. See 'plugin/30_mini.lua'

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- Leader mappings ============================================================

-- Neovim has the concept of a Leader key (see `:h <Leader>`). It is a configurable
-- key that is primarily used for "workflow" mappings (opposed to text editing).
-- Like "open file explorer", "create scratch buffer", "pick from buffers".
--
-- In 'plugin/10_options.lua' <Leader> is set to <Space>, i.e. press <Space>
-- whenever there is a suggestion to press <Leader>.
--
-- This config uses a "two key Leader mappings" approach: first key describes
-- semantic group, second key executes an action. Both keys are usually chosen
-- to create some kind of mnemonic.
-- Example: `<Leader>f` groups "find" type of actions; `<Leader>ff` - find files.
-- Use this section to add Leader mappings in a structural manner.
--
-- Usually if there are global and local kinds of actions, lowercase second key
-- denotes global and uppercase - local.
-- Example: `<Leader>fs` / `<Leader>fS` - find workspace/document LSP symbols.
--
-- Many of the mappings use 'mini.nvim' modules set up in 'plugin/30_mini.lua'.

-- Create a global table with information about Leader groups in certain modes.
-- This is used to provide 'mini.clue' with extra clues.
-- Add an entry if you create a new group.
_G.Config.leader_group_clues = {}
local add_group = function(a)
  table.insert(_G.Config.leader_group_clues, a)
end

-- Helpers for a more concise `<Leader>` mappings.
-- Most of the mappings use `<Cmd>...<CR>` string as a right hand side (RHS) in
-- an attempt to be more concise yet descriptive. See `:h <Cmd>`.
-- This approach also doesn't require the underlying commands/functions to exist
-- during mapping creation: a "lazy loading" approach to improve startup time.
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

add_group  { mode = 'n', keys = '<Leader>b', desc = 'Buffer...' }
-- b is for 'Buffer'. Common usage:
-- - `<Leader>bs` - create scratch (temporary) buffer
-- - `<Leader>ba` - navigate to the alternative buffer
-- - `<Leader>bw` - wipeout (fully delete) current buffer
local new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

nmap_leader('bb', '<Cmd>b#<CR>',                                 'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>',         'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
nmap_leader('bs', new_scratch_buffer,                            'Scratch')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>',        'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- c is for 'Code'. Common usage:
-- - `<Leader>cd` - show more diagnostic details in a floating window
-- - `<Leader>cr` - perform rename via LSP
-- - `<Leader>cs` - navigate to source definition of symbol under cursor
--
-- NOTE: most LSP mappings represent a more structured way of replacing built-in
-- LSP mappings (like `:h gra` and others). This is needed because `gr` is mapped
-- by an "replace" operator in 'mini.operators' (which is more commonly used).
add_group  { mode = 'n', keys = '<Leader>c', desc = 'Code...' }
add_group  { mode = 'x', keys = '<Leader>c', desc = 'Code...' }
local betterReferences = 'require("fzf-lua").lsp_references({ ignore_current_line = true, jump1 = true })'
local usagesContainingMethod =
  '<Cmd>lua require("nvim-treesitter-textobjects.move").goto_previous_start("@function.name", "textobjects"); ' .. betterReferences .. '<CR>'

nmap("<C-.>",     '<Cmd>FzfLua lsp_code_actions<CR>',                             "Code Action")
nmap_leader("c?", function() vim.diagnostic.open_float({border = 'rounded'}) end, "Line Diagnostics")
nmap_leader("ca", '<Cmd>FzfLua lsp_code_actions<CR>',                             "Code Action")
nmap_leader('cd', '<Cmd>FzfLua lsp_definitions<CR>',                              'Source definition')
nmap_leader("cD", '<Cmd>FzfLua lsp_declarations<CR>',                             "Goto Declaration")
xmap_leader('cf', '<Cmd>lua require("conform").format({lsp_fallback=true})<CR>',  'Format selection')
nmap_leader('ci', '<Cmd>FzfLua lsp_implementations<CR>',                          'Implementation')
nmap_leader('ch', vim.lsp.buf.hover,                                              'Hover')
nmap_leader("cl", "<Cmd>check lsp<cr>",                                           "LSP Info")
nmap_leader('cr', vim.lsp.buf.rename,                                             'Rename')
nmap_leader("cs", vim.lsp.buf.signature_help,                                     "Signature Help")
nmap_leader('cu', '<Cmd>lua ' .. betterReferences .. '<CR>',                      'Usages')
nmap_leader("cU", usagesContainingMethod,                                         "Goto Usages of containing method")
nmap_leader('ct', '<Cmd>FzfLua lsp_typedefs<CR>',                                 'Type definition')

add_group({ mode = 'n', keys = '<Leader>d', desc = 'Debugging...' })
nmap_leader('dd', "<Cmd>lua require('easy-dotnet').run_profile_default()<cr>",   'Run default profile')
nmap_leader('dp', "<Cmd>lua require('dap').repl.open()<cr>",                     'Open REPL')
nmap_leader('dl', "<Cmd>lua require('dap').run_last()<cr>",                      'Run last debug config')
nmap_leader('dt', "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<cr>", 'Debug nearest test')
nmap('<F5>',      "<Cmd>lua require('dap').continue()<cr>",                      'Continue')
nmap('<F6>',      "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<cr>", 'Debug nearest test')
nmap('<F9>',      "<Cmd>lua require('dap').toggle_breakpoint()<cr>",             'Toggle breakpoint')
nmap('<F10>',     "<Cmd>lua require('dap').step_over()<cr>",                     'Step over')
nmap('<F11>',     "<Cmd>lua require('dap').step_into()<cr>",                     'Step into')
nmap('<F8>',      "<Cmd>lua require('dap').step_out()<cr>",                      'Step out')
nmap('<F12>',     "<Cmd>lua require('dap').step_out()<cr>",                      'Step out')

add_group  { mode = 'n', keys = '<Leader>e', desc = 'Explore/Edit...' }
-- e is for 'Explore' and 'Edit'. Common usage:
-- - `<Leader>ed` - open explorer at current working directory
-- - `<Leader>ef` - open directory of current file (needs to be present on disk)
-- - `<Leader>ei` - edit 'init.lua'
-- - All mappings that use `edit_plugin_file` - edit 'plugin/' config files
local edit_plugin_file = function(filename)
  return string.format('<Cmd>edit %s/plugin/%s<CR>', vim.fn.stdpath('config'), filename)
end
local explore_at_file = '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>'
local explore_quickfix = function()
  for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.fn.getwininfo(win_id)[1].quickfix == 1 then return vim.cmd('cclose') end
  end
  vim.cmd('copen')
end

nmap_leader('ed', '<Cmd>lua MiniFiles.open()<CR>',          'Directory')
nmap_leader('ef', explore_at_file,                          'File directory')
nmap_leader('ei', '<Cmd>edit $MYVIMRC<CR>',                 'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'),       'Keymaps config')
nmap_leader('em', edit_plugin_file('30_mini.lua'),          'MINI config')
nmap_leader('en', '<Cmd>lua MiniNotify.show_history()<CR>', 'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'),       'Options config')
nmap_leader('ep', edit_plugin_file('40_plugins.lua'),       'Plugins config')
nmap_leader('eq', explore_quickfix,                         'Quickfix')

add_group  { mode = 'n', keys = '<Leader>f', desc = 'Find...' }
-- f is for 'Fuzzy Find'. Common usage:
-- - `<Leader>ff` - find files; for best performance requires `ripgrep`
-- - `<Leader>fg` - find inside files; requires `ripgrep`
-- - `<Leader>fh` - find help tag
-- - `<Leader>fr` - resume latest picker
-- - `<Leader>fv` - all visited paths; requires 'mini.visits'
--
-- All these use 'mini.pick'. See `:h MiniPick-overview` for an overview.
local pick_added_hunks_buf = '<Cmd>Pick git_hunks path="%"<CR>'

nmap_leader('f/', '<Cmd>FzfLua search_history<CR>'            , '"/" history')
nmap_leader('f:', '<Cmd>FzfLua command_history<CR>'           , '":" history')
nmap_leader('fa', '<Cmd>FzfLua git_hunks<CR>'                 , 'Added hunks (all)')
nmap_leader('fA', pick_added_hunks_buf                        , 'Added hunks (buf)')
nmap_leader('fb', '<Cmd>FzfLua buffers<CR>'                   , 'Buffers')
nmap_leader('fc', '<Cmd>FzfLua git_commits<CR>'               , 'Commits (all)')
nmap_leader('fC', '<Cmd>FzfLua git_bcommits<CR>'              , 'Commits (buf)')
nmap_leader('fd', '<Cmd>FzfLua diagnostics_workspace<CR>'     , 'Diagnostic workspace')
nmap_leader('fD', '<Cmd>FzfLua diagnostics_document<CR>'      , 'Diagnostic buffer')
nmap_leader('ff', '<Cmd>FzfLua files<CR>'                     , 'Files')
nmap_leader('fg', '<Cmd>FzfLua live_grep<CR>'                 , 'Grep live')
nmap_leader('fG', '<Cmd>FzfLua grep_cword<CR>'                , 'Grep current word')
nmap_leader('fh', '<Cmd>FzfLua help<CR>'                      , 'Help tags')
nmap_leader('fH', '<Cmd>FzfLua hl_groups<CR>'                 , 'Highlight groups')
nmap_leader('fl', '<Cmd>FzfLua lines<CR>'                     , 'Lines (buf)')
nmap_leader('fo', '<Cmd>FzfLua oldfiles'                      , 'Old files')
nmap_leader('fm', '<Cmd>FzfLua git_hunks<CR>'                 , 'Modified hunks (all)')
nmap_leader('fM', '<Cmd>FzfLua git_hunks path="%"<CR>'        , 'Modified hunks (buf)')
nmap_leader('fy', '<Cmd>FzfLua registers<CR>'                 , 'Registers')
nmap_leader('fr', '<Cmd>FzfLua resume<CR>'                    , 'Resume')
nmap_leader('fs', '<Cmd>FzfLua lsp_workspace_symbols<CR>'     , 'Symbols workspace')
nmap_leader('fS', '<Cmd>FzfLua lsp_document_symbols<CR>'      , 'Symbols document')
nmap_leader('fv', '<Cmd>FzfLua visit_paths cwd=""<CR>'        , 'Visit paths (all)')
nmap_leader('fV', '<Cmd>FzfLua visit_paths<CR>'               , 'Visit paths (cwd)')

add_group  { mode = 'n', keys = '<Leader>g', desc = 'Git...' }
add_group  { mode = 'x', keys = '<Leader>g', desc = 'Git...' }
-- g is for 'Git'. Common usage:
-- - `<Leader>gs` - show information at cursor
-- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
local git_log_buf_cmd = git_log_cmd .. ' --follow -- %'

nmap_leader('ga', '<Cmd>Git diff --cached<CR>',             'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>',        'Added diff buffer')
nmap_leader('gc', '<Cmd>Git commit<CR>',                    'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',            'Commit amend')
nmap_leader('gd', '<Cmd>Git diff<CR>',                      'Diff')
nmap_leader('gD', '<Cmd>Git diff -- %<CR>',                 'Diff buffer')
nmap_leader('gg', '<Cmd>LazyGitCurrentFile<CR>',            'LazyGit')
nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>',         'Log')
nmap_leader('gL', '<Cmd>' .. git_log_buf_cmd .. '<CR>',     'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>', 'Toggle overlay')
nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',  'Show at cursor')

xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at selection')

add_group  { mode = 'n', keys = '<Leader>m', desc = 'Map...' }
-- m is for 'Map'. Common usage:
-- - `<Leader>mt` - toggle map from 'mini.map' (closed by default)
-- - `<Leader>mf` - focus on the map for fast navigation
-- - `<Leader>ms` - change map's side (if it covers something underneath)
nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>', 'Focus (toggle)')
nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>',      'Refresh')
nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>',  'Side (toggle)')
nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>',       'Toggle')

add_group  { mode = 'n', keys = '<Leader>o', desc = 'Other...' }
-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',    'Trim trailspace')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',          'Zoom toggle')

-- Refactoring

-- Function to perform LSP code actions
local function code_action()
    local params = vim.lsp.util.make_range_params()
    params.context = { diagnostics = {} } -- You can expand this with diagnostics if needed

    -- Call the LSP code action
    vim.lsp.buf_request_all(0, 'textDocument/codeAction', params, function(err, res)
        if err then
            print("Error: " .. err.message)
            return
        end
        for _, action in ipairs(res or {}) do
            if action.title == "Inline Variable" then  -- Change this to your specific action title
                vim.lsp.buf.execute_command(action.command)
            end
        end
    end)
end

-- Key mapping for the specific code action
nmap_leader('ia', code_action, "Inline variable")

add_group  { mode = 'n', keys = '<Leader>r', desc = 'Refactor...' }
add_group  { mode = 'x', keys = '<Leader>r', desc = 'Refactor...' }
nmap_leader("rb",  ":Refactor extract_block<CR>",         "Extract block")
nmap_leader("rbf", ":Refactor extract_block_to_file<CR>", "Extract block to file")
xmap_leader("re",  ":Refactor extract<CR>",               "Extract function")
xmap_leader("rf",  ":Refactor extract_to_file<CR>",       "Extract function to file")
nmap_leader("ri",  ":Refactor inline_var<CR>",            "Inline variable")
xmap_leader("ri",  ":Refactor inline_var<CR>",            "Inline variable")
nmap_leader("rI",  ":Refactor inline_func<CR>",           "Inline function")
nmap_leader("rn",  vim.lsp.buf.rename,                    "Rename")
xmap_leader("rv",  ":Refactor extract_var<CR>",           "Extract variable")

add_group  { mode = 'n', keys = '<Leader>R', desc = 'REST...' }
-- REST Client (lookup Kulala plugin configuration)

add_group  { mode = 'n', keys = '<Leader>s', desc = 'Session...' }
-- s is for 'Session'. Common usage:
-- - `<Leader>sn` - start new session
-- - `<Leader>sr` - read previously started session
-- - `<Leader>sd` - delete previously started session
local session_new = 'MiniSessions.write(vim.fn.input("Session name: "))'

nmap_leader('sd', '<Cmd>lua MiniSessions.select("delete")<CR>', 'Delete')
nmap_leader('sn', '<Cmd>lua ' .. session_new .. '<CR>',         'New')
nmap_leader('sr', '<Cmd>lua MiniSessions.select("read")<CR>',   'Read')
nmap_leader('sw', '<Cmd>lua MiniSessions.write()<CR>',          'Write current')

add_group  { mode = 'n', keys = '<Leader>t', desc = 'Terminal...' }
-- t is for 'Terminal'
nmap_leader('tT', '<Cmd>horizontal term<CR>', 'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>',   'Terminal (vertical)')

add_group  { mode = 'n', keys = '<Leader>v', desc = 'Visits...' }
-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
-- - `<Leader>vc` - pick among all files with "core" label.
local make_pick_core = function(cwd, desc)
  return function()
    local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
    local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
    MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
  end
end

nmap_leader('vc', make_pick_core('',  'Core visits (all)'),       'Core visits (all)')
nmap_leader('vC', make_pick_core(nil, 'Core visits (cwd)'),       'Core visits (cwd)')
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>',    'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>',          'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>',       'Remove label')
-- stylua: ignore end
