return {
    "stevearc/resession.nvim",
    dependencies = {
        {
            "scottmckendry/pick-resession.nvim",
            dev = true,
            config = function()
                require("pick-resession").setup({
                    path_icons = {
                        { match = "C:/Users/" .. vim.g.user .. "/Repos/", icon = " ", highlight = "Changed" },
                        { match = "/home/" .. vim.g.user .. "/Repos/", icon = " ", highlight = "Changed" },
                        { match = "C:/Users/" .. vim.g.user .. "/", icon = " ", highlight = "Special" },
                        { match = "/home/" .. vim.g.user .. "/", icon = " ", highlight = "Special" },
                    },
                })
            end,
        },
    },
    lazy = false,
    config = function()
        local resession = require("resession")
        resession.setup({
            autosave = {
                enabled = true,
                interval = 60,
                notify = false,
            },
        })
        local function get_repo_root()
            local name = vim.fn.getcwd()
            local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))
            if vim.v.shell_error == 0 then
                return root:gsub("/", "\\")
            else
                return nil
            end
        end
        vim.api.nvim_create_autocmd("VimEnter", {
            callback = function()
                -- Only load the session if nvim was started with no args
                local repo_root = get_repo_root()
                if vim.fn.argc(-1) == 0 then
                    if repo_root then
                        resession.load(repo_root, { silence_errors = true, notify = true })
                        vim.g.resession_name = repo_root
                        local repo_name = string.match(repo_root, "([^/\\]+)$")
                        vim.cmd("silent !wezterm cli set-tab-title " .. repo_name)
                        require("snacks").notifier("Loaded repo session [" .. vim.g.resession_name .. "]")
                    else
                        local sanitized_cwd = vim.fn.getcwd()
                        resession.load(sanitized_cwd, { silence_errors = true, notify = true })
                        vim.g.resession_name = sanitized_cwd
                        require("snacks").notifier("Loaded dir session [" .. vim.g.resession_name .. "]")
                    end
                else
                    require("snacks").notifier("No session loaded")
                end
            end,
        })

        vim.api.nvim_create_autocmd("VimLeavePre", {
            callback = function()
                -- Save session if we opened it when starting nvim
                if vim.g.resession_name then
                    resession.save(vim.g.resession_name, { notify = false })
                    require("snacks").notifier("Saved dir session [" .. vim.g.resession_name .. "]")
                end
            end,
        })
    end,
}
