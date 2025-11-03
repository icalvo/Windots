return {
    "saghen/blink.cmp",
    event = "InsertEnter",
    dependencies = "rafamadriz/friendly-snippets",
    version = "v1.*",
    config = function()
        local is_enabled = function()
            local disabled_ft = {
                "TelescopePrompt",
                "grug-far",
            }
            return not vim.tbl_contains(disabled_ft, vim.bo.filetype)
                and vim.b.completion ~= false
                and vim.bo.buftype ~= "prompt"
        end

        require("blink.cmp").setup({
            enabled = is_enabled,
            cmdline = { completion = { menu = { auto_show = true } } },
            fuzzy = { implementation = "prefer_rust_with_warning" },
            sources = {
                default = { "lsp", "easy-dotnet", "path" },
                providers = {
                    ["easy-dotnet"] = {
                        name = "easy-dotnet",
                        enabled = true,
                        module = "easy-dotnet.completion.blink",
                        score_offset = 10000,
                        async = true,
                    },
                },
            },
            keymap = {
                preset = "default",
                ["<CR>"] = { "select_and_accept", "fallback" },
            },
            completion = {
                menu = {
                    scrollbar = false,
                    auto_show = is_enabled,
                    border = {
                        { "󱐋", "WarningMsg" },
                        "─",
                        "╮",
                        "│",
                        "╯",
                        "─",
                        "╰",
                        "│",
                    },
                },
                documentation = {
                    auto_show = true,
                    window = {
                        border = {
                            { "", "DiagnosticHint" },
                            "─",
                            "╮",
                            "│",
                            "╯",
                            "─",
                            "╰",
                            "│",
                        },
                    },
                },
            },
        })
    end,
}
