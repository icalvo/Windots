-- Always-on startup timing. Reports live in `stdpath('log')/startup/`.
-- Open the latest with `:StartupLog`.

local M = {}

local KEEP_REPORTS = 10
local SLOW_FACTOR = 1.5
local SLOW_MIN_MS = 800

local t0 = vim.uv.hrtime()
local marks = {}
local done = false
local report_path --- @type string?

local function elapsed_ms()
  return (vim.uv.hrtime() - t0) / 1e6
end

local function mark(label)
  marks[#marks + 1] = { ms = elapsed_ms(), label = label }
end

local function log_dir()
  return vim.fs.joinpath(vim.fn.stdpath('log'), 'startup')
end

local function shorten(path)
  path = path:gsub('\\', '/')
  local function replace(prefix, name)
    if not prefix or prefix == '' then return end
    prefix = prefix:gsub('\\', '/')
    local pat = prefix:gsub('(%p)', '%%%1')
    path = path:gsub('^' .. pat, name)
  end
  -- `data` is `nvim-data`, which would otherwise become `$config-data`.
  replace(vim.fn.stdpath('data'), '$data')
  replace(vim.fn.stdpath('config'), '$config')
  replace(vim.env.VIMRUNTIME, '$runtime')
  return path
end

local function argv_summary()
  local args = {}
  for i = 2, #vim.v.argv do
    args[#args + 1] = vim.v.argv[i]
  end
  return table.concat(args, ' ')
end

local function wrap_pack_add()
  local pack_add = vim.pack.add
  vim.pack.add = function(specs, opts)
    local list = specs
    if type(specs) == 'table' and specs.src then list = { specs } end
    local names = {}
    if type(list) == 'table' then
      for _, spec in ipairs(list) do
        local src = type(spec) == 'string' and spec or spec.src
        names[#names + 1] = type(src) == 'string' and src:match('[^/]+$') or '?'
      end
    end
    local before = elapsed_ms()
    pack_add(specs, opts)
    mark(
      string.format(
        'vim.pack.add %s (+%.1f ms)',
        table.concat(names, ', '),
        elapsed_ms() - before
      )
    )
  end
end

local function median(values)
  if #values == 0 then return nil end
  local t = vim.deepcopy(values)
  table.sort(t)
  local mid = math.ceil(#t / 2)
  if #t % 2 == 0 then return (t[mid] + t[mid + 1]) / 2 end
  return t[mid]
end

local function read_recent_totals(dir, n)
  local index = vim.fs.joinpath(dir, 'index.tsv')
  if vim.fn.filereadable(index) ~= 1 then return {} end
  local lines = vim.fn.readfile(index)
  local totals = {}
  local start = math.max(1, #lines - n + 1)
  for i = start, #lines do
    local ms = tonumber(lines[i]:match('\t([%d.]+)\t'))
    if ms then totals[#totals + 1] = ms end
  end
  return totals
end

local function prune(dir)
  local files = {}
  local ok, iter = pcall(vim.fs.dir, dir)
  if not ok or not iter then return end
  for name, typ in iter do
    if typ == 'file' and name:match('^%d.*%.log$') then
      files[#files + 1] = name
    end
  end
  table.sort(files)
  while #files > KEEP_REPORTS do
    local name = table.remove(files, 1)
    vim.fn.delete(vim.fs.joinpath(dir, name))
  end
end

local function deltas()
  local rows = {}
  local prev = 0
  for _, m in ipairs(marks) do
    rows[#rows + 1] = {
      at = m.ms,
      dt = m.ms - prev,
      label = m.label,
    }
    prev = m.ms
  end
  return rows
end

local function write_report(reason)
  if done then return end
  done = true
  mark(reason)

  local ok, err = pcall(function()
    local total = elapsed_ms()
    local dir = log_dir()
    vim.fn.mkdir(dir, 'p')

    local stamp = os.date('%Y-%m-%dT%H%M%S')
    local path = vim.fs.joinpath(dir, string.format('%s_%05dms.log', stamp, math.floor(total)))
    report_path = path

    local v = vim.version()
    local extra = (type(v.prerelease) == 'string' and v.prerelease ~= '')
        and ('-' .. v.prerelease)
      or ''
    local version = string.format('v%d.%d.%d%s', v.major, v.minor, v.patch, extra)

    local rows = deltas()
    local slowest = vim.deepcopy(rows)
    table.sort(slowest, function(a, b) return a.dt > b.dt end)

    local lines = {
      '=== Neovim startup report ===',
      'Attach this file when a launch felt slow.',
      '',
      string.format('time:      %s', os.date('%Y-%m-%d %H:%M:%S')),
      string.format('total_ms:  %.1f', total),
      string.format('reason:    %s', reason),
      string.format('version:   %s', version),
      string.format('gui:       %s', vim.g.neovide and 'neovide' or (vim.v.progname or 'nvim')),
      string.format('cwd:       %s', vim.uv.cwd() or ''),
      string.format('argv:      %s', argv_summary()),
      string.format('log_dir:   %s', dir),
      '',
      '-- Slowest steps --',
    }

    for i = 1, math.min(15, #slowest) do
      local r = slowest[i]
      if r.dt >= 1 then
        lines[#lines + 1] = string.format('%8.1f ms  %s', r.dt, r.label)
      end
    end

    lines[#lines + 1] = ''
    lines[#lines + 1] = '-- Timeline (cumulative / step) --'
    for _, r in ipairs(rows) do
      lines[#lines + 1] = string.format('%8.1f  +%7.1f  %s', r.at, r.dt, r.label)
    end

    vim.fn.writefile(lines, path)

    local recent = read_recent_totals(dir, 20)
    local med = median(recent)
    local slow = total >= SLOW_MIN_MS and (not med or total >= med * SLOW_FACTOR)

    local index_line = string.format(
      '%s\t%.1f\t%s\t%s\t%s',
      stamp,
      total,
      slow and 'slow' or 'ok',
      vim.fs.basename(path),
      argv_summary():gsub('\t', ' ')
    )
    vim.fn.writefile({ index_line }, vim.fs.joinpath(dir, 'index.tsv'), 'a')
    prune(dir)

    if slow and #vim.api.nvim_list_uis() > 0 then
      local extra = med and string.format(' (median %.0f ms)', med) or ''
      vim.schedule(function()
        vim.notify(
          string.format('Slow startup: %.0f ms%s. :StartupLog', total, extra),
          vim.log.levels.WARN,
          { title = 'startup' }
        )
      end)
    end
  end)

  if not ok then
    done = false
    pcall(function()
      vim.fn.writefile(
        { tostring(err) },
        vim.fs.joinpath(vim.fn.stdpath('data'), 'startuplog-error.txt')
      )
    end)
  end
end

local function append_late(label)
  if not report_path or vim.fn.filereadable(report_path) ~= 1 then return end
  vim.fn.writefile(
    { string.format('%8.1f  late  %s', elapsed_ms(), label) },
    report_path,
    'a'
  )
end

function M.open(which)
  local dir = log_dir()
  if which == 'index' then
    local index = vim.fs.joinpath(dir, 'index.tsv')
    if vim.fn.filereadable(index) ~= 1 then
      vim.notify('No startup index yet', vim.log.levels.WARN, { title = 'startup' })
      return
    end
    vim.cmd.edit(vim.fn.fnameescape(index))
    return
  end

  local latest = report_path
  if not latest or vim.fn.filereadable(latest) ~= 1 then
    local files = vim.fn.glob(vim.fs.joinpath(dir, '*.log'), false, true)
    table.sort(files)
    latest = files[#files]
  end
  if not latest then
    vim.notify('No startup reports yet', vim.log.levels.WARN, { title = 'startup' })
    return
  end
  vim.cmd.edit(vim.fn.fnameescape(latest))
end

wrap_pack_add()

local grp = vim.api.nvim_create_augroup('startuplog', { clear = true })

vim.api.nvim_create_autocmd('SourcePost', {
  group = grp,
  callback = function(ev)
    if done or ev.file == '' then return end
    mark('source ' .. shorten(ev.file))
  end,
})

vim.api.nvim_create_autocmd({ 'PackChangedPre', 'PackChanged' }, {
  group = grp,
  callback = function(ev)
    local label = string.format(
      '%s %s %s',
      ev.event,
      ev.data.kind,
      ev.data.spec and ev.data.spec.name or '?'
    )
    if done then
      append_late(label)
    else
      mark(label)
    end
  end,
})

vim.api.nvim_create_autocmd('VimEnter', {
  group = grp,
  once = true,
  callback = function()
    mark('VimEnter')
    if vim.tbl_contains(vim.v.argv, '--headless') then write_report('VimEnter') end
  end,
})

vim.api.nvim_create_autocmd('UIEnter', {
  group = grp,
  once = true,
  callback = function() write_report('UIEnter') end,
})

-- If something quits before UIEnter (e.g. `nvim --headless +qa`), still write.
vim.api.nvim_create_autocmd('VimLeave', {
  group = grp,
  once = true,
  callback = function()
    if not done then write_report('VimLeave') end
  end,
})

vim.api.nvim_create_user_command('StartupLog', function(opts)
  M.open(opts.args ~= '' and opts.args or nil)
end, {
  nargs = '?',
  complete = function() return { 'index' } end,
  desc = 'Open latest startup timing report (or :StartupLog index)',
})

return M
