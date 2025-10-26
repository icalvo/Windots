return {
	{
		"folke/flash.nvim",
		event = "verylazy",
		---@type flash.config
		opts = {
			modes = {
				char = {
					enabled = false,
				},
				treesitter = {
					highlight = {
						backdrop = true,
						matches = true,
					},
				},
			},
		},
	},
}
