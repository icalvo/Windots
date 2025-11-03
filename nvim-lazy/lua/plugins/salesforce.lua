return {
    "jonathanmorris180/salesforce.nvim",
    cond = vim.fn.getcwd():find("Salesforce", nil, true) ~= nil,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
}
