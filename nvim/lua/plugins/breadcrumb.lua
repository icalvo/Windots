return {
    "smiteshp/nvim-navic",
    lazy = false,
    config = function()
        require("nvim-navic").setup({
            lsp = {
                auto_attach = true,
                -- priority order for attaching LSP servers
                -- to the current buffer
                preference = {
                    "html",
                    "templ",
                },
            },
            highlight = true,
            separator = " 󰁔 ",
        })
    end,
}
