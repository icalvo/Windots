-- Org buffer display: conceal link targets, show descriptions only.
-- See :help orgmode-troubleshooting-links-are-not-concealed
vim.cmd('setlocal conceallevel=2 concealcursor=nc wrap')

-- mini.completion uses LSP omnifunc when attached; org keeps orgmode omnifunc
-- and falls back to it for popup completion (roam nodes inside [[ ... ]]).
vim.b.minicompletion_config = {
  fallback_action = function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-x><C-o>', true, false, true), 'n', false)
  end,
}

-- Restore orgmode omnifunc if org LSP attaches after this ftplugin runs.
vim.api.nvim_create_autocmd('LspAttach', {
  buffer = 0,
  once = true,
  callback = function()
    vim.bo.omnifunc = 'v:lua.orgmode.omnifunc'
  end,
})
