-- orgmode binds capture finalize in normal mode only; in insert mode <C-c> just
-- exits insert. org-roam also creates its own Capture instance (with callbacks),
-- so we must call that buffer-local handler—not Org.action('capture.refile').
local capture_map_opts = {
  desc = 'Finalize org capture (refile)',
  nowait = true,
  silent = true,
}

local daily_map_opts = {
  desc = 'Save roam daily note',
  nowait = true,
  silent = true,
}

---@return string
local function capture_finalize_lhs()
  local user = vim.tbl_get(require('orgmode.config').opts.mappings, 'capture') or {}
  local key = user.org_capture_finalize or '<Leader>ow'
  if type(key) == 'table' then
    key = key[1]
  end
  return key
end

---@param bufnr number
---@return function|nil
local function find_finalize_fn(bufnr)
  local key = capture_finalize_lhs()
  local map = vim.keymap.get('n', key, { buffer = bufnr })
  if map and map.callback then
    return map.callback
  end

  for _, entry in ipairs(vim.api.nvim_buf_get_keymap(bufnr, 'n')) do
    local desc = entry.desc or ''
    if desc:find('finalize', 1, true) or desc:find('Save to default notes', 1, true) then
      if entry.callback then
        return entry.callback
      end
    end
  end
end

local finalize_capture = function()
  if vim.api.nvim_get_mode().mode:match('^[iR]') then
    vim.cmd.stopinsert()
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local fn = find_finalize_fn(bufnr)
  if fn then
    fn()
    return
  end

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(capture_finalize_lhs(), true, false, true), 'n', false)
end

---@param bufnr number
---@return boolean
local function is_roam_daily_buf(bufnr)
  if vim.b[bufnr].org_capture then
    return false
  end

  local ok, roam = pcall(require, 'org-roam')
  if not ok then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == '' then
    return false
  end

  name = vim.fs.normalize(vim.fn.expand(name))
  local daily_dir = vim.fs.normalize(vim.fn.expand(vim.fs.joinpath(
    roam.config.directory,
    roam.config.extensions.dailies.directory
  )))

  if not vim.startswith(name, daily_dir) then
    return false
  end

  return require('orgmode.objects.date').is_valid_date_string(vim.fn.fnamemodify(name, ':t:r')) ~= nil
end

local save_daily_note = function()
  if vim.api.nvim_get_mode().mode:match('^[iR]') then
    vim.cmd.stopinsert()
  end
  vim.cmd.write()
end

---@param bufnr number
local function setup_capture_maps(bufnr)
  if not vim.b[bufnr].org_capture or vim.b[bufnr].org_capture_finalize_maps then
    return
  end

  if not find_finalize_fn(bufnr) then
    return
  end

  vim.b[bufnr].org_capture_finalize_maps = true
  local opts = vim.tbl_extend('force', capture_map_opts, { buffer = bufnr })
  vim.keymap.set({ 'n', 'i' }, '<C-c>', finalize_capture, opts)
  vim.keymap.set('i', capture_finalize_lhs(), finalize_capture, opts)
end

---@param bufnr number
local function setup_daily_maps(bufnr)
  if not is_roam_daily_buf(bufnr) or vim.b[bufnr].org_daily_save_maps then
    return
  end

  vim.b[bufnr].org_daily_save_maps = true
  local opts = vim.tbl_extend('force', daily_map_opts, { buffer = bufnr })
  vim.keymap.set({ 'n', 'i' }, capture_finalize_lhs(), save_daily_note, opts)
  vim.keymap.set({ 'n', 'i' }, '<C-c>', save_daily_note, opts)
end

---@param bufnr number
---@param attempt? integer
local function setup_maps_when_ready(bufnr, attempt)
  attempt = attempt or 0
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  setup_capture_maps(bufnr)
  setup_daily_maps(bufnr)

  if vim.b[bufnr].org_capture and not vim.b[bufnr].org_capture_finalize_maps and attempt < 20 then
    vim.defer_fn(function()
      setup_maps_when_ready(bufnr, attempt + 1)
    end, 10)
  end
end

local function on_enter(ev)
  setup_maps_when_ready(ev.buf)
end

Config.new_autocmd({ 'BufEnter', 'WinEnter' }, '*', on_enter, 'Org capture and daily note finalize maps')
