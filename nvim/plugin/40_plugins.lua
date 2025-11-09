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
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later
local now_if_args = _G.Config.now_if_args
local dbg = function(s) vim.notify(s, vim.log.levels.INFO, { title = 'IGNACIO' }) end
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
now(function()
  add({
    source = 'nvim-treesitter/nvim-treesitter',
    -- Use `main` branch since `master` branch is frozen, yet still default
    checkout = 'main',
    -- Update tree-sitter parser after plugin is updated
    hooks = { post_checkout = function() vim.cmd('TSUpdate') end },
  })
  add({
    source = 'nvim-treesitter/nvim-treesitter-textobjects',
    -- Same logic as for 'nvim-treesitter'
    checkout = 'main',
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
      -- selection_modes = {
      --   ['@parameter.outer'] = 'v', -- charwise
      --   ['@function.outer'] = 'V', -- linewise
      --   ['@class.outer'] = '<c-v>', -- blockwise
      -- },
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
end)

later(
  function()
    add({
      source = 'ibhagwan/fzf-lua',
      depends = { 'nvim-mini/mini.icons' },
    })
  end
)

-- Testing
later(function()
  add({
    source = 'nvim-neotest/neotest',
    depends = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      -- "marilari88/neotest-vitest",
    },
  })
end)

-- Formatting =================================================================

-- Programs dedicated to text formatting (a.k.a. formatters) are very useful.
-- Neovim has built-in tools for text formatting (see `:h gq` and `:h 'formatprg'`).
-- They can be used to configure external programs, but it might become tedious.
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup.
later(function()
  add('stevearc/conform.nvim')

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
end)

-- Snippets ===================================================================

-- Although 'mini.snippets' provides functionality to manage snippet files, it
-- deliberately doesn't come with those.
--
-- The 'rafamadriz/friendly-snippets' is currently the largest collection of
-- snippet files. They are organized in 'snippets/' directory (mostly) per language.
-- 'mini.snippets' is designed to work with it as seamlessly as possible.
-- See `:h MiniSnippets.gen_loader.from_lang()`.
later(function() add('rafamadriz/friendly-snippets') end)

-- Honorable mentions =========================================================

-- 'mason-org/mason.nvim' (a.k.a. "Mason") is a great tool (package manager) for
-- installing external language servers, formatters, and linters. It provides
-- a unified interface for installing, updating, and deleting such programs.
--
-- The caveat is that these programs will be set up to be mostly used inside Neovim.
-- If you need them to work elsewhere, consider using other package managers.
--
-- You can use it like so:
later(function()
  add('mason-org/mason.nvim')
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
    'roslyn',
    'rzls',
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
end)

-- LSPS ========================================================
later(function()
  vim.filetype.add({
    extension = {
      razor = 'razor',
      cshtml = 'razor',
    },
  })
  add({
    source = 'seblyng/roslyn.nvim',
    depends = { 'tris203/rzls.nvim' },
  })
  require('rzls').setup({})
  require('roslyn').setup({})

  local lsps = {
    { 'html' },
    { 'jsonls' },
    { 'lua_ls' },
    { 'powershell_es' },
    { 'tailwindcss' },
    { 'taplo' }, -- toml
    { 'ts_ls' },
    { 'yamlls' },
    { 'roslyn_ls' },
  }

  for _, lsp in pairs(lsps) do
    local name, config = lsp[1], lsp[2]
    if config then vim.lsp.config(name, config) end
    vim.lsp.enable(name)
  end
end)

-- Debugging
later(function()
  add({
    source = 'mfussenegger/nvim-dap',
    depends = {
      {
        source = 'GustavEikaas/easy-dotnet.nvim',
        depends = {
          'nvim-lua/plenary.nvim',
        },
      },
    },
  })

  local function get_secret_path(secret_guid)
    local path = ''
    local home_dir = vim.fn.expand('~')
    if require('easy-dotnet.extensions').isWindows() then
      local secret_path = home_dir
        .. '\\AppData\\Roaming\\Microsoft\\UserSecrets\\'
        .. secret_guid
        .. '\\secrets.json'
      path = secret_path
    else
      local secret_path = home_dir
        .. '/.microsoft/usersecrets/'
        .. secret_guid
        .. '/secrets.json'
      path = secret_path
    end
    return path
  end

  local dotnet = require('easy-dotnet')
  -- Options are not required
  dotnet.setup({
    lsp = {
      enabled = false,
    },
    debugger = {
      -- The path to netcoredbg executable
      bin_path = 'C:\\Users\\ignacio.calvo\\AppData\\Local\\nvim-data\\mason\\bin\\netcoredbg.cmd',
      -- bin_path = vim.fn.expand("$MASON/packages/netcoredbg/netcoredbg/"),
      auto_register_dap = true,
      mappings = {
        open_variable_viewer = { lhs = 'T', desc = 'open variable viewer' },
      },
    },
    ---@type TestRunnerOptions
    test_runner = {
      ---@type "split" | "vsplit" | "float" | "buf"
      viewmode = 'float',
      ---@type number|nil
      vsplit_width = nil,
      ---@type string|nil "topleft" | "topright"
      vsplit_pos = nil,
      enable_buffer_test_execution = true, --Experimental, run tests directly from buffer
      noBuild = true,
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
        run_test_from_buffer = { lhs = '<leader>nr', desc = 'run test from buffer' },
        peek_stack_trace_from_buffer = {
          lhs = '<leader>np',
          desc = 'peek stack trace from buffer',
        },
        filter_failed_tests = { lhs = '<leader>nfe', desc = 'filter failed tests' },
        debug_test = { lhs = '<leader>nd', desc = 'debug test' },
        debug_test_from_buffer = {
          lhs = '<leader>nb',
          desc = 'debug test from buffer',
        },
        go_to_file = { lhs = 'g', desc = 'go to file' },
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
      --- Optional table of extra args e.g "--blame crash"
      additional_args = {},
    },
    new = {
      project = {
        prefix = 'sln', -- "sln" | "none"
      },
    },
    ---@param action "test" | "restore" | "build" | "run"
    terminal = function(path, action, args)
      args = args or ''
      local commands = {
        run = function()
          return string.format('dotnet run --project %s %s', path, args)
        end,
        test = function() return string.format('dotnet test %s %s', path, args) end,
        restore = function()
          return string.format('dotnet restore %s %s', path, args)
        end,
        build = function() return string.format('dotnet build %s %s', path, args) end,
        watch = function()
          return string.format('dotnet watch --project %s %s', path, args)
        end,
      }
      local command = commands[action]()
      if require('easy-dotnet.extensions').isWindows() == true then
        command = command .. '\r'
      end
      vim.cmd('vsplit')
      vim.cmd('term ' .. command)
    end,
    secrets = {
      path = get_secret_path,
    },
    csproj_mappings = true,
    fsproj_mappings = true,
    auto_bootstrap_namespace = {
      --block_scoped, file_scoped
      type = 'block_scoped',
      enabled = true,
      use_clipboard_json = {
        behavior = 'prompt', --'auto' | 'prompt' | 'never',
        register = '+', -- which register to check
      },
    },
    server = {
      ---@type nil | "Off" | "Critical" | "Error" | "Warning" | "Information" | "Verbose" | "All"
      log_level = 'Information',
    },
    -- choose which picker to use with the plugin
    -- possible values are "telescope" | "fzf" | "snacks" | "basic"
    -- if no picker is specified, the plugin will determine
    -- the available one automatically with this priority:
    -- telescope -> fzf -> snacks ->  basic
    picker = 'fzf',
    background_scanning = true,
    notifications = {
      --Set this to false if you have configured lualine to avoid double logging
      handler = false,
    },
    diagnostics = {
      default_severity = 'error',
      setqflist = false,
    },
  })

  vim.api.nvim_create_user_command('Secrets', function() dotnet.secrets() end, {})

  require('easy-dotnet.netcoredbg').register_dap_variables_viewer()
end)

later(function()
  add({ source = 'rcarriga/nvim-dap-ui', depends = { 'mfussenegger/nvim-dap' } })

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
    text = '🔴',
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
  dapui.setup()
end)

-- REST client
now(function()
  add('mistweaverco/kulala.nvim')
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
end)
-- vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
--   pattern = { '*.http', '*.rest' }, -- Add specific file types here
--   once = true,
--   callback = function()
--     add('mistweaverco/kulala.nvim')
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
now(function()
  -- Install only those that you need
  add('sainnhe/everforest')
  add('Shatur/neovim-ayu')
  add('ellisonleao/gruvbox.nvim')

  -- Enable only one
  vim.cmd('color ayu-mirage')
end)

-- Statusline
now(function()
  add({
    source = 'nvim-lualine/lualine.nvim',
    depends = {
      'nvim-tree/nvim-web-devicons',
      'smiteshp/nvim-navic',
      'yavorski/lualine-macro-recording.nvim',
    },
  })
  require('lualine').setup({
    options = {
      icons_enabled = true,
      theme = 'auto',
      component_separators = { left = '', right = '' },
      section_separators = { left = '', right = '' },
      disabled_filetypes = {
        statusline = {},
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
        },
      },
    },
    sections = {
      lualine_a = {
        {
          'mode',
          fmt = function(str) return str:sub(1, 1) end,
        },
      },
      lualine_b = {
        {
          "require'salesforce.org_manager':get_default_alias()",
          icon = '󰢎',
        },
        {
          "require'easy-dotnet.ui-modules.jobs':lualine()",
        },
        'branch',
        'diff',
        'diagnostics',
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
        -- {
        --   require('noice').api.status.search.get,
        --   cond = require('noice').api.status.search.has,
        --   color = { fg = '#ff9eff' },
        -- },
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
        'fileformat',
        'filetype',
      },
      lualine_z = { 'location' },
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
    winbar = {},
    inactive_winbar = {},
    extensions = {},
  })
end)

later(
  function()
    add({
      source = 'ThePrimeagen/refactoring.nvim',
      depends = {
        'nvim-lua/plenary.nvim',
        'nvim-treesitter/nvim-treesitter',
      },
    })
  end
)
later(
  function()
    add({
      source = 'kdheepak/lazygit.nvim',
      depends = {
        'nvim-lua/plenary.nvim',
      },
    })
  end
)
