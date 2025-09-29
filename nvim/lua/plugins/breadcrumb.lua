return {
    "smiteshp/nvim-navic",
    lazy = false,
    opts = {
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
    },
}
