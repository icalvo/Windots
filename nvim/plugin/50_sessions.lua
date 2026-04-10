local function log_info(s)
    vim.notify(s, vim.log.levels.INFO, { title = "IGNACIO" })
end

vim.opt.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

local session_dir = vim.fn.stdpath("state") .. "/sessions/"

if vim.fn.isdirectory(session_dir) == 0 then
    vim.fn.mkdir(session_dir, "p")
end

local function ask_yes_no(prompt, default_yes)
    local choices = { "&Yes", "&No" }
    local default = default_yes and 1 or 2
    local res = vim.fn.confirm(prompt, table.concat(choices, "\n"), default)
    return res == 1
end

-- usage
local function get_session_file()
    local cwd = vim.fn.getcwd()
    local session_path = cwd
    local git_root = vim.fn.finddir(".git", cwd .. ";")
    if git_root ~= "" and type(git_root) == "string" then
        git_root = vim.fn.fnamemodify(git_root, ":h")
        -- if
        --     git_root ~= session_path
        --     and ask_yes_no(
        --         "You are in a git repo, do you want to load its session instead of the one for the current dir?",
        --         true
        --     )
        -- then
        session_path = git_root
        -- end
    end
    local session_name = session_path:gsub("/", "__"):gsub(":", "__"):gsub("\\", "__")

    return session_dir .. session_name .. ".vim"
end

local function get_last_session_file()
    return session_dir .. "last_session.vim"
end

vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        local no_args = vim.fn.argc() == 0

        if no_args then
            local session_file = get_session_file()

            if vim.fn.filereadable(session_file) == 1 then
                vim.cmd("silent! set winminwidth=1 winwidth=1 winminheight=1 winheight=1")

                log_info("Loading session " .. session_file)
                vim.cmd("source " .. vim.fn.fnameescape(session_file))
            end
        end
    end,
})

local function create_session()
    local stop_file = session_dir .. ".stop_saving"

    if vim.fn.filereadable(stop_file) == 1 then
        vim.fn.delete(stop_file)

        return
    end

    local buf_count = 0

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) ~= "" then
            buf_count = buf_count + 1
        end
    end

    if buf_count >= 1 then
        local session_file = get_session_file()

        log_info("Saving session " .. session_file)
        vim.cmd("mksession! " .. vim.fn.fnameescape(session_file))

        vim.cmd("mksession! " .. vim.fn.fnameescape(get_last_session_file()))
    end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = create_session,
})

vim.keymap.set("n", "<leader>qq", create_session, { desc = "Create session" })

vim.keymap.set("n", "<leader>qs", function()
    local session_file = get_session_file()

    if vim.fn.filereadable(session_file) == 1 then
        vim.cmd("source " .. vim.fn.fnameescape(session_file))
    else
        print("No session found")
    end
end, { desc = "Load session" })

vim.keymap.set("n", "<leader>ql", function()
    local last_session = get_last_session_file()

    if vim.fn.filereadable(last_session) == 1 then
        vim.cmd("source " .. vim.fn.fnameescape(last_session))
    else
        print("No last session found")
    end
end, { desc = "Load last session" })

vim.keymap.set("n", "<leader>qS", function()
    local sessions = {}

    local session_files = vim.fn.glob(session_dir .. "*.vim", false, true)

    for _, file in ipairs(session_files) do
        local name = vim.fn.fnamemodify(file, ":t:r")

        name = name:gsub("__", "/")

        table.insert(sessions, name)
    end

    if #sessions == 0 then
        print("No sessions found")

        return
    end

    vim.ui.select(sessions, { prompt = "Select session:" }, function(choice)
        if choice then
            local session_file = session_dir .. choice:gsub("/", "__") .. ".vim"

            vim.cmd("source " .. vim.fn.fnameescape(session_file))
        end
    end)
end, { desc = "Select session" })

vim.keymap.set("n", "<leader>qd", function()
    local stop_file = session_dir .. ".stop_saving"

    vim.fn.writefile({}, stop_file)

    print("Session saving disabled")
end, { desc = "Disable session saving" })
