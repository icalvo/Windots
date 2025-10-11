return {
    "stevearc/conform.nvim",
    lazy = false,
    -- event = "BufReadPre",
    config = function()
        vim.g.autoformat = true
        require("conform").setup({
            formatters_by_ft = {
                cs = { "csharpier" },
                css = { "prettier" },
                html = { "prettier" },
                http = { "kulala-fmt" },
                javascript = { "prettier" },
                json = { "prettier" },
                lua = { "stylua" },
                markdown = { "prettier" },
                scss = { "prettier" },
                sh = { "shfmt" },
                templ = { "templ" },
                toml = { "taplo" },
                typescript = { "prettier" },
                yaml = { "prettier" },
            },

            format_after_save = function(bufnr)
                if not vim.g.autoformat then
                    return
                else
                    if vim.bo.filetype == "ps1" then
                        vim.lsp.buf.format()
                        return
                    end
                    -- Disable autoformat for files in a certain path
                    local bufname = vim.api.nvim_buf_get_name(bufnr)
                    if bufname:match("/node_modules/") then
                        return
                    end
                    return { lsp_format = "fallback" }
                end
            end,

            formatters = {
                goimports_reviser = {
                    command = "goimports-reviser",
                    args = { "-output", "stdout", "$FILENAME" },
                },
            },
        })
    end,
}
