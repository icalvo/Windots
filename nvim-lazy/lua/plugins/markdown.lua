return {
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = "markdown",
        config = function()
            require("render-markdown").setup({
                completions = { lsp = { enabled = true } },
                pipe_table = {
                    border = { "╭", "┬", "╮", "├", "┼", "┤", "╰", "┴", "╯", "│", "─" },
                },
                code = {
                    width = "block",
                    left_pad = 2,
                    right_pad = 2,
                },
                bullet = {
                    left_pad = 0,
                    right_pad = 1,
                },
            })
        end,
    },
    {
        "iamcco/markdown-preview.nvim",
        ft = { "markdown" },
        cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
        build = function()
            local install_path = vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim/app"
            vim.cmd("!cd " .. install_path .. " && npm install && git reset --hard")
        end,
        init = function()
            vim.g.mkdp_filetypes = { "markdown" }
            vim.g.mkdp_auto_close = 0
        end,
    },
}
