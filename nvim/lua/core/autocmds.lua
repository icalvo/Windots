local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup
local utils = require("core.utils")

-- General Settings
local general = augroup("General Settings", { clear = true })

autocmd("BufEnter", {
	callback = function()
		vim.opt.formatoptions:remove({ "c", "r", "o" })
	end,
	group = general,
	desc = "Disable New Line Comment",
})

autocmd("BufEnter", {
	pattern = { "*.md", "*.txt" },
	callback = function()
		vim.opt_local.spell = true
	end,
	group = general,
	desc = "Enable spell checking on specific filetypes",
})
autocmd("BufEnter", {
	callback = function()
		local bufname = vim.api.nvim_buf_get_name(0)
		local name = bufname:match("([^\\/]+)$") or bufname

		vim.cmd("silent !wezterm cli set-tab-title " .. name)
	end,
	group = general,
	desc = "Set wezterm tab name to bufname",
})
autocmd("BufWinEnter", {
	callback = function(data)
		utils.open_help(data.buf)
	end,
	group = general,
	desc = "Redirect help to floating window",
})

autocmd("FileType", {
	group = general,
	pattern = {
		"grug-far",
		"help",
		"checkhealth",
		"copilot-chat",
	},
	callback = function(event)
		vim.bo[event.buf].buflisted = false
		vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", {
			buffer = event.buf,
			silent = true,
			desc = "Quit buffer",
		})
	end,
})
autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("highlight_yank", {}),
	desc = "Hightlight selection on yank",
	pattern = "*",
	callback = function()
		vim.highlight.on_yank({ higroup = "IncSearch", timeout = 500 })
	end,
})
