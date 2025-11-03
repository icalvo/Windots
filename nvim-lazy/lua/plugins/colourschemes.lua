return {
    {
        "scottmckendry/cyberdream.nvim",
        dev = true,
        lazy = false,
        priority = 1000,
        opts = {
            variant = "auto",
            transparent = true,
            italic_comments = true,
            hide_fillchars = true,
            terminal_colors = false,
            cache = true,
            borderless_pickers = true,
            overrides = function(c)
                return {
                    CursorLine = { bg = c.bg },
                    CursorLineNr = { fg = c.magenta },
                }
            end,
        },
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        opts = {
            styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
                comments = { "italic" }, -- Change the style of comments
                conditionals = { "italic" },
                loops = {},
                functions = { "italic" },
                keywords = {},
                strings = {},
                variables = {},
                numbers = {},
                booleans = {},
                properties = {},
                types = {},
                operators = {},
                -- miscs = {}, -- Uncomment to turn off hard-coded styles
            },
        },
        config = function(_, opts)
            require("catppuccin").setup(opts)
            vim.cmd("colorscheme catppuccin-mocha")
        end,
    },
}
