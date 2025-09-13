return {
    "folke/snacks.nvim",
    dependencies = { "folke/flash.nvim" },
    lazy = false,
    priority = 1000,
    opts = {
        notifier = { enabled = true },
        words = { enabled = true },
        lazygit = {
            configure = false,
            win = {
                position = "float",
                width = 0.99,
                height = 0.99,
            },
        },
        terminal = {
            win = {
                position = "right",
                width = 0.5,
                wo = {
                    winbar = "", -- hide terminal title
                },
            },
        },
        picker = {
            formatters = {
                file = {
                    filename_first = true,
                },
            },
            prompt = "   ",
            win = {
                input = {
                    keys = {
                        ["<a-s>"] = { "flash", mode = { "n", "i" } },
                        ["s"] = { "flash" },
                    },
                },
            },
            actions = {
                flash = function(picker)
                    require("flash").jump({
                        pattern = "^",
                        label = { after = { 0, 0 } },
                        search = {
                            mode = "search",
                            exclude = {
                                function(win)
                                    return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "snacks_picker_list"
                                end,
                            },
                        },
                        action = function(match)
                            local idx = picker.list:row2idx(match.pos[1])
                            picker.list:_move(idx, true, true)
                        end,
                    })
                end,
            },
        },
    },
}
