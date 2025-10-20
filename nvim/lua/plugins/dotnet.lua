return {
    {
        "seblyng/roslyn.nvim",
        lazy = false,
        init = function()
            -- We add the Razor file types before the plugin loads.
            vim.filetype.add({
                extension = {
                    razor = "razor",
                    cshtml = "razor",
                },
            })
        end,
        dependencies = {
            {
                -- By loading as a dependencies, we ensure that we are available to set
                -- the handlers for Roslyn.
                "tris203/rzls.nvim",
                config = true,
            },
        },
        config = function()
            -- Using mason
            local rzls_path = vim.fn.expand("$MASON/packages/rzls/libexec")
            local cmd = {
                "roslyn",
                "--stdio",
                "--logLevel=Information",
                "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.get_log_path()),
                "--razorSourceGenerator=" .. vim.fs.joinpath(rzls_path, "Microsoft.CodeAnalysis.Razor.Compiler.dll"),
                "--razorDesignTimePath="
                    .. vim.fs.joinpath(rzls_path, "Targets", "Microsoft.NET.Sdk.Razor.DesignTime.targets"),
                "--extension",
                vim.fs.joinpath(rzls_path, "RazorExtension", "Microsoft.VisualStudioCode.RazorExtension.dll"),
            }

            vim.lsp.config("roslyn", {
                cmd = cmd,
                handlers = require("rzls.roslyn_handlers"),
                settings = {
                    ["csharp|inlay_hints"] = {
                        csharp_enable_inlay_hints_for_implicit_object_creation = true,
                        csharp_enable_inlay_hints_for_implicit_variable_types = true,

                        csharp_enable_inlay_hints_for_lambda_parameter_types = true,
                        csharp_enable_inlay_hints_for_types = true,
                        dotnet_enable_inlay_hints_for_indexer_parameters = true,
                        dotnet_enable_inlay_hints_for_literal_parameters = true,
                        dotnet_enable_inlay_hints_for_object_creation_parameters = true,
                        dotnet_enable_inlay_hints_for_other_parameters = true,
                        dotnet_enable_inlay_hints_for_parameters = true,
                        dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
                        dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
                        dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
                    },
                    ["csharp|code_lens"] = {
                        dotnet_enable_references_code_lens = true,
                    },
                },
            })
            vim.lsp.enable("roslyn")
        end,
    },
    {
        "GustavEikaas/easy-dotnet.nvim",
        enabled = false,
        dependencies = {
            "nvim-lua/plenary.nvim",
            "folke/snacks.nvim",
        },
        config = function()
            local function get_secret_path(secret_guid)
                local path = ""
                local home_dir = vim.fn.expand("~")
                if require("easy-dotnet.extensions").isWindows() then
                    local secret_path = home_dir
                        .. "\\AppData\\Roaming\\Microsoft\\UserSecrets\\"
                        .. secret_guid
                        .. "\\secrets.json"
                    path = secret_path
                else
                    local secret_path = home_dir .. "/.microsoft/usersecrets/" .. secret_guid .. "/secrets.json"
                    path = secret_path
                end
                return path
            end

            local dotnet = require("easy-dotnet")
            -- Options are not required
            dotnet.setup({
                lsp = {
                    enabled = false,
                },
                debugger = {
                    -- The path to netcoredbg executable
                    bin_path = "C:\\Users\\Administrator\\AppData\\Local\\nvim-data\\mason\\bin\\",
                    -- bin_path = vim.fn.expand("$MASON/packages/netcoredbg/netcoredbg/"),
                    auto_register_dap = true,
                    mappings = {
                        open_variable_viewer = { lhs = "T", desc = "open variable viewer" },
                    },
                },
                ---@type TestRunnerOptions
                test_runner = {
                    ---@type "split" | "vsplit" | "float" | "buf"
                    viewmode = "float",
                    ---@type number|nil
                    vsplit_width = nil,
                    ---@type string|nil "topleft" | "topright"
                    vsplit_pos = nil,
                    enable_buffer_test_execution = true, --Experimental, run tests directly from buffer
                    noBuild = true,
                    icons = {
                        passed = "",
                        skipped = "",
                        failed = "",
                        success = "",
                        reload = "",
                        test = "",
                        sln = "󰘐",
                        project = "󰘐",
                        dir = "",
                        package = "",
                    },
                    mappings = {
                        run_test_from_buffer = { lhs = "<leader>nr", desc = "run test from buffer" },
                        peek_stack_trace_from_buffer = { lhs = "<leader>np", desc = "peek stack trace from buffer" },
                        filter_failed_tests = { lhs = "<leader>nfe", desc = "filter failed tests" },
                        debug_test = { lhs = "<leader>nd", desc = "debug test" },
                        debug_test_from_buffer = { lhs = "<leader>nb", desc = "debug test from buffer" },
                        go_to_file = { lhs = "g", desc = "go to file" },
                        run_all = { lhs = "<leader>nR", desc = "run all tests" },
                        run = { lhs = "<leader>nr", desc = "run test" },
                        peek_stacktrace = { lhs = "<leader>np", desc = "peek stacktrace of failed test" },
                        expand = { lhs = "o", desc = "expand" },
                        expand_node = { lhs = "E", desc = "expand node" },
                        expand_all = { lhs = "-", desc = "expand all" },
                        collapse_all = { lhs = "W", desc = "collapse all" },
                        close = { lhs = "q", desc = "close testrunner" },
                        refresh_testrunner = { lhs = "<C-r>", desc = "refresh testrunner" },
                    },
                    --- Optional table of extra args e.g "--blame crash"
                    additional_args = {},
                },
                new = {
                    project = {
                        prefix = "sln", -- "sln" | "none"
                    },
                },
                ---@param action "test" | "restore" | "build" | "run"
                terminal = function(path, action, args)
                    args = args or ""
                    local commands = {
                        run = function()
                            return string.format("dotnet run --project %s %s", path, args)
                        end,
                        test = function()
                            return string.format("dotnet test %s %s", path, args)
                        end,
                        restore = function()
                            return string.format("dotnet restore %s %s", path, args)
                        end,
                        build = function()
                            return string.format("dotnet build %s %s", path, args)
                        end,
                        watch = function()
                            return string.format("dotnet watch --project %s %s", path, args)
                        end,
                    }
                    local command = commands[action]()
                    if require("easy-dotnet.extensions").isWindows() == true then
                        command = command .. "\r"
                    end
                    vim.cmd("vsplit")
                    vim.cmd("term " .. command)
                end,
                secrets = {
                    path = get_secret_path,
                },
                csproj_mappings = true,
                fsproj_mappings = true,
                auto_bootstrap_namespace = {
                    --block_scoped, file_scoped
                    type = "block_scoped",
                    enabled = true,
                    use_clipboard_json = {
                        behavior = "prompt", --'auto' | 'prompt' | 'never',
                        register = "+", -- which register to check
                    },
                },
                server = {
                    ---@type nil | "Off" | "Critical" | "Error" | "Warning" | "Information" | "Verbose" | "All"
                    log_level = nil,
                },
                -- choose which picker to use with the plugin
                -- possible values are "telescope" | "fzf" | "snacks" | "basic"
                -- if no picker is specified, the plugin will determine
                -- the available one automatically with this priority:
                -- telescope -> fzf -> snacks ->  basic
                picker = "snacks",
                background_scanning = true,
                notifications = {
                    --Set this to false if you have configured lualine to avoid double logging
                    handler = false,
                },
                diagnostics = {
                    default_severity = "error",
                    setqflist = false,
                },
            })

            -- Example command
            vim.api.nvim_create_user_command("Secrets", function()
                dotnet.secrets()
            end, {})

            -- Example keybinding
            vim.keymap.set("n", "<C-p>", function()
                dotnet.run_project()
            end)
        end,
    },
}
