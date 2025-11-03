return {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = {
        terminal = {
            win = {
                position = "right",
                width = 0.5,
                wo = {
                    winbar = "", -- hide terminal title
                },
            },
        },
    },
}
