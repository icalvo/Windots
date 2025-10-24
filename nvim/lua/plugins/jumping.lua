return {
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		---@type Flash.Config
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
