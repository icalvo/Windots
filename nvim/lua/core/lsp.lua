vim.diagnostic.config({
    signs = true,
    underline = true,
    update_in_insert = true,
    virtual_text = {
        source = "if_many",
        prefix = "●",
    },
})
vim.lsp.enable({
    -- "bicep",
    -- "docker_compose_language_service",
    "html",
    "jsonls",
    "luals",
    "powershell_es",
    -- "pyright",
    -- "rust_analyzer",
    "tailwindcss",
    "taplo", -- toml
    "ts_ls",
    "yamlls",
})
-- vim.lsp.config("docker_compose_language_service", {})
-- vim.lsp.config("pyright", {})
vim.lsp.config("kulala-ls", {
    cmd = { "kulala-ls", "--stdio" },
    filetypes = { "http" },
    root_markers = { ".git" },
})
vim.lsp.inlay_hint.enable()
