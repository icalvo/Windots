return {
    "Issafalcon/neotest-dotnet",
    lazy = false,
    dependencies = {
        "nvim-neotest/neotest",
    },
    config = function()
        require("neotest").setup({
            adapters = {
                require("neotest-dotnet"),
            },
        })
    end,
}
