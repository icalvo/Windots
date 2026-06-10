-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

-- General mappings ===========================================================

-- Use this section to add custom general mappings. See `:h vim.keymap.set()`.

-- Helper to create a Normal mode mapping
local nmap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()
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
local cmd = function(cmdexp) return '<Cmd>' .. cmdexp .. '<CR>' end
local lua = function(luaexp) return cmd('lua ' .. luaexp) end
local call = function(module, callexp)
  return lua("require('" .. module .. "')." .. callexp)
end
-- better up/down
map({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Down', expr = true })
map({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Up', expr = true })

nmap('<PageDown>', '<C-d>', 'PgDown does half page')
nmap('<PageUp>', '<C-u>', 'PgUp does half page')

-- shift doesn't leave visual mode
map('x', '>', '>gv', { desc = 'Shift right and stay visual' })
map('x', '<', '<gv', { desc = 'Shift left and stay visual' })

-- Clear search highlight with <esc>
nmap('<esc>', cmd('noh') .. '<esc>', 'Escape and clear hlsearch')

nmap('[<Space>', 'i<C-m><Esc>', 'Break line')
nmap(']<Space>', 'mzo<Esc>0"_D`z', 'Insert line below')
-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap('[p', cmd('exe "put! " . v:register'), 'Paste Above')
nmap(']p', cmd('exe "put "  . v:register'), 'Paste Below')

nmap('\\p', lua('MiniHipatterns.toggle()'), 'MiniHipatterns')
-- keymaps
local xomap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set({ 'x', 'o' }, lhs, rhs, { desc = desc })
end

local tsto = function(module, capture)
  return call('nvim-treesitter-textobjects.' .. module, capture)
end
local select = function(capture)
  return tsto('select', 'select_textobject("' .. capture .. '", "textobjects")')
end
xomap('af', select('@function.outer'), 'Around Function')
xomap('af', select('@function.outer'), 'Inside Function')
xomap('ac', select('@class.outer'), 'Around Class')
xomap('ic', select('@class.inner'), 'Inside Class')
xomap('aa', select('@parameter.outer'), 'Around Parameter')
xomap('ia', select('@parameter.inner'), 'Inside Parameter')
xomap('al', select('@loop.outer'), 'Around Loop')
xomap('il', select('@loop.inner'), 'Inside Loop')
xomap('ai', select('@conditional.outer'), 'Around Conditional')
xomap('ii', select('@conditional.inner'), 'Inside Conditional')
xomap('ab', select('@block.outer'), 'Around Block')
xomap('ib', select('@block.inner'), 'Inside Block')
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

add_group  { mode = 'n', keys = '<Leader>a', desc = 'Actions...' }
nmap_leader('aa', 'ggVG',                              'Select all the buffer')
nmap_leader('aw', cmd 'write',                    'Write')
nmap_leader('ar', cmd 'restart', 'Restart')

add_group  { mode = 'n', keys = '<Leader>b', desc = 'Buffer...' }
-- b is for 'Buffer'. Common usage:
-- - `<Leader>bs` - create scratch (temporary) buffer
-- - `<Leader>ba` - navigate to the alternative buffer
-- - `<Leader>bw` - wipeout (fully delete) current buffer
local new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end
nmap_leader('bb', cmd 'b#',                              'Alternate')
nmap_leader('bd', lua 'MiniBufremove.delete()',         'Delete')
nmap_leader('bD', lua 'MiniBufremove.delete(0, true)',  'Delete!')
nmap_leader('bs', new_scratch_buffer,                   'Scratch')
nmap_leader('bw', lua 'MiniBufremove.wipeout()',        'Wipeout')
nmap_leader('bW', lua 'MiniBufremove.wipeout(0, true)', 'Wipeout!')

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
  lua('require("nvim-treesitter-textobjects.move").goto_previous_start("@function.name", "textobjects"); ' .. betterReferences)

nmap("<C-.>",     cmd 'FzfLua lsp_code_actions',                                  "Code Action")
nmap_leader("c?", function() vim.diagnostic.open_float({border = 'rounded'}) end, "Line Diagnostics")
nmap_leader("ca", cmd 'FzfLua lsp_code_actions',                                  "Code Action")
nmap_leader('cd', cmd 'FzfLua lsp_definitions',                                   'Source definition')
nmap_leader("cD", cmd 'FzfLua lsp_declarations',                                  "Goto Declaration")
nmap_leader("cc", lua 'vim.lsp.codelens.run()',                                   "Codelens")
nmap_leader("cC", call('nvim-treesitter-textobjects.move', 'goto_previous_start("@function.name", "textobjects")'), "Containing method")
xmap_leader('cf', call('conform', 'format({lsp_fallback=true})'),                 'Format selection')
nmap_leader('ci', cmd 'FzfLua lsp_implementations',                               'Implementation')
nmap_leader('ch', vim.lsp.buf.hover,                                              'Hover')
nmap_leader("cl", cmd 'check lsp',                                                "LSP Info")
nmap_leader('cr', vim.lsp.buf.rename,                                             'Rename')
nmap_leader("cs", vim.lsp.buf.signature_help,                                     "Signature Help")
nmap_leader('cu', lua(betterReferences),                                          'Usages')
nmap_leader("cU", usagesContainingMethod,                                         "Goto Usages of containing method")
nmap_leader('ct', cmd 'FzfLua lsp_typedefs',                                      'Type definition')

add_group({ mode = 'n', keys = '<Leader>d', desc = 'Debugging...' })
nmap_leader('dd', call('easy-dotnet', 'debug_profile_default()'),  'Run default profile')
nmap_leader('dp', call('dap', 'repl.open()'),                      'Open REPL')
nmap_leader('dl', call('dap', 'run_last()'),                       'Run last debug config')
nmap_leader('dt', call('neotest', "run.run({strategy = 'dap'})"),  'Debug nearest test')
nmap_leader('ds', call('dap', 'terminate()'),                      'Stop debugging')
nmap('<F5>',      call('dap', 'continue()'),                       'Continue')
nmap('<F6>',      call('neotest', "run.run({strategy = 'dap'})"),  'Debug nearest test')
nmap('<F9>',      call('dap', 'toggle_breakpoint()'),              'Toggle breakpoint')
nmap('<F10>',     call('dap', 'step_over()'),                      'Step over')
nmap('<F11>',     call('dap', 'step_into()'),                      'Step into')
nmap('<F8>',      call('dap', 'step_out()'),                       'Step out')
nmap('<F12>',     call('dap', 'step_out()'),                       'Step out')

add_group  { mode = 'n', keys = '<Leader>e', desc = 'Explore/Edit...' }
-- e is for 'Explore' and 'Edit'. Common usage:
-- - `<Leader>ed` - open explorer at current working directory
-- - `<Leader>ef` - open directory of current file (needs to be present on disk)
-- - `<Leader>ei` - edit 'init.lua'
-- - All mappings that use `edit_plugin_file` - edit 'plugin/' config files
local edit_plugin_file = function(filename)
  return cmd(string.format('edit %s/plugin/%s', vim.fn.stdpath('config'), filename))
end
local explore_at_file = lua 'MiniFiles.open(vim.api.nvim_buf_get_name(0))'
local explore_quickfix = function()
  for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.fn.getwininfo(win_id)[1].quickfix == 1 then return vim.cmd('cclose') end
  end
  vim.cmd('copen')
end

nmap_leader('ed', lua 'MiniFiles.open()',             'Directory')
nmap_leader('ef', explore_at_file,                    'Current file directory')
nmap_leader('ei', cmd 'edit $MYVIMRC',                'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'), 'Keymaps config')
nmap_leader('em', edit_plugin_file('30_mini.lua'),    'MINI config')
nmap_leader('en', lua 'MiniNotify.show_history()',    'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'), 'Options config')
nmap_leader('ep', edit_plugin_file('40_plugins.lua'), 'Plugins config')
nmap_leader('eq', explore_quickfix,                   'Quickfix')

add_group  { mode = 'n', keys = '<Leader>f', desc = 'Find...' }
local pick_added_hunks_buf = cmd 'Pick git_hunks path="%"'
local lsp_live_workspace_symbols_classes_first = function(opts)  
  opts = opts or {}  
    
  -- Define priority order (lower number = higher priority)  
  local kind_priority = {  
    Class = 1,  
    Interface = 2,  
    Struct = 3,  
    Enum = 4,  
    -- Other kinds will get priority 99  
  }  
    
  opts.symbol_fmt = function(s, _)  
    local priority = kind_priority[s] or 99  
    -- Add numeric prefix for sorting, will be hidden by fzf  
    return string.format("%02d [%s]", priority, s)  
  end  
    
  -- Configure fzf to sort by the prefix  
  opts.fzf_opts = opts.fzf_opts or {}  
  opts.fzf_opts["--tiebreak"] = "index"  -- Sort by input order  
    
  return require('fzf-lua').lsp_live_workspace_symbols(opts)  
end
nmap_leader('f/', cmd 'FzfLua search_history'        , '"/" history')
nmap_leader('f:', cmd 'FzfLua command_history'       , '":" history')
nmap_leader('fa', cmd 'FzfLua git_hunks'             , 'Added hunks (all)')
nmap_leader('fA', pick_added_hunks_buf               , 'Added hunks (buf)')
nmap_leader('fb', cmd 'FzfLua buffers'               , 'Buffers')
nmap_leader('fc', cmd 'FzfLua git_commits'           , 'Commits (all)')
nmap_leader('fC', cmd 'FzfLua git_bcommits'          , 'Commits (buf)')
nmap_leader('fd', cmd 'FzfLua diagnostics_workspace' , 'Diagnostic workspace')
nmap_leader('fD', cmd 'FzfLua diagnostics_document'  , 'Diagnostic buffer')
nmap_leader('ff', cmd 'FzfLua files'                 , 'Files')
nmap_leader('fg', cmd 'FzfLua live_grep'             , 'Grep live')
nmap_leader('fG', cmd 'FzfLua grep_cword'            , 'Grep current word')
nmap_leader('fh', cmd 'FzfLua helptags'                  , 'Help tags')
nmap('<F1>', cmd 'FzfLua helptags', 'Help')
nmap_leader('fH', cmd 'FzfLua hl_groups'             , 'Highlight groups')
nmap_leader('fl', cmd 'FzfLua lines'                 , 'Lines (buf)')
nmap_leader('fo', cmd 'FzfLua oldfiles'              , 'Old files')
nmap_leader('fm', cmd 'FzfLua git_hunks'             , 'Modified hunks (all)')
nmap_leader('fM', cmd 'FzfLua git_hunks path="%"'    , 'Modified hunks (buf)')
nmap_leader('fy', cmd 'FzfLua registers'             , 'Registers')
nmap_leader('fr', cmd 'FzfLua resume'                , 'Resume')
nmap_leader('fs', lsp_live_workspace_symbols_classes_first, 'Symbols workspace')
nmap_leader('fS', cmd 'FzfLua lsp_document_symbols'  , 'Symbols document')
nmap_leader('fv', cmd 'FzfLua visit_paths cwd=""'    , 'Visit paths (all)')
nmap_leader('fV', cmd 'FzfLua visit_paths'           , 'Visit paths (cwd)')

add_group  { mode = 'n', keys = '<Leader>g', desc = 'Git...' }
add_group  { mode = 'x', keys = '<Leader>g', desc = 'Git...' }
nmap_leader('g', cmd 'LazyGitCurrentFile', 'LazyGit')

-- h is for 'Harpoon'. Common usage:
-- - `<Leader>hv` - add    "core" label to current file.
-- - `<Leader>hV` - remove "core" label to current file.
-- - `<Leader>hc` - pick among all files with "core" label.
local make_pick_core = function(cwd, desc)
  return function()
        local MiniVisits = require("mini.visits")
        local MiniExtra = require("mini.extra")
    local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
    local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
    MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
  end
end

add_group  { mode = 'n', keys = '<Leader>h', desc = 'Visits...' }
nmap_leader('hc', make_pick_core('',  'Core visits (all)'),       'Core visits (all)')
nmap_leader('hC', make_pick_core(nil, 'Core visits (cwd)'),       'Core visits (cwd)')
nmap_leader('hh', lua 'MiniVisits.add_label("core")',    'Add "core" label')
nmap_leader('hH', lua 'MiniVisits.remove_label("core")', 'Remove "core" label')
nmap_leader('hl', lua 'MiniVisits.add_label()',          'Add label')
nmap_leader('hL', lua 'MiniVisits.remove_label()',       'Remove label')

add_group  { mode = 'n', keys = '<Leader>m', desc = 'Map...' }
nmap_leader('mf', lua 'MiniMap.toggle_focus()', 'Focus (toggle)')
nmap_leader('mr', lua 'MiniMap.refresh()',      'Refresh')
nmap_leader('ms', lua 'MiniMap.toggle_side()',  'Side (toggle)')
nmap_leader('mt', lua 'MiniMap.toggle()',       'Toggle')
add_group  { mode = 'n', keys = '<Leader>n', desc = 'Dotnet...' }
-- local dotnet = require('easy-dotnet')
-- local diagnostics = require('easy-dotnet.actions.diagnostics')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').get_environment_variables(project_name, project_path, use_default_launch_profile: boolean)
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').is_dotnet_project()<cr>", 'Returns true if a csproj or sln is present in CWD or subdirs')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').try_get_selected_solution()<cr>", 'Returns currently selected solution')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').get_debug_dll()<cr>", '')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').reset()<cr>", '')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').solution_select(path: string)
-- nmap_leader('', '<Cmd>lua require('easy-dotnet').createfile(path: string)

add_group  { mode = 'n', keys = '<Leader>nb', desc = 'Build...' }
nmap_leader('nbb', call('easy-dotnet', 'build()'), 'Build')
nmap_leader('nbss', call('easy-dotnet', 'build_solution()'), 'Build sln')
nmap_leader('nbsq', call('easy-dotnet', 'build_solution_quickfix()'), 'Build sln qf')
nmap_leader('nbq', call('easy-dotnet', 'build_quickfix()'), 'Build qf')
nmap_leader('nbdq', call('easy-dotnet', 'build_default()'), 'Build default')
nmap_leader('nbdq', call('easy-dotnet', 'build_default_quickfix()'), 'Build default qf')
nmap_leader('nbc', call('easy-dotnet', 'clean()'), 'Clean')

add_group  { mode = 'n', keys = '<Leader>nd', desc = 'Diagnostics...' }
nmap_leader('ndd', call('easy-dotnet.actions.diagnostics', 'get_workspace_diagnostics()'), '')
nmap_leader('nde', call('easy-dotnet.actions.diagnostics', "get_workspace_diagnostics('error')"), '')
nmap_leader('ndw', call('easy-dotnet.actions.diagnostics', "get_workspace_diagnostics('warning')"), '')

add_group  { mode = 'n', keys = '<Leader>ne', desc = 'EF...' }
-- nmap_leader('nea', "<Cmd>lua require('easy-dotnet').ef_migrations_add(name: string)
nmap_leader('nel', call('easy-dotnet', 'ef_migrations_list()'), 'EF: Migrations list')
nmap_leader('ned', call('easy-dotnet', 'ef_database_drop()'), 'EF: drop database')
nmap_leader('neu', call('easy-dotnet', 'ef_database_update()'), 'EF: update database')
nmap_leader('nep', call('easy-dotnet', 'ef_database_update_pick()'), 'EF: Update database (pick)')
nmap_leader('ner', call('easy-dotnet', 'ef_migrations_remove()'), 'EF: remove migration')

add_group  { mode = 'n', keys = '<Leader>nl', desc = 'LSP...' }
nmap_leader('nll', call('easy-dotnet', 'lsp_start()'), 'Start lsp server')
nmap_leader('nlr', call('easy-dotnet', 'lsp_restart()'), 'Restart lsp server')
nmap_leader('nls', call('easy-dotnet', 'lsp_stop()'), 'Stop lsp server')

nmap_leader('nn', call('easy-dotnet', 'new()'), 'Creates files/projects')

nmap_leader('no', call('easy-dotnet', 'outdated()'), 'Outdated')

add_group  { mode = 'n', keys = '<Leader>np', desc = 'Nuget...' }
nmap_leader('npa', call('easy-dotnet', 'add_package()'), 'Adds a Nuget package')
nmap_leader('npd', call('easy-dotnet', 'remove_package()'), 'Removes a Nuget package')
nmap_leader('npp', call('easy-dotnet', 'pack()'), 'Pack')
nmap_leader('nps', call('easy-dotnet', 'push()'), 'Push')
nmap_leader('npr', call('easy-dotnet', 'restore()'), 'Restore')

add_group  { mode = 'n', keys = '<Leader>nr', desc = 'Run...' }
nmap_leader('nrr', call('easy-dotnet', 'run()'), 'Run')
nmap_leader('nrpp', call('easy-dotnet', 'run_profile()'), 'Run profile')
nmap_leader('nrpd', call('easy-dotnet', 'run_profile_default()'), 'Run default profile')
nmap_leader('nrd', call('easy-dotnet', 'run_default()'), 'Run default')

nmap_leader('ns', call('easy-dotnet', 'secrets()'), 'Secrets')

add_group  { mode = 'n', keys = '<Leader>nt', desc = 'Test...' }
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').test()<cr>", '')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').testrunner()<cr>", '')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').testrunner_refresh()<cr>", '')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').testrunner_refresh_build()<cr>", '')
nmap_leader('ntl', call('easy-dotnet', 'test_solution()'), 'Runs tests on solution')
nmap_leader('ntt', call('easy-dotnet', 'test_default()'), 'Runs test default')
nmap_leader('nww', call('easy-dotnet', 'watch()'), 'Watch')
nmap_leader('nwd', call('easy-dotnet', 'watch_default()'), 'Watch default')

add_group  { mode = 'n', keys = '<Leader>o', desc = 'Other...' }
-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
nmap_leader('or', lua 'MiniMisc.resize_window()', 'Resize to default width')
nmap_leader('ot', lua 'MiniTrailspace.trim()',    'Trim trailspace')
nmap_leader('oz', lua 'MiniMisc.zoom()',          'Zoom toggle')

-- Pack
add_group  { mode = 'n', keys = '<Leader>p', desc = 'Pack' }
nmap_leader('pu', lua 'vim.pack.update()', 'Update')

-- Refactoring
add_group  { mode = 'n', keys = '<Leader>r', desc = 'Refactor...' }
add_group  { mode = 'x', keys = '<Leader>r', desc = 'Refactor...' }

nmap_leader("rb",  cmd 'Refactor extract_block',         "Extract block")
nmap_leader("rbf", cmd 'Refactor extract_block_to_file', "Extract block to file")
xmap_leader("re",  cmd 'Refactor extract',               "Extract function")
xmap_leader("rf",  cmd 'Refactor extract_to_file',       "Extract function to file")
nmap_leader("ri",  cmd 'Refactor inline_var',            "Inline variable")
nmap_leader("rI",  cmd 'Refactor inline_func',           "Inline function")
nmap_leader("rn",  vim.lsp.buf.rename,                    "Rename")
xmap_leader("rv",  cmd 'Refactor extract_var',           "Extract variable")
nmap_leader("ra", tsto('swap', "swap_next('@function.outer')"), "Move function up")
nmap_leader("rA", tsto('swap', "swap_previous('@function.outer'"), "Move function down")

add_group  { mode = 'n', keys = '<Leader>R', desc = 'REST...' }
-- REST Client (lookup Kulala plugin configuration)

add_group  { mode = 'n', keys = '<Leader>s', desc = 'Session...' }

add_group  { mode = 'n', keys = '<Leader>t', desc = 'Terminal...' }
-- t is for 'Terminal'
nmap_leader('tT', cmd 'horizontal term', 'Terminal (horizontal)')
nmap_leader('tt', cmd 'vertical term',   'Terminal (vertical)')

nmap_leader('u', call('undotree', 'open()'), 'Undotree')

-- View
add_group  { mode = 'n', keys = '<Leader>v', desc = 'View...' }
add_group  { mode = 'x', keys = '<Leader>v', desc = 'View...' }

nmap_leader("vz",  cmd 'ZenMode',         "Zen mode")
-- stylua: ignore end
