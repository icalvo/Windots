return {
    "nvim-mini/mini.pairs",
    event = "InsertEnter",
    opts = {},
    config = function(opts)
        require("mini.pairs").setup(opts)
        local map_bs = function(lhs, rhs)
            vim.keymap.set("i", lhs, rhs, { expr = true, replace_keycodes = false })
        end

        map_bs("<C-j>", "v:lua.MiniPairs.cr()")
    end,
}
