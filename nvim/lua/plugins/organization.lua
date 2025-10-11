return {
    "obsidian-nvim/obsidian.nvim",
    version = "*", -- recommended, use latest release instead of latest commit
    lazy = true,
    ft = "markdown",
    -- event = {
    --     "BufReadPre " .. vim.fn.expand("~") .. "\\Repos\\Ignacio\\*.md",
    --     "BufNewFile " .. vim.fn.expand("~") .. "\\Repos\\Ignacio\\*.md",
    -- },
    dependencies = {
        "nvim-lua/plenary.nvim",
        "saghen/blink.cmp",
        "folke/snacks.nvim",
    },
    opts = {
        completion = { blink = true },
        picker = { snacks = true },
        -- disable_frontmatter = true,
        -- new_notes_location = "notes_subdir",
        -- notes_subdir = "Zettelkasten",
        templates = { folder = "Templates", date_format = "%y-%m-%d", time_format = "%H:%M" },
        workspaces = {
            {
                name = "default",
                path = "~/repos/Ignacio",
            },
        },
        legacy_commands = false,
    },
}
