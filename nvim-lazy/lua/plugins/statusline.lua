return {
	"nvim-lualine/lualine.nvim",
	lazy = false,
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"smiteshp/nvim-navic",
		"yavorski/lualine-macro-recording.nvim",
	},
	opts = {
		options = {
			icons_enabled = true,
			theme = "auto",
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
			disabled_filetypes = {
				statusline = {},
				winbar = {},
			},
			ignore_focus = {},
			always_divide_middle = true,
			always_show_tabline = true,
			globalstatus = false,
			refresh = {
				statusline = 1000,
				tabline = 1000,
				winbar = 1000,
				refresh_time = 16, -- ~60fps
				events = {
					"WinEnter",
					"BufEnter",
					"BufWritePost",
					"SessionLoadPost",
					"FileChangedShellPost",
					"VimResized",
					"Filetype",
					"CursorMoved",
					"CursorMovedI",
					"ModeChanged",
				},
			},
		},
		sections = {
			lualine_a = {
				{
					"mode",
					fmt = function(str)
						return str:sub(1, 1)
					end,
				},
			},
			lualine_b = {
				{
					"require'salesforce.org_manager':get_default_alias()",
					icon = "󰢎",
				},
				{ require("easy-dotnet.ui-modules.jobs").lualine },
				"branch",
				"diff",
				"diagnostics",
				{
					require("kulala").get_selected_env,
					color = { fg = "#ffcc00" },
				},
			},
			lualine_c = {
				{ "filename", color = { fg = "#ffffff" } },
				{ "navic", color_correction = "dynamic" },
			},
			lualine_x = {},
			lualine_y = {
				{
					require("noice").api.status.search.get,
					cond = require("noice").api.status.search.has,
					color = { fg = "#ff9eff" },
				},
				{ "macro_recording", "%S" },
				{
					"encoding",
					fmt = function(str)
						if str == "utf-8" then
							return ""
						else
							return str
						end
					end,
				},
				"fileformat",
				"filetype",
			},
			lualine_z = { "location" },
		},
		inactive_sections = {
			lualine_a = {},
			lualine_b = {},
			lualine_c = { "filename" },
			lualine_x = { "location" },
			lualine_y = {},
			lualine_z = {},
		},
		tabline = {},
		winbar = {},
		inactive_winbar = {},
		extensions = {},
	},
}
