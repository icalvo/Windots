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

-- NOTE: This is a hacky fix for bicep param files. The current behaviour causes the bicep lsp to detect
-- bicepparem files as bicep files when switching buffers. This isn't an issue when initialising the lsp
-- with a bicepparam file initially.
-- TODO: Find a better solution, report upstream or wait for a fix.
autocmd("BufEnter", {
	pattern = { "*.bicepparam" },
	callback = function()
		local bicep_client = vim.lsp.get_clients({ name = "bicep" })
		vim.lsp.buf_detach_client(vim.api.nvim_get_current_buf(), bicep_client[1].id)
		vim.lsp.buf_attach_client(vim.api.nvim_get_current_buf(), bicep_client[1].id)
	end,
	group = general,
	desc = "Detach and reattach bicep client for bicepparam files",
})

autocmd("BufEnter", {
	pattern = { "*.md", "*.txt" },
	callback = function()
		vim.opt_local.spell = true
	end,
	group = general,
	desc = "Enable spell checking on specific filetypes",
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
