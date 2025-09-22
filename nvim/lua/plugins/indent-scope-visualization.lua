return {
    "nvim-mini/mini.indentscope",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        symbol = "│",
        options = { try_as_border = true },
    },
    init = function()
        vim.api.nvim_create_autocmd("FileType", {
            pattern = {
                "Trouble",
                "alpha",
                "copilot-chat",
                "dashboard",
                "help",
                "lazy",
                "mason",
                "neotree",
                "notify",
                "snacks_terminal",
            },
            callback = function()
                vim.b.miniindentscope_disable = true
            end,
        })
    end,
}
