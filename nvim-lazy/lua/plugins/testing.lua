return {
    -- {
    --     {
    --         "Issafalcon/neotest-dotnet",
    --         lazy = false,
    --         dependencies = {
    --             "nvim-neotest/neotest",
    --         },
    --         config = function()
    --             require("neotest").setup({
    --                 adapters = {
    --                     require("neotest-dotnet"),
    --                 },
    --             })
    --         end,
    --     },
    -- },
    {
        "nvim-neotest/neotest",
        lazy = false,
        dependencies = {
            "nvim-neotest/nvim-nio",
            "nvim-lua/plenary.nvim",
            "antoinemadec/FixCursorHold.nvim",
            "nvim-treesitter/nvim-treesitter",
            "marilari88/neotest-vitest",
        },
        config = function()
            require("neotest").setup({
                log_level = vim.log.levels.DEBUG,
                adapters = {
                    require("neotest-vitest"),
                },
            })
        end,
    },
}
