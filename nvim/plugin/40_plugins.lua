-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- This file contains installation and configuration of plugins outside of MINI.
-- They significantly improve user experience in a way not yet possible with MINI.
-- These are mostly plugins that provide programming language specific behavior.
--
-- Use this file to install and configure other such plugins.

-- Make concise helpers for installing/adding plugins in two stages
local gh = function(x) return 'https://github.com/' .. x end
local add = function(spec, args)
  if type(spec) == 'string' then
    vim.pack.add({ spec }, args)
  else
    vim.pack.add(spec, args)
  end
end
local dbg = function(s) vim.notify(s, vim.log.levels.INFO, { title = 'IGNACIO' }) end

vim.cmd.packadd('nvim.undotree')
-- Tree-sitter ================================================================

-- Tree-sitter is a tool for fast incremental parsing. It converts text into
-- a hierarchical structure (called tree) that can be used to implement advanced
-- and/or more precise actions: syntax highlighting, textobjects, indent, etc.
--
-- Tree-sitter support is built into Neovim (see `:h treesitter`). However, it
-- requires two extra pieces that don't come with Neovim directly:
-- - Language parsers: programs that convert text into trees. Some are built-in
--   (like for Lua), 'nvim-treesitter' provides many others.
-- - Query files: definitions of how to extract information from trees in
--   a useful manner (see `:h treesitter-query`). 'nvim-treesitter' also provides
--   these, while 'nvim-treesitter-textobjects' provides the ones for Neovim
--   textobjects (see `:h text-objects`, `:h MiniAi.gen_spec.treesitter()`).
--
-- Add these plugins now if file (and not 'mini.starter') is shown after startup.
add({
  gh('arborist-ts/arborist.nvim'),
})
require('arborist').setup({
  overrides = {
    c_sharp = { url = gh('tree-sitter/tree-sitter-c-sharp') },
  },
})
add({
  gh('nvim-treesitter/nvim-treesitter-textobjects'),
})
require('nvim-treesitter-textobjects').setup({
  select = {
    -- Automatically jump forward to textobj, similar to targets.vim
    lookahead = true,
    -- You can choose the select mode (default is charwise 'v')
    --
    -- Can also be a function which gets passed a table with the keys
    -- * query_string: eg '@function.inner'
    -- * method: eg 'v' or 'o'
    -- and should return the mode ('v', 'V', or '<c-v>') or a table
    -- mapping query_strings to modes.
    selection_modes = {
      ['@parameter.outer'] = 'v', -- charwise
      ['@function.outer'] = 'V', -- linewise
      --   ['@class.outer'] = '<c-v>', -- blockwise
    },
    -- If you set this to `true` (default is `false`) then any textobject is
    -- extended to include preceding or succeeding whitespace. Succeeding
    -- whitespace has priority in order to act similarly to eg the built-in
    -- `ap`.
    --
    -- Can also be a function which gets passed a table with the keys
    -- * query_string: eg '@function.inner'
    -- * selection_mode: eg 'v'
    -- and should return true of false
    include_surrounding_whitespace = false,
  },
})

add({
  gh('nvim-mini/mini.icons'),
  gh('ibhagwan/fzf-lua'),
})
local fzf_lua = require('fzf-lua')
fzf_lua.setup({
  defaults = {
    formatter = 'path.filename_first',
  },
  fzf_opts = {
    ['--tiebreak'] = 'begin,length,index',
  },
  files = {
    fzf_opts = {
      -- `path.filename_first` lays each entry out as `<icon>U+2002<filename><Tab><dir>`.
      -- Split on both the U+2002 (fzf-lua's field separator, bytes \226\128\130) and the
      -- Tab so the filename is field 2; `--nth=2` then restricts the fuzzy search to the
      -- filename only, and `--tiebreak=chunk` makes the shorter filename win on ties.
      ['--delimiter'] = '[\t\226\128\130]',
      ['--nth'] = '2',
      ['--tiebreak'] = 'chunk',
    },
  },
})
fzf_lua.register_ui_select()

-- Register mini.visits extension
fzf_lua.register_extension(
  'visit_paths', -- name
  function()
    local path = require('fzf-lua.path')
    local cwd = vim.fn.getcwd()
    local paths = require('mini.visits').list_paths()
    -- Convert absolute paths to relative paths
    local relative_paths = {}
    for _, p in ipairs(paths) do
      table.insert(relative_paths, path.relative_to(p, cwd))
    end
    return fzf_lua.fzf_exec(relative_paths, {
      prompt = 'Visit Paths> ',
      cwd = cwd,
      cwd_prompt = true, -- Enable cwd in prompt
      cwd_prompt_shorten_len = 32, -- Shorten if longer than 32 chars
      cwd_prompt_shorten_val = 1, -- Length of shortened parts
      previewer = 'builtin',
      actions = {
        ['default'] = fzf_lua.actions.file_edit,
        ['ctrl-s'] = fzf_lua.actions.file_split,
        ['ctrl-v'] = fzf_lua.actions.file_vsplit,
      },
    })
  end, -- function
  { prompt = 'Visit> ' }, -- default options (optional)
  false -- override existing (optional)
)

-- Testing
add({
  gh('nvim-neotest/nvim-nio'),
  gh('nvim-lua/plenary.nvim'),
  -- treesitter_package,
  -- gh("marilari88/neotest-vitest"),
  gh('nvim-neotest/neotest'),
})

-- Formatting =================================================================

-- Programs dedicated to text formatting (a.k.a. formatters) are very useful.
-- Neovim has built-in tools for text formatting (see `:h gq` and `:h 'formatprg'`).
-- They can be used to configure external programs, but it might become tedious.
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup.
add(gh('stevearc/conform.nvim'))

-- See also:
-- - `:h Conform`
-- - `:h conform-options`
-- - `:h conform-formatters`
vim.g.autoformat = true
require('conform').setup({
  formatters_by_ft = {
    -- cs = { 'csharpier' },
    css = { 'prettier' },
    html = { 'prettier' },
    http = { 'kulala-fmt' },
    javascript = { 'prettier' },
    json = { 'prettier' },
    lua = { 'stylua' },
    markdown = { 'prettier' },
    scss = { 'prettier' },
    sh = { 'shfmt' },
    templ = { 'templ' },
    toml = { 'taplo' },
    typescript = { 'prettier' },
    yaml = { 'prettier' },
  },

  format_after_save = function(bufnr)
    if not vim.g.autoformat then
      return
    else
      if vim.bo.filetype == 'ps1' then
        vim.lsp.buf.format()
        return
      end
      -- Disable autoformat for files in a certain path
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname:match('/node_modules/') then return end
      return { lsp_format = 'fallback' }
    end
  end,

  formatters = {
    goimports_reviser = {
      command = 'goimports-reviser',
      args = { '-output', 'stdout', '$FILENAME' },
    },
  },
})

-- Snippets ===================================================================

-- Although 'mini.snippets' provides functionality to manage snippet files, it
-- deliberately doesn't come with those.
--
-- The 'rafamadriz/friendly-snippets' is currently the largest collection of
-- snippet files. They are organized in 'snippets/' directory (mostly) per language.
-- 'mini.snippets' is designed to work with it as seamlessly as possible.
-- See `:h MiniSnippets.gen_loader.from_lang()`.
add(gh('rafamadriz/friendly-snippets'))

-- Honorable mentions =========================================================

-- 'mason-org/mason.nvim' (a.k.a. "Mason") is a great tool (package manager) for
-- installing external language servers, formatters, and linters. It provides
-- a unified interface for installing, updating, and deleting such programs.
--
-- The caveat is that these programs will be set up to be mostly used inside Neovim.
-- If you need them to work elsewhere, consider using other package managers.
--
-- You can use it like so:
add(gh('mason-org/mason.nvim'))
require('mason').setup({
  ui = {
    border = 'rounded',
    width = 0.8,
    height = 0.8,
  },
  registries = {
    'github:mason-org/mason-registry',
    'github:crashdummyy/mason-registry',
  },
})

local mason_packages = {
  -- "bicep-lsp",
  'csharpier',
  'docker-compose-language-service',
  'dockerfile-language-server',
  'html-lsp',
  'jq',
  'json-lsp',
  'lua-language-server',
  'markdownlint-cli2',
  'netcoredbg',
  'ols',
  'powershell-editor-services',
  'prettier',
  'pyright',
  'shfmt',
  'stylua',
  'tailwindcss-language-server',
  'taplo',
  'templ',
  'terraform-ls',
  'typescript-language-server',
  'yaml-language-server',
}

local mr = require('mason-registry')
local function ensure_installed()
  for _, tool in ipairs(mason_packages) do
    local p = mr.get_package(tool)
    if not p:is_installed() then p:install() end
  end
end
if mr.refresh then
  mr.refresh(ensure_installed)
else
  ensure_installed()
end

-- LSPS ========================================================
local function setup_lsp(name, config)
  if config then
    vim.lsp.config(name, config)
  else
    vim.lsp.config(name, {})
  end
  vim.lsp.enable(name)
end

vim.filetype.add({
  extension = {
    razor = 'razor',
    cshtml = 'razor',
  },
})
add({
  gh('mason-org/mason.nvim'),
  gh('neovim/nvim-lspconfig'),
})
local mason_dir = require('mason.settings').current.install_root_dir

setup_lsp('fsautocomplete')
-- local orig_show_message = vim.lsp.handlers['window/showMessage']
-- vim.lsp.handlers['window/showMessage'] = function(err, result, ctx, config)
--   local client = vim.lsp.get_client_by_id(ctx.client_id)
--   if client and client.name == 'fsautocomplete' then
--     -- drop Info (3) and Log (4); keep Error (1) and Warning (2)
--     if
--       result
--       and result.type
--       and result.type > vim.lsp.protocol.MessageType.Warning
--     then
--       return
--     end
--   end
--   return orig_show_message(err, result, ctx, config)
-- end
setup_lsp('hls', {
  filetypes = { 'haskell', 'lhaskell', 'cabal' },
  settings = {
    haskell = {
      cabalFormattingProvider = 'cabal-gild',
    },
  },
})
setup_lsp('html')
setup_lsp('jsonls')
setup_lsp('kulala_ls')
setup_lsp('lua_ls', {
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if
        path ~= vim.fn.stdpath('config')
        and (
          vim.uv.fs_stat(path .. '/.luarc.json')
          or vim.uv.fs_stat(path .. '/.luarc.jsonc')
        )
      then
        return
      end
    end

    client.config.settings.Lua =
      vim.tbl_deep_extend('force', client.config.settings.Lua, {
        runtime = {
          -- Tell the language server which version of Lua you're using (most
          -- likely LuaJIT in the case of Neovim)
          version = 'LuaJIT',
          -- Tell the language server how to find Lua modules same way as Neovim
          -- (see `:h lua-module-load`)
          path = {
            'lua/?.lua',
            'lua/?/init.lua',
          },
        },
        -- Make the server aware of Neovim runtime files
        workspace = {
          checkThirdParty = false,
          library = {
            vim.env.VIMRUNTIME,
            -- Depending on the usage, you might want to add additional paths
            -- here.
            -- '${3rd}/luv/library',
            -- '${3rd}/busted/library',
          },
          -- Or pull in all of 'runtimepath'.
          -- NOTE: this is a lot slower and will cause issues when working on
          -- your own configuration.
          -- See https://github.com/neovim/nvim-lspconfig/issues/3189
          -- library = vim.api.nvim_get_runtime_file('', true),
        },
      })
  end,
  settings = {
    Lua = {},
  },
})
setup_lsp('powershell_es', {
  bundle_path = mason_dir .. '/packages/powershell-editor-services',
  -- PSES >= 2.x (PR #1801) requires `enableProfileLoading` in
  -- `initializationOptions`, otherwise it never responds to `initialize`
  -- on stdio clients and the LSP stays uninitialized forever.
  init_options = { enableProfileLoading = false },
  -- PSES requests the `powershell.rename` config section over
  -- `workspace/configuration` and otherwise prompts a "disclaimer" dialog
  -- once per session before enabling rename. Pre-accept it here.
  settings = {
    powershell = {
      rename = { acceptDisclaimer = true },
    },
  },
})
setup_lsp('tailwindcss')
setup_lsp('taplo')
setup_lsp('ts_ls')
setup_lsp('yamlls')

-- Debugging
add({
  gh('nvim-lua/plenary.nvim'),
  gh('GustavEikaas/easy-dotnet.nvim'),
  gh('mfussenegger/nvim-dap'),
})

local dotnet = require('easy-dotnet')
-- Options are not required
dotnet.setup({
  test_runner = {
    icons = {
      passed = '',
      skipped = '',
      failed = '',
      success = '',
      reload = '',
      test = '',
      sln = '󰘐',
      project = '󰘐',
      dir = '',
      package = '',
    },
    mappings = {
      run_test_from_buffer = { lhs = '<leader>ntb', desc = 'run test from buffer' },
      run_test_all_tests_from_buffer = {
        lhs = '<leader>nta',
        desc = 'run all tests from buffer',
      },
      get_build_errors = { lhs = '<leader>nbe', desc = 'get build errors' },
      peek_stack_trace_from_buffer = {
        lhs = '<leader>np',
        desc = 'peek stack trace from buffer',
      },
      debug_test = { lhs = '<leader>nd', desc = 'debug test' },
      debug_test_from_buffer = {
        lhs = '<leader>nb',
        desc = 'debug test from buffer',
      },
      go_to_file = { lhs = '<leader>ng', desc = 'go to file' },
      run_all = { lhs = '<leader>nR', desc = 'run all tests' },
      run = { lhs = '<leader>nr', desc = 'run test' },
      peek_stacktrace = {
        lhs = '<leader>np',
        desc = 'peek stacktrace of failed test',
      },
      expand = { lhs = 'o', desc = 'expand' },
      expand_node = { lhs = 'E', desc = 'expand node' },
      expand_all = { lhs = '-', desc = 'expand all' },
      collapse_all = { lhs = 'W', desc = 'collapse all' },
      close = { lhs = 'q', desc = 'close testrunner' },
      refresh_testrunner = { lhs = '<C-r>', desc = 'refresh testrunner' },
    },
  },
  server = {
    ---@type nil | "Off" | "Critical" | "Error" | "Warning" | "Information" | "Verbose" | "All"
    log_level = 'Information',
  },
  picker = 'fzf',
  notifications = {
    --Set this to false if you have configured lualine to avoid double logging
    handler = false,
  },
})

add({
  gh('mfussenegger/nvim-dap'),
  -- gh('nvim-neotest/nvim-nio'),
  gh('rcarriga/nvim-dap-ui'),
})
local dapui = require('dapui')
local dap = require('dap')

--- open ui immediately when debugging starts
dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end
-- https://emojipedia.org/en/stickers/search?q=circle
vim.fn.sign_define('DapBreakpoint', {
  text = '⚪',
  texthl = 'DapBreakpointSymbol',
  linehl = 'DapBreakpoint',
  numhl = 'DapBreakpoint',
})
vim.fn.sign_define('DapStopped', {
  text = '➡️',
  texthl = 'yellow',
  linehl = 'DapBreakpoint',
  numhl = 'DapBreakpoint',
})
vim.fn.sign_define('DapBreakpointRejected', {
  text = '⭕',
  texthl = 'DapStoppedSymbol',
  linehl = 'DapBreakpoint',
  numhl = 'DapBreakpoint',
})
-- default configuration
dapui.setup({
  layouts = {
    {
      elements = {
        { id = 'easy-dotnet_cpu', size = 0.5 }, -- CPU usage panel (50% of layout)
        { id = 'easy-dotnet_mem', size = 0.5 }, -- Memory usage panel (50% of layout)
      },
      size = 35, -- Width of the sidebar
      position = 'right',
    },
  },
})

-- REST client
add(gh('mistweaverco/kulala.nvim'))
require('kulala').setup({
  global_keymaps = true,
  global_keymaps_prefix = '<leader>R',
  kulala_keymaps_prefix = '',
  additional_curl_options = { '-k' },
  default_env = '',
})
-- { "<leader>Rs", desc = "Send request" },
-- { "<leader>Ra", desc = "Send all requests" },
-- { "<leader>Rb", desc = "Open scratchpad" },
-- vim.treesitter.language.register('kulala_http', 'http')

-- vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
--   pattern = { '*.http', '*.rest' }, -- Add specific file types here
--   once = true,
--   callback = function()
--     add(gh('mistweaverco/kulala.nvim')
--     require('kulala').setup({
--       global_keymaps = true,
--       global_keymaps_prefix = '<leader>R',
--       kulala_keymaps_prefix = '',
--       additional_curl_options = { '-k' },
--       default_env = '',
--     })
--     -- { "<leader>Rs", desc = "Send request" },
--     -- { "<leader>Ra", desc = "Send all requests" },
--     -- { "<leader>Rb", desc = "Open scratchpad" },
--   end,
-- })

-- Beautiful, usable, well maintained color schemes outside of 'mini.nvim' and
-- have full support of its highlight groups. Use if you don't like 'miniwinter'
-- enabled in 'plugin/30_mini.lua' or other suggested 'mini.hues' based ones.
-- Install only those that you need
add({
  gh('folke/tokyonight.nvim'),
  -- gh('sainnhe/everforest'),
  -- gh('Shatur/neovim-ayu'),
  -- gh('catppuccin/nvim'),
  -- gh('ellisonleao/gruvbox.nvim'),
  -- gh('rose-pine/neovim'),
})
-- require('ayu').setup({
--   overrides = {
--     -- To see the available highlight groups, run :source $VIMRUNTIME/syntax/hitest.vim
--     -- Search = { bg = "#ff00ff"}
--   },
-- })

-- Enable only one
vim.cmd('color tokyonight')
-- Statusline
add({
  gh('nvim-tree/nvim-web-devicons'),
  gh('smiteshp/nvim-navic'),
  gh('yavorski/lualine-macro-recording.nvim'),
  gh('dokwork/lualine-ex'),
  { src = gh('icalvo/lualine-lsp-progress'), version = 'modernize-fork' },
  gh('nvim-lualine/lualine.nvim'),
})
require('lualine').setup({
  options = {
    icons_enabled = true,
    theme = 'auto',
    component_separators = { left = '', right = '' },
    section_separators = { left = '', right = '' },
    disabled_filetypes = {
      statusline = { 'nvim-undotree' },
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    always_show_tabline = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
      refresh_time = 16, -- ~60fps
      events = {
        'WinEnter',
        'BufEnter',
        'BufWritePost',
        'SessionLoadPost',
        'FileChangedShellPost',
        'VimResized',
        'Filetype',
        'CursorMoved',
        'CursorMovedI',
        'ModeChanged',
        'DiagnosticChanged',
      },
    },
  },
  sections = {
    lualine_a = {
      {
        'mode',
        fmt = function(str) return str:sub(1, 1) end,
      },
      function()
        if vim.o.autowriteall then
          return 'AWA'
        elseif vim.o.autowrite then
          return 'AW'
        else
          return ''
        end
      end,
    },
    lualine_b = {
      {
        "require'salesforce.org_manager':get_default_alias()",
        icon = '󰢎',
      },
      {
        "require'easy-dotnet'.lualine.jobs()",
      },
      'branch',
      'diff',
      {
        'diagnostics',
      },
      {
        "require'kulala':get_selected_env()",
        color = { fg = '#ffcc00' },
      },
    },
    lualine_c = {
      { 'filename', color = { fg = '#ffffff' }, path = 1 },
      { 'navic', color_correction = 'dynamic' },
    },
    lualine_x = {},
    lualine_y = {
      {
        'ex.lsp.single',

        icons = {
          -- Default icon for any unknow server:
          unknown = '?',

          -- Default icon for a case, when no one server is run:
          lsp_is_off = '󰚦',

          -- Example of the icon for a client, which doesn't have an icon in `nvim-web-devicons`:
          ['null-ls'] = { 'N', color = 'magenta' },
        },

        { 'macro_recording', '%S' },
        {
          'encoding',
          fmt = function(str)
            if str == 'utf-8' then
              return ''
            else
              return str
            end
          end,
        },
      },
      'fileformat',
      'filetype',
    },
    lualine_z = {
      'searchcount',
      'location',
    },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { 'filename' },
    lualine_x = { 'location' },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {},
  winbar = {
    lualine_a = {
      -- 'lsp_status'
    },
    lualine_b = { 'lsp_progress' },
    lualine_c = {},
    lualine_x = {},
    lualine_y = { "require'easy-dotnet'.lualine.run_status()" },
    lualine_z = { 'lsp_status' },
  },
  inactive_winbar = {},
  extensions = {},
})

add({
  gh('nvim-lua/plenary.nvim'),
  -- treesitter_package,
  gh('ThePrimeagen/refactoring.nvim'),
})
add({
  gh('nvim-lua/plenary.nvim'),
  gh('kdheepak/lazygit.nvim'),
})
add(gh('xTacobaco/cursor-agent.nvim'))
add(gh('folke/zen-mode.nvim'))
require('zen-mode').setup({
  window = {
    backdrop = 0.95, -- shade the backdrop of the Zen window. Set to 1 to keep the same as Normal
    -- height and width can be:
    -- * an absolute number of cells when > 1
    -- * a percentage of the width / height of the editor when <= 1
    -- * a function that returns the width or the height
    width = 120, -- width of the Zen window
    height = 1, -- height of the Zen window
    -- by default, no options are changed for the Zen window
    -- uncomment any of the options below, or add other vim.wo options you want to apply
    options = {
      -- signcolumn = "no", -- disable signcolumn
      -- number = false, -- disable number column
      -- relativenumber = false, -- disable relative numbers
      -- cursorline = false, -- disable cursorline
      -- cursorcolumn = false, -- disable cursor column
      -- foldcolumn = "0", -- disable fold column
      -- list = false, -- disable whitespace characters
    },
  },
  plugins = {
    -- disable some global vim options (vim.o...)
    -- comment the lines to not apply the options
    options = {
      enabled = true,
      ruler = false, -- disables the ruler text in the cmd line area
      showcmd = false, -- disables the command in the last line of the screen
      -- you may turn on/off statusline in zen mode by setting 'laststatus'
      -- statusline will be shown only if 'laststatus' == 3
      laststatus = 0, -- turn off the statusline in zen mode
    },
    twilight = { enabled = false }, -- enable to start Twilight when zen mode opens
    gitsigns = { enabled = false }, -- disables git signs
    tmux = { enabled = false }, -- disables the tmux statusline
    todo = { enabled = false }, -- if set to "true", todo-comments.nvim highlights will be disabled
    -- this will change the font size on kitty when in zen mode
    -- to make this work, you need to set the following kitty options:
    -- - allow_remote_control socket-only
    -- - listen_on unix:/tmp/kitty
    kitty = {
      enabled = false,
      font = '+4', -- font size increment
    },
    -- this will change the font size on alacritty when in zen mode
    -- requires  Alacritty Version 0.10.0 or higher
    -- uses `alacritty msg` subcommand to change font size
    alacritty = {
      enabled = false,
      font = '14', -- font size
    },
    -- this will change the font size on wezterm when in zen mode
    -- See alse also the Plugins/Wezterm section in this projects README
    wezterm = {
      enabled = false,
      -- can be either an absolute font size or the number of incremental steps
      font = '+4', -- (10% increase per step)
    },
    -- this will change the scale factor in Neovide when in zen mode
    -- See alse also the Plugins/Wezterm section in this projects README
    neovide = {
      enabled = false,
      -- Will multiply the current scale factor by this number
      scale = 1.2,
      -- disable the Neovide animations while in Zen mode
      disable_animations = {
        neovide_animation_length = 0,
        neovide_cursor_animate_command_line = false,
        neovide_scroll_animation_length = 0,
        neovide_position_animation_length = 0,
        neovide_cursor_animation_length = 0,
        neovide_cursor_vfx_mode = '',
      },
    },
  },
})
vim.g.cursor_agent_mapped = true
-- Run the current file and show its output in a dedicated vsplit buffer.
-- After `:Run`, saving the same file re-runs it and refreshes the output.
local run_interpreters = {
  python = 'python',
  javascript = 'node',
  ruby = 'ruby',
  haskell = 'runghc',
}

local run_output_buf = nil
local run_job = nil
local run_id = 0
local run_group = vim.api.nvim_create_augroup('custom-run-on-save', { clear = true })

-- Ensure the dedicated output buffer exists and is shown in a vsplit.
local function run_ensure_output_window()
  if not (run_output_buf and vim.api.nvim_buf_is_valid(run_output_buf)) then
    run_output_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[run_output_buf].buftype = 'nofile'
    vim.bo[run_output_buf].bufhidden = 'hide'
    vim.bo[run_output_buf].swapfile = false
    vim.api.nvim_buf_set_name(run_output_buf, '[Run Output]')
  end

  if vim.fn.bufwinid(run_output_buf) == -1 then
    local src_win = vim.api.nvim_get_current_win()
    vim.cmd('vsplit')
    vim.api.nvim_win_set_buf(0, run_output_buf)
    vim.api.nvim_set_current_win(src_win)
  end

  return run_output_buf
end

local function run_set_output(lines)
  local buf = run_ensure_output_window()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

-- Run the current buffer's file and replace the output buffer's content.
local function run_execute()
  local interpreter = run_interpreters[vim.bo.filetype]
  if not interpreter then
    vim.notify('Run: file type not supported', vim.log.levels.WARN)
    return
  end

  local file = vim.fn.expand('%:p')
  if file == '' then return end

  run_id = run_id + 1
  local this_run = run_id

  if run_job then
    pcall(function() run_job:kill('sigterm') end)
    run_job = nil
  end

  run_set_output({ 'Running...' })

  run_job = vim.system(
    { interpreter, file },
    { text = true, cwd = vim.fn.fnamemodify(file, ':h') },
    function(obj)
      -- The callback runs in a fast event context, where most API calls
      -- (including buffer manipulation) are disallowed. Defer with schedule.
      vim.schedule(function()
        if this_run ~= run_id then return end
        run_job = nil

        local lines = {}
        if obj.stdout and obj.stdout ~= '' then
          vim.list_extend(lines, vim.split(obj.stdout, '\n', { trimempty = false }))
        end
        if obj.stderr and obj.stderr ~= '' then
          if #lines > 0 then table.insert(lines, '') end
          vim.list_extend(lines, vim.split(obj.stderr, '\n', { trimempty = false }))
        end
        if #lines == 0 then lines = { '(no output)' } end
        if obj.code ~= 0 then
          table.insert(lines, '')
          table.insert(lines, string.format('Process exited with code %d', obj.code))
        end

        run_set_output(lines)
      end)
    end
  )
end

vim.api.nvim_create_user_command('Run', function()
  if not run_interpreters[vim.bo.filetype] then
    vim.notify('Run: file type not supported', vim.log.levels.WARN)
    return
  end

  local src_buf = vim.api.nvim_get_current_buf()

  -- Re-run on every save of this file. `run_execute` never writes, so this
  -- does not recurse. Register before writing so the initial `:Run` and later
  -- saves share the single `BufWritePost` -> `run_execute` path.
  vim.api.nvim_clear_autocmds({ group = run_group })
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = run_group,
    buffer = src_buf,
    callback = run_execute,
    desc = 'Re-run file on save (:Run)',
  })

  vim.cmd('silent write')
end, {})

-- Shortcut to trigger file run
vim.api.nvim_set_keymap('n', '<Leader>r', ':Run<CR>', { silent = true })
