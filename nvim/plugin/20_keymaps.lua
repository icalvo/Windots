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

-- better up/down
map({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Down', expr = true })
map({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Up', expr = true })

nmap('<PageDown>', '<C-d>', 'PgDown does half page')
nmap('<PageUp>', '<C-u>', 'PgUp does half page')

-- shift doesn't leave visual mode
map('x', '>', '>gv', { desc = 'Shift right and stay visual' })
map('x', '<', '<gv', { desc = 'Shift left and stay visual' })

-- Clear search highlight with <esc>
nmap('<esc>', ':noh<cr><esc>', 'Escape and clear hlsearch')

nmap('[<Space>', 'i<C-m><Esc>', 'Break line')
nmap(']<Space>', 'mzo<Esc>0"_D`z', 'Insert line below')
-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap('[p', '<Cmd>exe "put! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "put "  . v:register<CR>', 'Paste Below')

nmap('\\p', '<Cmd>lua MiniHipatterns.toggle()<cr>', 'MiniHipatterns')
-- keymaps
local xomap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set({ 'x', 'o' }, lhs, rhs, { desc = desc })
end

local tsto = function(module, capture)
  return '<Cmd>lua require("nvim-treesitter-textobjects.'
    .. module
    .. '").'
    .. capture
    .. '<CR>'
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
nmap_leader('aw', '<Cmd>write<CR>',                    'Write')
nmap_leader('ar', '<Cmd>writeall<CR><CMD>restart<CR>', 'Write')

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
nmap_leader("cc", '<Cmd>lua vim.lsp.codelens.run()<CR>',                          "Codelens")
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
nmap_leader('dd', "<Cmd>lua require('easy-dotnet').debug_profile_default()<cr>", 'Run default profile')
nmap_leader('dp', "<Cmd>lua require('dap').repl.open()<cr>",                     'Open REPL')
nmap_leader('dl', "<Cmd>lua require('dap').run_last()<cr>",                      'Run last debug config')
nmap_leader('dt', "<Cmd>lua require('neotest').run.run({strategy = 'dap'})<cr>", 'Debug nearest test')
nmap_leader('ds', "<Cmd>lua require('dap').terminate()<cr>",                     'Stop debugging')
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
nmap_leader('ef', explore_at_file,                          'Current file directory')
nmap_leader('ei', '<Cmd>edit $MYVIMRC<CR>',                 'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'),       'Keymaps config')
nmap_leader('em', edit_plugin_file('30_mini.lua'),          'MINI config')
nmap_leader('en', '<Cmd>lua MiniNotify.show_history()<CR>', 'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'),       'Options config')
nmap_leader('ep', edit_plugin_file('40_plugins.lua'),       'Plugins config')
nmap_leader('eq', explore_quickfix,                         'Quickfix')

add_group  { mode = 'n', keys = '<Leader>f', desc = 'Find...' }
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
nmap_leader('fo', '<Cmd>FzfLua oldfiles<CR>'                  , 'Old files')
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
nmap_leader('g', '<Cmd>LazyGitCurrentFile<CR>',            'LazyGit')

add_group  { mode = 'n', keys = '<Leader>m', desc = 'Map...' }
nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>', 'Focus (toggle)')
nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>',      'Refresh')
nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>',  'Side (toggle)')
nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>',       'Toggle')
add_group  { mode = 'n', keys = '<Leader>n', desc = 'Dotnet...' }
add_group  { mode = 'n', keys = '<Leader>nl', desc = 'LSP...' }
add_group  { mode = 'n', keys = '<Leader>nt', desc = 'Test...' }
add_group  { mode = 'n', keys = '<Leader>nb', desc = 'Build...' }
add_group  { mode = 'n', keys = '<Leader>ne', desc = 'EF...' }
add_group  { mode = 'n', keys = '<Leader>np', desc = 'Nuget...' }
add_group  { mode = 'n', keys = '<Leader>nr', desc = 'Run...' }
add_group  { mode = 'n', keys = '<Leader>nd', desc = 'Diagnostics...' }
-- local dotnet = require('easy-dotnet')
-- local diagnostics = require('easy-dotnet.actions.diagnostics')
nmap_leader('nll', "<Cmd>lua require('easy-dotnet').lsp_start()<cr>", 'Start lsp server')
nmap_leader('nlr', "<Cmd>lua require('easy-dotnet').lsp_restart()<cr>", 'Restart lsp server')
nmap_leader('nls', "<Cmd>lua require('easy-dotnet').lsp_stop()<cr>", 'Stop lsp server')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').get_environment_variables(project_name, project_path, use_default_launch_profile: boolean)
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').is_dotnet_project()<cr>", 'Returns true if a csproj or sln is present in CWD or subdirs')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').try_get_selected_solution()<cr>", 'Returns currently selected solution')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').get_debug_dll()<cr>", '')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').reset()<cr>", '')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').test()<cr>", '')
nmap_leader('ntl', "<Cmd>lua require('easy-dotnet').test_solution()<cr>", 'Runs tests on solution')
nmap_leader('ntt', "<Cmd>lua require('easy-dotnet').test_default()<cr>", 'Runs test default')

-- nmap_leader('', "<Cmd>lua require('easy-dotnet').testrunner()<cr>", '')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').testrunner_refresh()<cr>", '')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').testrunner_refresh_build()<cr>", '')
nmap_leader('nn', "<Cmd>lua require('easy-dotnet').new()<cr>", 'Creates files/projects')
nmap_leader('no', "<Cmd>lua require('easy-dotnet').outdated()<cr>", 'Outdated')
nmap_leader('npa', "<Cmd>lua require('easy-dotnet').add_package()<cr>", 'Adds a Nuget package')
nmap_leader('npd', "<Cmd>lua require('easy-dotnet').remove_package()<cr>", 'Removes a Nuget package')
nmap_leader('npp', "<Cmd>lua require('easy-dotnet').pack()<cr>", 'Pack')
nmap_leader('nps', "<Cmd>lua require('easy-dotnet').push()<cr>", 'Push')
nmap_leader('npr', "<Cmd>lua require('easy-dotnet').restore()<cr>", 'Restore')
-- nmap_leader('', "<Cmd>lua require('easy-dotnet').solution_select(path: string)
nmap_leader('ner', "<Cmd>lua require('easy-dotnet').ef_migrations_remove()<cr>", 'EF: remove migration')
-- nmap_leader('nea', "<Cmd>lua require('easy-dotnet').ef_migrations_add(name: string)
nmap_leader('nel', "<Cmd>lua require('easy-dotnet').ef_migrations_list()<cr>", 'EF: Migrations list')
nmap_leader('ned', "<Cmd>lua require('easy-dotnet').ef_database_drop()<cr>", 'EF: drop database')
nmap_leader('neu', "<Cmd>lua require('easy-dotnet').ef_database_update()<cr>", 'EF: update database')
nmap_leader('nep', "<Cmd>lua require('easy-dotnet').ef_database_update_pick()<cr>", 'EF: Update database (pick)')
-- nmap_leader('', '<Cmd>lua require('easy-dotnet').createfile(path: string)
nmap_leader('nbb', "<Cmd>lua require('easy-dotnet').build()<cr>", 'Build')
nmap_leader('nbss', "<Cmd>lua require('easy-dotnet').build_solution()<cr>", 'Build sln')
nmap_leader('nbsq', "<Cmd>lua require('easy-dotnet').build_solution_quickfix()<cr>", 'Build sln qf')
nmap_leader('nbq', "<Cmd>lua require('easy-dotnet').build_quickfix()<cr>", 'Build qf')
nmap_leader('nbdq', "<Cmd>lua require('easy-dotnet').build_default()<cr>", 'Build default')
nmap_leader('nbdq', "<Cmd>lua require('easy-dotnet').build_default_quickfix()<cr>", 'Build default qf')
nmap_leader('nbc', "<Cmd>lua require('easy-dotnet').clean()<cr>", 'Clean')
nmap_leader('nrr', "<Cmd>lua require('easy-dotnet').run()<cr>", 'Run')
nmap_leader('nrpp', "<Cmd>lua require('easy-dotnet').run_profile()<cr>", 'Run profile')
nmap_leader('nrpd', "<Cmd>lua require('easy-dotnet').run_profile_default()<cr>", 'Run default profile')
nmap_leader('nrd', "<Cmd>lua require('easy-dotnet').run_default()<cr>", 'Run default')
nmap_leader('nww', "<Cmd>lua require('easy-dotnet').watch()<cr>", 'Watch')
nmap_leader('nwd', "<Cmd>lua require('easy-dotnet').watch_default()<cr>", 'Watch default')
nmap_leader('ns', "<Cmd>lua require('easy-dotnet').secrets()<cr>", 'Secrets')

nmap_leader('ndd', "<Cmd>lua require('easy-dotnet.actions.diagnostics').get_workspace_diagnostics()<cr>", '')
nmap_leader('nde', "<Cmd>lua require('easy-dotnet.actions.diagnostics').get_workspace_diagnostics('error')<cr>", '')
nmap_leader('ndw', "<Cmd>lua require('easy-dotnet.actions.diagnostics').get_workspace_diagnostics('warning')<cr>", '')

add_group  { mode = 'n', keys = '<Leader>o', desc = 'Other...' }
-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',    'Trim trailspace')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',          'Zoom toggle')

-- Pack
add_group  { mode = 'n', keys = '<Leader>p', desc = 'Pack' }
nmap_leader('pu', '<Cmd>lua vim.pack.update()<CR>', 'Update')

-- Refactoring
add_group  { mode = 'n', keys = '<Leader>r', desc = 'Refactor...' }
add_group  { mode = 'x', keys = '<Leader>r', desc = 'Refactor...' }

nmap_leader("rb",  ":Refactor extract_block<CR>",         "Extract block")
nmap_leader("rbf", ":Refactor extract_block_to_file<CR>", "Extract block to file")
xmap_leader("re",  ":Refactor extract<CR>",               "Extract function")
xmap_leader("rf",  ":Refactor extract_to_file<CR>",       "Extract function to file")
nmap_leader("ri",  ":Refactor inline_var<CR>",            "Inline variable")
nmap_leader("rI",  ":Refactor inline_func<CR>",           "Inline function")
nmap_leader("rn",  vim.lsp.buf.rename,                    "Rename")
xmap_leader("rv",  ":Refactor extract_var<CR>",           "Extract variable")
nmap_leader("ra", tsto('swap', "swap_next('@function.outer')"), "Move function up")
nmap_leader("rA", tsto('swap', "swap_previous('@function.outer'"), "Move function down")

add_group  { mode = 'n', keys = '<Leader>R', desc = 'REST...' }
-- REST Client (lookup Kulala plugin configuration)

add_group  { mode = 'n', keys = '<Leader>s', desc = 'Session...' }

add_group  { mode = 'n', keys = '<Leader>t', desc = 'Terminal...' }
-- t is for 'Terminal'
nmap_leader('tT', '<Cmd>horizontal term<CR>', 'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>',   'Terminal (vertical)')

add_group  { mode = 'n', keys = '<Leader>v', desc = 'Visits...' }
nmap_leader('u', "<Cmd>lua require('undotree').open()<CR>", 'Undotree')
-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
-- - `<Leader>vc` - pick among all files with "core" label.
local make_pick_core = function(cwd, desc)
  return function()
        local MiniVisits = require("mini.visits")
        local MiniExtra = require("mini.extra")
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
