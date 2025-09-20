return {
    "nvim-neotest/neotest",
    requires = {
        {
            "Issafalcon/neotest-dotnet",
        },
    },
    dependencies = {
        "nvim-neotest/nvim-nio",
        "nvim-lua/plenary.nvim",
        "antoinemadec/FixCursorHold.nvim",
        "nvim-treesitter/nvim-treesitter",
        "marilari88/neotest-vitest",
        "nvim-neotest/neotest-jest",
    },
    config = function()
        require("neotest").setup({
            adapters = {
                require("neotest-vitest"),
                require("neotest-jest"),
            },
        })
    end,
}
